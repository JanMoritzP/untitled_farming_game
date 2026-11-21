extends SceneTree
## Balance probe: a greedy bot plays full runs so goal targets can be tuned.
##   godot --headless --path . -s tests/balance.gd

var db: ContentDB


func _initialize() -> void:
	db = ContentDB.new()
	db.load_all(false)
	var lengths := [14, 28, 84]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		lengths = [int(args[0])]
	for n in lengths:
		for diff in ["cozy", "normal", "hard"]:
			var results: Array = []
			for sd in [1, 2, 3]:
				results.append(play({"mode": "classic", "difficulty": diff, "modifiers": [], "seed": sd, "goal": null}, n))
			var avg := 0
			for r in results:
				avg += r
			print("%3d days  %-7s net worth: %s  (avg %d)" % [n, diff, str(results), avg / results.size()])
	quit()


func input_ids() -> Dictionary:
	var out := {}
	for rid in db.recipes:
		for k in db.recipes[rid].inputs:
			out[k] = true
	return out


func play(cfg: Dictionary, days: int) -> int:
	var s := FarmState.create(db, cfg, Journal.new())
	var inputs := input_ids()
	var machine_order := ["mill", "kitchen", "preserves", "oven", "dairy", "coop", "cowshed"]
	for d in days:
		var guard := 0
		while not s.waiting_next_day and guard < 100000:
			guard += 1
			for i in s.plots.size():
				if s.plots[i].ready:
					s.harvest(i)
			# expand land
			var pr := s.plot_prices()
			for i in s.plots.size():
				if s.plots[i].state == "locked" and s.money > pr.buy + 120 and s.unlocked_count() < s.max_plots():
					s.buy_plot(i, false)
					break
			# buy machines
			for mid in machine_order:
				if s.machines[mid].owned == 0 and s.machine_available(mid) and s.money > int(db.machines[mid].buy_cost) * 1.4 and s.unlocked_count() >= 6:
					s.buy_machine(mid)
					break
			# craft whatever has inputs, best value first
			for mid in s.machines:
				if not s.machine_available(mid):
					continue
				for rid in s.available_recipes(mid):
					if rid == "compost":
						continue
					while s.queue_job(mid, rid, 1) == 1:
						pass
			# plant the most valuable in-season crop
			var best := ""
			var best_v := -1.0
			for cid in s.available_crops():
				if s.crop_season_error(cid) != "":
					continue
				var c: Dictionary = db.crops[cid]
				var left: int = s.season_len - s.season_day + 1
				if left < int(c.grow_days):
					continue
				var v: float = (float(c.yield[0]) + float(c.yield[1])) / 2.0 * float(db.items[c.yield_item].base_price) / float(c.grow_days)
				if v > best_v:
					best_v = v
					best = cid
			if best != "":
				for i in s.plots.size():
					if s.plots[i].state != "locked" and s.plots[i].crop == "":
						var seed: String = db.crops[best].seed
						if s.count_item(seed) == 0 and s.money > int(db.items[seed].buy_price):
							s._spend(int(db.items[seed].buy_price))
							s._add_item(seed, 1)
						if s.plant(i, best) != "":
							break
			s.tick(2.0)
		# sell: all finals, and raw goods nothing can use
		for k in s.inventory.keys():
			var id: String = FarmState.key_item(k)
			if not s.sellable(id):
				continue
			var keep: bool = inputs.has(id) and db.items[id].category in ["crop", "ingredient", "animal", "dairy"]
			# keep only what the owned machines can still use
			if keep:
				var usable := false
				for rid in db.recipes:
					if db.recipes[rid].inputs.has(id) and (s.machines[db.recipes[rid].machine].owned > 0):
						usable = true
				keep = usable and d < days - 1
			if not keep:
				s.sell(k, 999)
		s.start_next_day()
	return s.net_worth()
