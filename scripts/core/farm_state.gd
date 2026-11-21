class_name FarmState
extends RefCounted
## The whole simulation of one run. Pure data and rules: no nodes, no UI.
## The UI only ever calls the action methods below and listens to the signals.

signal changed
signal event(text: String, kind: String)   # kind: info | good | bad | journal
signal day_ended(summary: Dictionary)
signal run_finished(result: Dictionary)

const COLS := 6
const ROWS := 4
const QUALITY_MULT := [1.0, 1.3, 1.7]
const QUALITY_NAMES := ["Normal", "Fine", "Gold"]
const MAX_QUEUE := 12
const MAX_ORDERS := 3

var db: ContentDB
var journal: Journal
var cfg: Dictionary = {}
var fx: Dictionary = {}
var rng := RandomNumberGenerator.new()

# --- clock / calendar ---
var day: int = 1
var start_day: int = 1
var day_time: float = 0.0
var day_length: float = 180.0
var waiting_next_day: bool = false
var finished: bool = false
var season_id: String = "spring"
var season_day: int = 1
var season_len: int = 7
var year: int = 1
var weather_today: String = "sunny"
var weather_tomorrow: String = "sunny"

# --- economy ---
var money: int = 0
var plots: Array = []
var machines: Dictionary = {}
var inventory: Dictionary = {}
var demand: Dictionary = {}
var orders: Array = []
var next_order_id: int = 1
var season_crops: Dictionary = {}
var used_machines: Array = []
var auto_renew: bool = true
var start_plots: int = 4
var today: Dictionary = {}
var stats: Dictionary = {}


# ------------------------------------------------------------------ creation

static func create(p_db: ContentDB, p_cfg: Dictionary, p_journal: Journal = null) -> FarmState:
	var s := FarmState.new()
	s.db = p_db
	s.journal = p_journal
	s.cfg = p_cfg.duplicate(true)
	s._setup_new()
	return s


func _setup_new() -> void:
	fx = _build_fx()
	var diff: Dictionary = db.difficulties[cfg.get("difficulty", "normal")]
	var sc: Dictionary = _scenario()
	rng.seed = int(cfg.get("seed", 1))
	day_length = float(diff.get("day_length", 180)) * fxf("time_mult")
	money = int(round(float(sc.get("start_money", diff.get("start_money", 250))) * fxf("start_money_mult")))
	start_plots = int(diff.get("start_plots", 4))
	start_day = _first_day_of_season(str(sc.get("start_season", db.season_ids()[0])))
	day = start_day
	_apply_season(day)
	_make_plots()
	for mid in db.machines:
		machines[mid] = {"owned": 0, "queue": []}
	for mid in sc.get("start_machines", {}):
		if machines.has(mid):
			machines[mid]["owned"] = int(sc["start_machines"][mid])
	var items_in: Dictionary = sc.get("start_items", diff.get("start_items", {}))
	for iid in items_in:
		_add_item(str(iid), int(items_in[iid]), 0, false)
	for iid in db.items:
		demand[iid] = 1.0
	stats = {"income": 0, "expenses": 0, "harvested": 0, "crafted": 0, "days": 0, "sold": 0}
	weather_today = _roll_weather(season_id)
	weather_tomorrow = _roll_weather(season_info(day + 1)["id"])
	today = _new_ledger()
	_top_up_orders()
	_apply_weather_effects()
	_discover("weather", weather_today)
	_discover("seasons", season_id)


func _scenario() -> Dictionary:
	return db.scenarios.get(cfg.get("scenario", ""), {})


func _build_fx() -> Dictionary:
	var out: Dictionary = {"ban_tags": []}
	var layers: Array = []
	layers.append(db.difficulties.get(cfg.get("difficulty", "normal"), {}).get("effects", {}))
	layers.append(_scenario().get("effects", {}))
	var mods: Array = cfg.get("modifiers", []).duplicate()
	for m in _scenario().get("modifiers", []):
		if not mods.has(m):
			mods.append(m)
	cfg["active_modifiers"] = mods
	for m in mods:
		layers.append(db.modifiers.get(m, {}).get("effects", {}))
	for layer in layers:
		for k in layer:
			var v = layer[k]
			if k == "ban_tags":
				for t in v:
					if not out["ban_tags"].has(t):
						out["ban_tags"].append(t)
			elif typeof(v) == TYPE_BOOL:
				out[k] = bool(out.get(k, false)) or v
			elif k.ends_with("_mult"):
				out[k] = float(out.get(k, 1.0)) * float(v)
			elif k.begins_with("max_"):
				out[k] = mini(int(out.get(k, 9999)), int(v))
			else:
				out[k] = float(out.get(k, 0.0)) + float(v)
	return out


func fxf(key: String, default: float = 1.0) -> float:
	return float(fx.get(key, default))


func fxb(key: String) -> bool:
	return bool(fx.get(key, false))


# ------------------------------------------------------------------ calendar

func season_info(d: int) -> Dictionary:
	var ids: Array = db.season_ids()
	var year_len := 0
	for s in ids:
		year_len += int(db.seasons[s].get("days", 7))
	var y: int = floori(float(d - 1) / float(year_len))
	var rem: int = (d - 1) % year_len
	for i in ids.size():
		var n: int = int(db.seasons[ids[i]].get("days", 7))
		if rem < n:
			return {"id": ids[i], "index": i, "day": rem + 1, "len": n, "year": y + 1}
		rem -= n
	return {"id": ids[0], "index": 0, "day": 1, "len": 7, "year": 1}


func _first_day_of_season(sid: String) -> int:
	var d := 1
	for s in db.season_ids():
		if s == sid:
			return d
		d += int(db.seasons[s].get("days", 7))
	return 1


func _apply_season(d: int) -> void:
	var info := season_info(d)
	season_id = info["id"]
	season_day = info["day"]
	season_len = info["len"]
	year = info["year"]


func run_day() -> int:
	return day - start_day + 1


func day_fraction() -> float:
	return clampf(day_time / day_length, 0.0, 1.0)


# ------------------------------------------------------------------ weather

func _roll_weather(sid: String) -> String:
	var weights: Dictionary = db.seasons[sid].get("weather", {})
	var harsh := fxf("harshness_mult")
	var total := 0.0
	var eff: Dictionary = {}
	for w in weights:
		var wt: float = float(weights[w])
		if db.weather[w].get("bad", false):
			wt *= harsh
		eff[w] = wt
		total += wt
	if total <= 0.0:
		return "sunny" if db.weather.has("sunny") else db.weather.keys()[0]
	var r := rng.randf() * total
	for w in eff:
		r -= eff[w]
		if r <= 0.0:
			return w
	return eff.keys()[0]


func _apply_weather_effects() -> void:
	if not db.weather[weather_today].get("kills_sensitive", false):
		return
	var lost := 0
	for p in plots:
		if p["crop"] != "" and db.crops[p["crop"]].get("frost_sensitive", false):
			_clear_plot(p)
			lost += 1
	if lost > 0:
		_note("Frost killed %d sensitive crop%s!" % [lost, "" if lost == 1 else "s"], "bad")


# ------------------------------------------------------------------ plots

func _make_plots() -> void:
	plots = []
	for i in COLS * ROWS:
		plots.append({"state": "locked", "crop": "", "progress": 0.0, "ready": false,
				"fertility": 1.0, "last_crop": "", "paid": 0, "fee": 0})
	var order: Array = range(COLS * ROWS)
	order.sort_custom(func(a, b): return _center_dist(a) < _center_dist(b))
	start_plots = mini(start_plots, max_plots())
	for i in mini(start_plots, order.size()):
		plots[order[i]]["state"] = "owned"


func _center_dist(i: int) -> float:
	var c := float(i % COLS) - (COLS - 1) / 2.0
	var r := float(i / COLS) - (ROWS - 1) / 2.0
	return c * c + r * r * 1.4 + float(i) * 0.0001


func unlocked_count() -> int:
	var n := 0
	for p in plots:
		if p["state"] != "locked":
			n += 1
	return n


func max_plots() -> int:
	return mini(int(fx.get("max_plots", 9999)), plots.size())


func plot_prices() -> Dictionary:
	var n: int = maxi(0, unlocked_count() - start_plots)
	var buy: int = int(round(90.0 * pow(1.12, n)))
	var lease: int = int(round(float(buy) * 0.2 * fxf("rent_mult")))
	return {"buy": buy, "lease": maxi(1, lease)}


func plot_unlock_error(idx: int, lease: bool) -> String:
	var p: Dictionary = plots[idx]
	if p["state"] != "locked":
		return "Already yours"
	if unlocked_count() >= max_plots():
		return "Plot limit reached (%d)" % max_plots()
	var prices := plot_prices()
	if not lease and fxb("no_plot_buy"):
		return "Buying land is not allowed in this run"
	var cost: int = prices["lease"] if lease else prices["buy"]
	if money < cost:
		return "Not enough money"
	return ""


func buy_plot(idx: int, lease: bool) -> String:
	var err := plot_unlock_error(idx, lease)
	if err != "":
		return err
	var prices := plot_prices()
	var p: Dictionary = plots[idx]
	if lease:
		_spend(prices["lease"])
		p["state"] = "leased"
		p["fee"] = prices["lease"]
		p["paid"] = 0
	else:
		_spend(prices["buy"])
		p["state"] = "owned"
		p["paid"] = prices["buy"]
	p["fertility"] = 1.0
	changed.emit()
	return ""


func _clear_plot(p: Dictionary) -> void:
	p["crop"] = ""
	p["progress"] = 0.0
	p["ready"] = false


# ------------------------------------------------------------------ bans / availability

func tags_banned(tags: Array) -> bool:
	for t in tags:
		if fx["ban_tags"].has(t):
			return true
	return false


func item_banned(id: String) -> bool:
	return tags_banned(db.item_tags(id))


func crop_banned(cid: String) -> bool:
	var c: Dictionary = db.crops[cid]
	return tags_banned(c.get("tags", [])) or item_banned(c["yield_item"]) or item_banned(c["seed"])


func recipe_banned(rid: String) -> bool:
	var r: Dictionary = db.recipes[rid]
	if tags_banned(r.get("tags", [])):
		return true
	if tags_banned(db.machines[r["machine"]].get("tags", [])):
		return true
	for k in r["inputs"]:
		if item_banned(k):
			return true
	for k in r["outputs"]:
		if item_banned(k):
			return true
	return false


func available_recipes(mid: String) -> Array:
	var out: Array = []
	for rid in db.recipes_for(mid):
		if not recipe_banned(rid):
			out.append(rid)
	return out


func machine_available(mid: String) -> bool:
	return not available_recipes(mid).is_empty()


func available_crops() -> Array:
	var out: Array = []
	for cid in db.crops:
		if not crop_banned(cid):
			out.append(cid)
	return out


# ------------------------------------------------------------------ inventory

static func key_of(id: String, q: int = 0) -> String:
	return "%s:%d" % [id, q]


static func key_item(k: String) -> String:
	return k.get_slice(":", 0)


static func key_quality(k: String) -> int:
	return int(k.get_slice(":", 1))


func count_item(id: String, min_q: int = 0) -> int:
	var n := 0
	for q in range(min_q, 3):
		n += int(inventory.get(key_of(id, q), 0))
	return n


func _add_item(id: String, n: int, q: int = 0, announce: bool = true) -> void:
	if n <= 0:
		return
	var k := key_of(id, q)
	inventory[k] = int(inventory.get(k, 0)) + n
	if announce:
		_discover("items", id)


func _remove_key(k: String, n: int) -> void:
	var left: int = int(inventory.get(k, 0)) - n
	if left <= 0:
		inventory.erase(k)
	else:
		inventory[k] = left


## Consumes the lowest qualities first. Returns the summed quality of consumed units, or -1.
func _consume(id: String, n: int, min_q: int = 0) -> int:
	if count_item(id, min_q) < n:
		return -1
	var qsum := 0
	var left := n
	for q in range(min_q, 3):
		var k := key_of(id, q)
		var take: int = mini(int(inventory.get(k, 0)), left)
		if take > 0:
			_remove_key(k, take)
			qsum += take * q
			left -= take
		if left == 0:
			break
	return qsum


func inventory_keys_sorted() -> Array:
	var keys: Array = inventory.keys()
	keys.sort_custom(func(a, b):
		var ia: Dictionary = db.items.get(key_item(a), {})
		var ib: Dictionary = db.items.get(key_item(b), {})
		var pa: float = float(ia.get("base_price", 0))
		var pb: float = float(ib.get("base_price", 0))
		if pa != pb:
			return pa < pb
		return a < b)
	return keys


# ------------------------------------------------------------------ farming actions

func crop_season_error(cid: String) -> String:
	var c: Dictionary = db.crops[cid]
	if not c["seasons"].has(season_id):
		return "%s can't grow in %s" % [db.item_name(cid), db.seasons[season_id]["name"]]
	return ""


func plant_error(idx: int, cid: String) -> String:
	var p: Dictionary = plots[idx]
	if p["state"] == "locked":
		return "That plot isn't yours yet"
	if p["crop"] != "":
		return "Plot is occupied"
	if not db.crops.has(cid):
		return "Unknown crop"
	if crop_banned(cid):
		return "Banned by a challenge"
	var e := crop_season_error(cid)
	if e != "":
		return e
	if fxb("one_crop_per_season") and season_crops.has(season_id) and season_crops[season_id] != cid:
		return "Only one crop type per season (%s)" % db.item_name(season_crops[season_id])
	if count_item(db.crops[cid]["seed"]) <= 0:
		return "Out of %s" % db.item_name(db.crops[cid]["seed"])
	return ""


func plant(idx: int, cid: String) -> String:
	var err := plant_error(idx, cid)
	if err != "":
		return err
	_consume(db.crops[cid]["seed"], 1)
	var p: Dictionary = plots[idx]
	p["crop"] = cid
	p["progress"] = 0.0
	p["ready"] = false
	season_crops[season_id] = cid
	changed.emit()
	return ""


func harvest(idx: int) -> bool:
	var p: Dictionary = plots[idx]
	if p["crop"] == "" or not p["ready"]:
		return false
	var cid: String = p["crop"]
	var c: Dictionary = db.crops[cid]
	var fert: float = p["fertility"]
	var yr: Array = c.get("yield", [1, 1])
	var n: int = rng.randi_range(int(yr[0]), int(yr[1]))
	n = maxi(1, int(round(float(n) * (0.6 + 0.4 * fert))))
	var p_great := clampf((fert - 0.85) * 2.0, 0.0, 0.4)
	var p_good := clampf((fert - 0.45) * 1.0, 0.0, 0.6)
	var counts := [0, 0, 0]
	for i in n:
		var r := rng.randf()
		if r < p_great:
			counts[2] += 1
		elif r < p_great + p_good:
			counts[1] += 1
		else:
			counts[0] += 1
	for q in 3:
		_add_item(c["yield_item"], counts[q], q)
	for bid in c.get("byproduct", {}):
		var br: Array = c["byproduct"][bid]
		_add_item(str(bid), rng.randi_range(int(br[0]), int(br[1])), 0)
	var loss: float = float(c.get("fertility_cost", 0.12)) * fxf("fertility_loss_mult")
	if p["last_crop"] == cid:
		loss += 0.08 * fxf("fertility_loss_mult")   # monoculture wears the soil faster
	p["fertility"] = maxf(0.15, fert - loss)
	p["last_crop"] = cid
	_clear_plot(p)
	today["harvested"][c["yield_item"]] = int(today["harvested"].get(c["yield_item"], 0)) + n
	stats["harvested"] += n
	_discover("crops", cid)
	changed.emit()
	return true


func fertilize_error(idx: int) -> String:
	var p: Dictionary = plots[idx]
	if p["state"] == "locked":
		return "That plot isn't yours yet"
	if p["fertility"] >= 0.99:
		return "Soil is already perfect"
	if count_item("compost") <= 0:
		return "No compost"
	return ""


func fertilize(idx: int) -> String:
	var err := fertilize_error(idx)
	if err != "":
		return err
	_consume("compost", 1)
	plots[idx]["fertility"] = minf(1.0, float(plots[idx]["fertility"]) + 0.4)
	changed.emit()
	return ""


# ------------------------------------------------------------------ market

func unit_price(id: String, q: int, dem: float) -> float:
	return float(db.items[id].get("base_price", 0)) * dem * QUALITY_MULT[q] * fxf("price_mult")


func sell_value(k: String, qty: int) -> int:
	var id := key_item(k)
	var q := key_quality(k)
	var n: int = mini(qty, int(inventory.get(k, 0)))
	var d: float = demand.get(id, 1.0)
	var total := 0.0
	for i in n:
		total += unit_price(id, q, d)
		d = maxf(0.4, d * 0.97)
	return int(round(total))


func sellable(id: String) -> bool:
	return bool(db.items[id].get("sellable", true))


func sell(k: String, qty: int) -> int:
	var id := key_item(k)
	if not inventory.has(k) or not sellable(id):
		return 0
	var n: int = mini(qty, int(inventory[k]))
	if n <= 0:
		return 0
	var total := sell_value(k, n)
	var d: float = demand.get(id, 1.0)
	for i in n:
		d = maxf(0.4, d * 0.97)
	demand[id] = d
	_remove_key(k, n)
	_earn(total)
	stats["sold"] += n
	today["sold"][id] = int(today["sold"].get(id, 0)) + n
	changed.emit()
	return total


# ------------------------------------------------------------------ orders

func _top_up_orders() -> void:
	if fxb("no_orders"):
		return
	var candidates: Array = []
	for iid in db.items:
		var def: Dictionary = db.items[iid]
		if not sellable(iid) or item_banned(iid):
			continue
		if def.get("category", "") in ["byproduct", "seed"]:
			continue
		candidates.append(iid)
	if candidates.is_empty():
		return
	var tries := 0
	while orders.size() < MAX_ORDERS and tries < 6:
		tries += 1
		if rng.randf() > 0.55:
			continue
		var iid: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		var base: float = float(db.items[iid].get("base_price", 5))
		var qty: int = clampi(int(round(60.0 / maxf(base, 1.0) * rng.randf_range(0.7, 1.3))), 1, 8)
		var min_q: int = 0
		if rng.randf() < 0.25:
			min_q = 1
		var mult: float = rng.randf_range(1.5, 2.0) + 0.25 * min_q
		orders.append({
			"id": next_order_id, "item": iid, "qty": qty, "min_q": min_q,
			"reward": int(round(base * qty * mult * fxf("price_mult"))),
			"deadline": day + rng.randi_range(3, 6)})
		next_order_id += 1


func order_error(i: int) -> String:
	if i < 0 or i >= orders.size():
		return "Order is gone"
	var o: Dictionary = orders[i]
	if count_item(o["item"], o["min_q"]) < int(o["qty"]):
		return "Not enough %s" % db.item_name(o["item"])
	return ""


func fulfill_order(i: int) -> String:
	var err := order_error(i)
	if err != "":
		return err
	var o: Dictionary = orders[i]
	_consume(o["item"], int(o["qty"]), int(o["min_q"]))
	_earn(int(o["reward"]))
	_note("Order delivered: %d x %s (+$%d)" % [o["qty"], db.item_name(o["item"]), o["reward"]], "good")
	orders.remove_at(i)
	changed.emit()
	return ""


# ------------------------------------------------------------------ machines

func machine_slots(mid: String) -> int:
	return maxi(1, int(machines[mid]["owned"]))


func machine_rent(mid: String) -> int:
	return int(round(float(db.machines[mid].get("rent", 3)) * fxf("rent_mult")))


func machine_use_error(mid: String) -> String:
	if not machine_available(mid):
		return "Banned by a challenge"
	var limit: int = int(fx.get("max_machine_types", 9999))
	if not used_machines.has(mid) and used_machines.size() >= limit:
		return "Limit: only %d machine type%s" % [limit, "" if limit == 1 else "s"]
	return ""


func machine_buy_error(mid: String) -> String:
	if fxb("no_machine_buy"):
		return "Buying machines is not allowed in this run"
	var e := machine_use_error(mid)
	if e != "":
		return e
	if money < int(db.machines[mid]["buy_cost"]):
		return "Not enough money"
	return ""


func buy_machine(mid: String) -> String:
	var err := machine_buy_error(mid)
	if err != "":
		return err
	_spend(int(db.machines[mid]["buy_cost"]))
	machines[mid]["owned"] = int(machines[mid]["owned"]) + 1
	if not used_machines.has(mid):
		used_machines.append(mid)
	_discover("machines", mid)
	changed.emit()
	return ""


func has_inputs(rid: String) -> bool:
	for k in db.recipes[rid]["inputs"]:
		if count_item(k) < int(db.recipes[rid]["inputs"][k]):
			return false
	return true


func queue_error(mid: String, rid: String) -> String:
	var e := machine_use_error(mid)
	if e != "":
		return e
	if recipe_banned(rid):
		return "Banned by a challenge"
	if machines[mid]["queue"].size() >= MAX_QUEUE:
		return "Queue is full"
	if not has_inputs(rid):
		return "Missing ingredients"
	if int(machines[mid]["owned"]) == 0 and money < machine_rent(mid):
		return "Can't afford the rent"
	return ""


## Queues up to qty batches. Returns the number actually queued.
func queue_job(mid: String, rid: String, qty: int) -> int:
	var r: Dictionary = db.recipes[rid]
	var done := 0
	for i in qty:
		if queue_error(mid, rid) != "":
			break
		var qsum := 0
		var units := 0
		for k in r["inputs"]:
			var n: int = int(r["inputs"][k])
			qsum += _consume(k, n)
			units += n
		var q: int = int(floor(float(qsum) / maxf(1.0, float(units))))
		if int(machines[mid]["owned"]) == 0:
			_spend(machine_rent(mid))
		if not used_machines.has(mid):
			used_machines.append(mid)
			_discover("machines", mid)
		machines[mid]["queue"].append({"recipe": rid, "remaining": float(r["time"]), "q": q})
		done += 1
	if done > 0:
		changed.emit()
	return done


func _finish_job(job: Dictionary) -> void:
	var r: Dictionary = db.recipes[job["recipe"]]
	var q: int = int(job["q"])
	for k in r["outputs"]:
		var n: int = int(r["outputs"][k])
		var cq: int = q if db.items[k].get("category", "") not in ["byproduct", "seed"] else 0
		_add_item(k, n, cq)
		today["crafted"][k] = int(today["crafted"].get(k, 0)) + n
		stats["crafted"] += n
	_discover("recipes", job["recipe"])


func _tick_machines(dt: float) -> void:
	var any_done := false
	for mid in machines:
		var m: Dictionary = machines[mid]
		var q: Array = m["queue"]
		if q.is_empty():
			continue
		var slots := machine_slots(mid)
		var i := 0
		while i < q.size() and i < slots:
			q[i]["remaining"] = float(q[i]["remaining"]) - dt
			i += 1
		i = 0
		while i < q.size() and i < slots:
			if float(q[i]["remaining"]) <= 0.0:
				_finish_job(q[i])
				q.remove_at(i)
				any_done = true
			else:
				i += 1
	if any_done:
		changed.emit()


# ------------------------------------------------------------------ time

func tick(dt: float) -> void:
	if waiting_next_day or finished or dt <= 0.0:
		return
	var step: float = minf(dt, day_length - day_time)
	_tick_growth(step)
	_tick_machines(step)
	day_time += step
	if day_time >= day_length - 0.0001:
		_end_day()


func _tick_growth(dt: float) -> void:
	var gm: float = float(db.weather[weather_today].get("growth_mult", 1.0)) * fxf("growth_mult")
	var became_ready := false
	for p in plots:
		if p["crop"] == "" or p["ready"]:
			continue
		var c: Dictionary = db.crops[p["crop"]]
		var soil: float = 0.6 + 0.4 * float(p["fertility"])
		p["progress"] = float(p["progress"]) + dt / (day_length * float(c["grow_days"])) * gm * soil
		if p["progress"] >= 1.0:
			p["progress"] = 1.0
			p["ready"] = true
			became_ready = true
	if became_ready:
		changed.emit()


func _end_day() -> void:
	day_time = day_length
	var spoiled := 0
	var rate := fxf("spoilage_rate", 0.0)
	if rate > 0.0:
		for k in inventory.keys():
			if db.item_tags(key_item(k)).has("perishable"):
				var lost := 0
				for i in int(inventory[k]):
					if rng.randf() < rate:
						lost += 1
				if lost > 0:
					_remove_key(k, lost)
					spoiled += lost
		if spoiled > 0:
			_note("%d perishable item%s spoiled overnight." % [spoiled, "" if spoiled == 1 else "s"], "bad")
	var wf := fxf("waste_fee", 0.0)
	if wf > 0.0:
		var waste := 0
		for k in inventory:
			if db.item_tags(key_item(k)).has("byproduct"):
				waste += int(inventory[k])
		if waste > 0:
			var fee: int = int(ceil(float(waste) * wf))
			money -= fee
			today["expenses"] += fee
			_note("Waste disposal fee for %d byproduct%s: -$%d" % [waste, "" if waste == 1 else "s", fee], "bad")
	var expired: Array = []
	for o in orders:
		if int(o["deadline"]) <= day:
			expired.append(o)
	for o in expired:
		orders.erase(o)
		_note("Order for %d x %s expired." % [o["qty"], db.item_name(o["item"])], "bad")
	stats["days"] += 1
	waiting_next_day = true
	var summary := {
		"day": day, "run_day": run_day(), "season": season_id, "weather": weather_today,
		"income": today["income"], "expenses": today["expenses"],
		"sold": today["sold"].duplicate(), "harvested": today["harvested"].duplicate(),
		"crafted": today["crafted"].duplicate(), "notes": today["notes"].duplicate(),
		"money": money, "net_worth": net_worth(),
		"tomorrow": "" if fxb("no_forecast") else weather_tomorrow}
	var goal = cfg.get("goal", null)
	if typeof(goal) == TYPE_DICTIONARY and run_day() >= int(goal.get("days", 999999)):
		_finish_run()   # before day_ended, so the summary knows the run is over
	day_ended.emit(summary)
	changed.emit()


## Fast-forwards the rest of today (crops and machines keep running).
func skip_to_evening() -> void:
	if not waiting_next_day and not finished:
		tick(day_length - day_time)


func start_next_day() -> void:
	if finished or not waiting_next_day:
		return
	var prev_season := season_id
	day += 1
	_apply_season(day)
	day_time = 0.0
	waiting_next_day = false
	weather_today = weather_tomorrow
	weather_tomorrow = _roll_weather(season_info(day + 1)["id"])
	today = _new_ledger()
	if season_id != prev_season:
		_on_new_season()
	_update_demand()
	for p in plots:
		if p["state"] != "locked" and p["crop"] == "":
			p["fertility"] = minf(1.0, float(p["fertility"]) + 0.05)
	_apply_weather_effects()
	_top_up_orders()
	_discover("weather", weather_today)
	changed.emit()


func _on_new_season() -> void:
	season_crops.clear()
	_discover("seasons", season_id)
	_note("%s begins!" % db.seasons[season_id]["name"], "info")
	for i in plots.size():
		var p: Dictionary = plots[i]
		if p["state"] == "leased":
			var fee: int = int(p["fee"])
			if auto_renew and money >= fee:
				_spend(fee)
				_note("Renewed a plot lease (-$%d)." % fee, "info")
			else:
				_clear_plot(p)
				p["state"] = "locked"
				_note("A plot lease expired.", "bad")
	var withered := 0
	for p in plots:
		if p["crop"] != "" and not p["ready"] and not db.crops[p["crop"]]["seasons"].has(season_id):
			_clear_plot(p)
			withered += 1
	if withered > 0:
		_note("%d unfinished crop%s withered with the season." % [withered, "" if withered == 1 else "s"], "bad")


func _update_demand() -> void:
	var rec: float = 0.35 * fxf("demand_recovery_mult")
	for iid in db.items:
		var target: float = float(db.items[iid].get("season_demand", {}).get(season_id, 1.0))
		var d: float = demand.get(iid, 1.0)
		d += (target - d) * rec
		d += rng.randf_range(-0.04, 0.04)
		demand[iid] = clampf(d, 0.4, 1.8)


# ------------------------------------------------------------------ scoring

func net_worth() -> int:
	var total := float(money)
	for mid in machines:
		total += float(machines[mid]["owned"]) * float(db.machines[mid]["buy_cost"]) * 0.6
	for p in plots:
		total += float(p["paid"]) * 0.6
	for k in inventory:
		total += float(inventory[k]) * float(db.items[key_item(k)].get("base_price", 0)) * 0.8
	return int(round(total))


func goal_target() -> int:
	var goal = cfg.get("goal", null)
	if typeof(goal) != TYPE_DICTIONARY:
		return 0
	var gm: float = float(db.difficulties[cfg.get("difficulty", "normal")].get("goal_mult", 1.0))
	return int(round(float(goal.get("target", 0)) * gm))


func score_multiplier() -> float:
	var m: float = float(db.difficulties[cfg.get("difficulty", "normal")].get("score_mult", 1.0))
	for mid in cfg.get("active_modifiers", []):
		m *= float(db.modifiers.get(mid, {}).get("score_mult", 1.0))
	return m


func run_key() -> String:
	var key: String = str(cfg.get("mode", "endless"))
	if cfg.has("scenario"):
		key += ":" + str(cfg["scenario"])
	return "%s:%s" % [key, cfg.get("difficulty", "normal")]


func _finish_run() -> void:
	finished = true
	var nw := net_worth()
	var target := goal_target()
	var score: int = int(round(float(nw) * score_multiplier()))
	var stars := 0
	if target > 0:
		if nw >= target:
			stars = 1
		if nw >= int(target * 1.5):
			stars = 2
		if nw >= int(target * 2.5):
			stars = 3
	var new_best := false
	if journal != null:
		new_best = journal.record_run(run_key(), score, stars > 0, run_day())
		journal.lifetime["income"] += int(stats["income"])
		journal.lifetime["harvested"] += int(stats["harvested"])
		journal.lifetime["crafted"] += int(stats["crafted"])
		journal.save()
	run_finished.emit({"net_worth": nw, "target": target, "score": score, "stars": stars,
			"success": stars > 0, "multiplier": score_multiplier(), "new_best": new_best,
			"days": run_day()})


## Lets the player keep farming after a finished run.
func continue_endless() -> void:
	finished = false
	cfg["goal"] = null
	changed.emit()


# ------------------------------------------------------------------ helpers

func _new_ledger() -> Dictionary:
	return {"income": 0, "expenses": 0, "sold": {}, "harvested": {}, "crafted": {}, "notes": []}


func _earn(amount: int) -> void:
	money += amount
	today["income"] += amount
	stats["income"] += amount


func _spend(amount: int) -> void:
	money -= amount
	today["expenses"] += amount
	stats["expenses"] += amount


func _note(text: String, kind: String = "info") -> void:
	today["notes"].append(text)
	event.emit(text, kind)


func _discover(kind: String, id: String) -> void:
	if journal != null and journal.discover(kind, id):
		var label := id
		match kind:
			"items": label = db.item_name(id)
			"crops": label = db.item_name(db.crops[id]["yield_item"]) if db.crops.has(id) else id
			"recipes": label = db.item_name(db.recipes[id]["outputs"].keys()[0]) if db.recipes.has(id) else id
			"machines": label = str(db.machines.get(id, {}).get("name", id))
			"weather": label = str(db.weather.get(id, {}).get("name", id))
			"seasons": label = str(db.seasons.get(id, {}).get("name", id))
		event.emit("Journal: new %s entry - %s" % [kind.trim_suffix("s"), label], "journal")


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	return {
		"version": 1, "cfg": cfg, "day": day, "start_day": start_day, "day_time": day_time,
		"waiting_next_day": waiting_next_day, "weather_today": weather_today,
		"weather_tomorrow": weather_tomorrow, "money": money, "plots": plots,
		"machines": machines, "inventory": inventory, "demand": demand, "orders": orders,
		"next_order_id": next_order_id, "season_crops": season_crops, "used_machines": used_machines,
		"auto_renew": auto_renew, "start_plots": start_plots, "today": today, "stats": stats,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}


static func restore(p_db: ContentDB, d: Dictionary, p_journal: Journal = null) -> FarmState:
	var s := FarmState.new()
	s.db = p_db
	s.journal = p_journal
	s.cfg = d["cfg"].duplicate(true)
	s.fx = s._build_fx()
	var diff: Dictionary = p_db.difficulties[s.cfg.get("difficulty", "normal")]
	s.day_length = float(diff.get("day_length", 180)) * s.fxf("time_mult")
	s.day = int(d["day"])
	s.start_day = int(d["start_day"])
	s.day_time = float(d["day_time"])
	s.waiting_next_day = bool(d["waiting_next_day"])
	s.weather_today = d["weather_today"]
	s.weather_tomorrow = d["weather_tomorrow"]
	s.money = int(d["money"])
	s.plots = d["plots"].duplicate(true)
	s.machines = d["machines"].duplicate(true)
	s.inventory = d["inventory"].duplicate(true)
	s.demand = d["demand"].duplicate(true)
	s.orders = d["orders"].duplicate(true)
	s.next_order_id = int(d["next_order_id"])
	s.season_crops = d["season_crops"].duplicate(true)
	s.used_machines = d["used_machines"].duplicate(true)
	s.auto_renew = bool(d["auto_renew"])
	s.start_plots = int(d["start_plots"])
	s.today = d["today"].duplicate(true)
	s.stats = d["stats"].duplicate(true)
	s.rng.seed = int(d["rng_seed"])
	s.rng.state = int(d["rng_state"])
	s._apply_season(s.day)
	for mid in p_db.machines:
		if not s.machines.has(mid):
			s.machines[mid] = {"owned": 0, "queue": []}
	return s
