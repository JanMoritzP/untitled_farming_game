extends SceneTree
## Headless simulation tests.  Run with:  godot --headless --path . -s tests/test_sim.gd

var db: ContentDB
var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func first_locked(s: FarmState) -> int:
	for i in s.plots.size():
		if s.plots[i].state == "locked":
			return i
	return -1


func cfg(extra: Dictionary = {}) -> Dictionary:
	var c := {"mode": "endless", "difficulty": "normal", "modifiers": [], "seed": 42, "goal": null}
	c.merge(extra, true)
	return c


func _initialize() -> void:
	db = ContentDB.new()
	db.load_all(false)
	test_content()
	test_farming()
	test_machines()
	test_market_and_orders()
	test_days_and_seasons()
	test_modifiers()
	test_save_load()
	test_mod_loading()
	test_bot_runs()
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_content() -> void:
	print("content")
	check(db.errors.is_empty(), "content loads without errors: %s" % str(db.errors))
	check(db.items.size() > 20 and db.crops.size() >= 6 and db.recipes.size() >= 10, "content counts")
	check(db.season_ids() == ["spring", "summer", "autumn", "winter"], "season order")
	for rid in db.recipes:
		var r: Dictionary = db.recipes[rid]
		var in_val := 0.0
		for k in r.inputs:
			in_val += float(db.items[k].base_price) * float(r.inputs[k])
		var out_val := 0.0
		for k in r.outputs:
			out_val += float(db.items[k].base_price) * float(r.outputs[k])
		if rid != "compost":
			check(out_val >= in_val, "recipe %s adds value (%.0f -> %.0f)" % [rid, in_val, out_val])


func test_farming() -> void:
	print("farming")
	var s := FarmState.create(db, cfg(), Journal.new())
	check(s.money == 250, "start money")
	check(s.season_id == "spring" and s.day == 1, "starts in spring")
	var owned := []
	for i in s.plots.size():
		if s.plots[i].state == "owned":
			owned.append(i)
	check(owned.size() == 6, "6 starting plots")
	check(s.plant(owned[0], "wheat") == "", "plant wheat")
	check(s.plant(owned[0], "wheat") != "", "can't double plant")
	check(s.plant(owned[1], "pumpkin") != "", "pumpkin out of season / no seeds")
	check(s.count_item("wheat_seed") == 11, "seed consumed")
	var guard := 0
	while not s.plots[owned[0]].ready and guard < 5000:
		s.tick(1.0)
		guard += 1
		if s.waiting_next_day:
			s.start_next_day()
	check(s.plots[owned[0]].ready, "wheat becomes ready")
	check(s.harvest(owned[0]), "harvest")
	check(s.count_item("wheat") >= 2, "got wheat")
	check(s.count_item("straw") >= 1, "got straw byproduct")
	check(s.plots[owned[0]].fertility < 1.0, "fertility drained")
	check(s.plots[owned[0]].last_crop == "wheat", "last crop remembered")
	s._add_item("compost", 1)
	check(s.fertilize(owned[0]) == "", "fertilize")
	var p := s.plot_prices()
	var locked := -1
	for i in s.plots.size():
		if s.plots[i].state == "locked":
			locked = i
			break
	s.money = 1000
	check(s.buy_plot(locked, true) == "", "lease plot")
	check(s.plots[locked].state == "leased", "plot leased")
	var p2 := s.plot_prices()
	check(p2.buy > p.buy, "plot prices rise as you expand")


func test_machines() -> void:
	print("machines")
	var s := FarmState.create(db, cfg(), Journal.new())
	s._add_item("wheat", 6)
	check(s.queue_job("mill", "flour", 5) == 2, "queues 2 batches (6 wheat, 3 per batch)")
	check(s.money == 250 - 2 * s.machine_rent("mill"), "rent paid per batch")
	for i in 6:
		s.tick(1.0)
	check(s.count_item("flour") == 2, "mill runs one batch at a time (2 flour after 6s)")
	for i in 5:
		s.tick(1.0)
	check(s.count_item("flour") == 4, "second batch done after 11s")
	s.money = 1000
	check(s.buy_machine("mill") == "", "buy mill")
	s._add_item("wheat", 9)
	var before := s.money
	check(s.queue_job("mill", "flour", 3) == 3, "owned machine queues")
	check(s.money == before, "owned machine has no rent")
	for i in 6:
		s.tick(1.0)
	check(s.count_item("flour") == 4 + 2, "owned mill ran first batch")
	s.buy_machine("mill")
	for i in 10:
		s.tick(1.0)
	check(s.count_item("flour") >= 4 + 4, "two mills run in parallel")
	# quality propagation
	var s2 := FarmState.create(db, cfg(), Journal.new())
	s2._add_item("wheat", 3, 2)
	s2.queue_job("mill", "flour", 1)
	for i in 11:
		s2.tick(1.0)
	check(s2.count_item("flour", 2) == 2, "gold wheat makes gold flour")
	# lowest quality consumed first
	var s3 := FarmState.create(db, cfg(), Journal.new())
	s3._add_item("flour", 2, 0)
	s3._add_item("flour", 2, 2)
	s3.queue_job("oven", "bread", 1)
	check(s3.count_item("flour", 2) == 2, "lowest quality consumed first")


func test_market_and_orders() -> void:
	print("market")
	var s := FarmState.create(db, cfg(), Journal.new())
	s._add_item("bread", 10)
	var one := s.sell_value("bread:0", 1)
	var ten := s.sell_value("bread:0", 10)
	check(one == 19, "bread sells at base price")
	check(ten < one * 10, "selling many saturates the market")
	var m := s.money
	var got := s.sell("bread:0", 10)
	check(got == ten and s.money == m + ten, "sell pays previewed value")
	check(s.demand["bread"] < 0.8, "demand dropped")
	s._add_item("bread", 1)
	check(s.sell_value("bread:0", 1) < 19, "price lower after flooding")
	check(s.sell("wheat_seed:0", 1) == 0, "seeds not sellable")
	s._add_item("bread", 5, 2)
	check(s.sell_value("bread:2", 1) > s.sell_value("bread:0", 1), "gold sells for more")
	s.orders = [{"id": 99, "item": "bread", "qty": 3, "min_q": 0, "reward": 100, "deadline": 5}]
	var s_before := s.money
	check(s.fulfill_order(0) == "", "fulfill order")
	check(s.money == s_before + 100 and s.orders.is_empty(), "reward paid")
	s.orders = [{"id": 100, "item": "cake", "qty": 3, "min_q": 0, "reward": 100, "deadline": 5}]
	check(s.fulfill_order(0) != "", "can't fulfill without goods")


func test_days_and_seasons() -> void:
	print("days & seasons")
	var s := FarmState.create(db, cfg(), Journal.new())
	var ended := []
	s.day_ended.connect(func(sum): ended.append(sum))
	s.tick(s.day_length + 5.0)
	check(s.waiting_next_day and ended.size() == 1, "day ends when timer runs out")
	var t := s.day_time
	s.tick(10.0)
	check(s.day_time == t, "time frozen while waiting")
	s.start_next_day()
	check(s.day == 2 and s.day_time == 0.0, "next day starts")
	# run through to winter and check withering + lease lapse
	var s2 := FarmState.create(db, cfg(), Journal.new())
	s2.money = 5000
	var locked := -1
	for i in s2.plots.size():
		if s2.plots[i].state == "locked":
			locked = i
			break
	s2.buy_plot(locked, true)
	var seasons_seen := {}
	for d in 60:
		seasons_seen[s2.season_id] = true
		s2.tick(s2.day_length + 1.0)
		s2.start_next_day()
	check(seasons_seen.size() == 4, "all four seasons occur")
	check(s2.year >= 2, "year rolls over")
	check(s2.plots[locked].state == "leased", "lease auto-renewed with money")
	# no money -> lapse
	var s3 := FarmState.create(db, cfg(), Journal.new())
	s3.money = 1000
	for i in s3.plots.size():
		if s3.plots[i].state == "locked":
			s3.buy_plot(i, true)
			locked = i
			break
	s3.money = 0
	for d in 8:
		s3.tick(s3.day_length + 1.0)
		s3.start_next_day()
	check(s3.plots[locked].state == "locked", "unpaid lease lapses at season change")
	# withering
	var s4 := FarmState.create(db, cfg({"scenario": ""}), Journal.new())
	s4._add_item("strawberry_seed", 1)
	var idx := -1
	for i in s4.plots.size():
		if s4.plots[i].state == "owned":
			idx = i
			break
	s4.plant(idx, "strawberry")
	s4.day = 7
	s4._apply_season(7)
	s4.waiting_next_day = true
	s4.plots[idx].progress = 0.5
	s4.start_next_day()
	check(s4.season_id == "summer" and s4.plots[idx].crop == "strawberry", "strawberry survives into summer")
	s4.day = 14
	s4._apply_season(14)
	s4.waiting_next_day = true
	s4.start_next_day()
	check(s4.season_id == "autumn" and s4.plots[idx].crop == "", "strawberry withers into autumn")
	# goal and finish
	var g := FarmState.create(db, cfg({"goal": {"type": "net_worth", "target": 100, "days": 3}, "mode": "sprint"}), Journal.new())
	var res := []
	g.run_finished.connect(func(r): res.append(r))
	for d in 3:
		g.tick(g.day_length + 1.0)
		if not g.finished:
			g.start_next_day()
	check(g.finished and res.size() == 1, "run finishes after goal days")
	check(res[0].success and res[0].stars >= 1, "net worth 250 beats target 100")
	check(res[0].score == int(round(res[0].net_worth * 1.0)), "score uses multiplier")


func test_modifiers() -> void:
	print("modifiers")
	for mid in db.modifiers:
		var s := FarmState.create(db, cfg({"modifiers": [mid]}), Journal.new())
		s.tick(s.day_length + 1.0)
		s.start_next_day()
		check(s.day == 2, "modifier %s runs" % mid)
	var vegan := FarmState.create(db, cfg({"modifiers": ["vegan"]}), Journal.new())
	check(not vegan.machine_available("coop") and not vegan.machine_available("dairy"), "vegan hides animal machines")
	check(vegan.machine_available("mill"), "vegan keeps mill")
	check(vegan.recipe_banned("cornbread") and vegan.recipe_banned("cake"), "vegan bans recipes using eggs")
	var nb := FarmState.create(db, cfg({"modifiers": ["no_bakery"]}), Journal.new())
	check(not nb.machine_available("oven"), "no bakery hides the oven")
	var om := FarmState.create(db, cfg({"modifiers": ["one_machine"]}), Journal.new())
	om._add_item("wheat", 6)
	om._add_item("potato", 3)
	check(om.queue_job("mill", "flour", 1) == 1, "first machine ok")
	check(om.queue_job("kitchen", "fries", 1) == 0, "second machine type blocked")
	var rent := FarmState.create(db, cfg({"modifiers": ["renters"]}), Journal.new())
	rent.money = 9999
	check(rent.buy_machine("mill") != "", "renter can't buy machines")
	check(rent.buy_plot(first_locked(rent), false) != "", "renter can't buy land")
	var tiny := FarmState.create(db, cfg({"modifiers": ["tiny_plot"], "difficulty": "cozy"}), Journal.new())
	tiny.money = 9999
	var bought := 0
	for i in tiny.plots.size():
		if tiny.plots[i].state == "locked" and tiny.buy_plot(i, false) == "":
			bought += 1
	check(tiny.unlocked_count() == 6, "boutique caps plots at 6 (got %d)" % tiny.unlocked_count())
	var oc := FarmState.create(db, cfg({"modifiers": ["one_crop"]}), Journal.new())
	var owned := []
	for i in oc.plots.size():
		if oc.plots[i].state == "owned":
			owned.append(i)
	check(oc.plant(owned[0], "wheat") == "", "one-crop: first plant ok")
	check(oc.plant(owned[1], "potato") != "", "one-crop: second crop blocked")
	check(oc.plant(owned[1], "wheat") == "", "one-crop: same crop ok")
	var zw := FarmState.create(db, cfg({"modifiers": ["zero_waste"]}), Journal.new())
	zw._add_item("straw", 5)
	var m := zw.money
	zw.tick(zw.day_length + 1.0)
	check(zw.money == m - 5, "zero waste charges for byproducts")
	var nf := FarmState.create(db, cfg({"modifiers": ["no_fridge"]}), Journal.new())
	nf._add_item("egg", 200)
	nf.tick(nf.day_length + 1.0)
	check(nf.count_item("egg") < 200, "perishables spoil")
	var fm := FarmState.create(db, cfg({"modifiers": ["free_market"]}), Journal.new())
	check(fm.orders.is_empty(), "free market has no orders")
	var h := FarmState.create(db, cfg({"modifiers": ["hurried"]}), Journal.new())
	check(is_equal_approx(h.day_length, 54.0), "hurried shortens the day")
	# scenarios
	for sid in db.scenarios:
		var sc := FarmState.create(db, cfg({"mode": "scenario", "scenario": sid, "goal": db.scenarios[sid].goal}), Journal.new())
		sc.tick(sc.day_length + 1.0)
		check(sc.waiting_next_day, "scenario %s runs" % sid)
	var wic := FarmState.create(db, cfg({"scenario": "winter_is_coming"}), Journal.new())
	check(wic.season_id == "autumn", "winter_is_coming starts in autumn")
	var dd := FarmState.create(db, cfg({"scenario": "dairy_dream"}), Journal.new())
	check(dd.machines["cowshed"].owned == 1, "dairy_dream gives a cow shed")


func test_save_load() -> void:
	print("save/load")
	var s := FarmState.create(db, cfg({"modifiers": ["harsh"]}), Journal.new())
	s._add_item("wheat", 9, 1)
	s.queue_job("mill", "flour", 2)
	s.tick(40.0)
	var d := s.to_dict()
	var path := "user://test_save.dat"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_var(d)
	f.close()
	var loaded = FileAccess.open(path, FileAccess.READ).get_var()
	var r := FarmState.restore(db, loaded, Journal.new())
	check(r.money == s.money and r.day == s.day and is_equal_approx(r.day_time, s.day_time), "basic fields")
	check(r.inventory == s.inventory, "inventory")
	check(r.plots == s.plots, "plots")
	check(r.machines == s.machines, "machines")
	for i in 50:
		s.tick(5.0)
		r.tick(5.0)
		if s.waiting_next_day:
			s.start_next_day()
		if r.waiting_next_day:
			r.start_next_day()
	check(r.money == s.money and r.day == s.day and r.weather_today == s.weather_today, "deterministic after restore (rng state)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# journal persistence
	var j := Journal.new()
	j.save_path = "user://test_journal.dat"
	j.discover("items", "wheat")
	j.record_run("classic:normal", 1234, true, 28)
	j.save()
	var j2 := Journal.new()
	j2.save_path = "user://test_journal.dat"
	j2.load_from_disk()
	check(j2.has("items", "wheat") and j2.best_scores["classic:normal"] == 1234, "journal round-trips")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_journal.dat"))


func test_mod_loading() -> void:
	print("mods")
	var mdb := ContentDB.new()
	mdb.load_all(false)
	var wheat_price: int = int(mdb.items["wheat"].base_price)
	mdb._load_dir("res://docs/example_mod/data", "radish_pack")
	mdb._validate()
	check(mdb.errors.is_empty(), "example mod validates: %s" % str(mdb.errors))
	check(mdb.crops.has("radish") and mdb.items.has("pickles") and mdb.recipes.has("pickles"), "mod content added")
	check(mdb.crop_by_seed.get("radish_seed", "") == "radish", "mod seed registered")
	check(int(mdb.items["wheat"].base_price) == 6 and wheat_price == 5, "patch changed wheat price, kept other fields")
	check(mdb.items["wheat"].has("shape") and mdb.items["wheat"]["_source"] == "radish_pack", "patch merges instead of replacing")
	check(mdb.sources == ["base", "radish_pack"], "sources tracked")
	var s := FarmState.create(mdb, {"mode": "endless", "difficulty": "normal", "modifiers": ["radish_rush"], "seed": 1, "goal": null}, Journal.new())
	s._add_item("radish_seed", 1)
	var idx := -1
	for i in s.plots.size():
		if s.plots[i].state == "owned":
			idx = i
			break
	check(s.plant(idx, "radish") == "", "plant a modded crop")
	for i in 200:
		s.tick(1.0)
	check(s.plots[idx].ready, "modded crop grows (radish_rush doubles speed)")
	s.harvest(idx)
	check(s.count_item("radish") >= 3, "modded crop harvested")
	s._add_item("radish", 3)
	check(s.queue_job("kitchen", "pickles", 1) == 1, "modded recipe runs on a base machine")
	# a broken mod must not crash the game
	var bad := ContentDB.new()
	bad.load_all(false)
	bad.crops["ghost"] = {"id": "ghost", "seed": "nope", "yield_item": "nope", "seasons": []}
	bad.recipes["ghost"] = {"id": "ghost", "machine": "nowhere", "inputs": {}, "outputs": {}}
	bad._validate()
	check(not bad.crops.has("ghost") and not bad.recipes.has("ghost") and bad.errors.size() == 2, "invalid entries are dropped with errors")


## A simple greedy bot: plants what it can, sells everything, crafts when possible.
func run_bot(config: Dictionary, days: int) -> Dictionary:
	var s := FarmState.create(db, config, Journal.new())
	for d in days:
		var guard := 0
		while not s.waiting_next_day and guard < 100000:
			guard += 1
			for i in s.plots.size():
				if s.plots[i].ready:
					s.harvest(i)
			# craft everything possible
			for mid in s.machines:
				if not s.machine_available(mid):
					continue
				for rid in s.available_recipes(mid):
					if rid == "compost":
						continue
					while s.queue_job(mid, rid, 1) == 1:
						pass
			# plant
			for cid in s.available_crops():
				for i in s.plots.size():
					if s.plots[i].state != "locked" and s.plots[i].crop == "":
						var seed: String = db.crops[cid].seed
						if s.count_item(seed) == 0 and s.money > 60 and s.crop_season_error(cid) == "":
							s.money -= int(db.items[seed].buy_price)
							s._add_item(seed, 1)
						if s.plant(i, cid) != "":
							break
			s.tick(2.0)
		# sell everything that is a final product
		for k in s.inventory.keys():
			var id: String = FarmState.key_item(k)
			if s.sellable(id) and not (db.items[id].category in ["crop", "ingredient", "animal"] and d < days - 1):
				s.sell(k, 999)
		if not s.finished:
			s.start_next_day()
	return {"money": s.money, "net_worth": s.net_worth(), "day": s.day}


func test_bot_runs() -> void:
	print("bot runs")
	for diff in ["cozy", "normal", "hard"]:
		var r := run_bot(cfg({"difficulty": diff}), 28)
		print("  %s: day %d, money %d, net worth %d" % [diff, r.day, r.money, r.net_worth])
		check(r.day == 29, "%s bot survives 28 days" % diff)
		check(r.net_worth > 200, "%s bot does not go bankrupt" % diff)
