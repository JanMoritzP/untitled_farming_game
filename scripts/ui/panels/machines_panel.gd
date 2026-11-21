class_name MachinesPanel
extends PanelBase

var _bars: Array = []   # [ProgressBar, machine id, queue index]


func _build() -> void:
	_bars.clear()
	content.add_child(UIKit.wrap_lbl("Rent a machine per batch, or buy it and run it for free. Buying another copy adds a parallel slot.", UIKit.C_MUTED))
	for mid in db.machines:
		if not st.machine_available(mid):
			continue
		content.add_child(_machine_card(mid))


func _machine_card(mid: String) -> Control:
	var def: Dictionary = db.machines[mid]
	var m: Dictionary = st.machines[mid]
	var owned: int = int(m["owned"])
	var card := UIKit.card()
	var v := UIKit.vb(6)
	card.add_child(v)

	var top := UIKit.hb(8)
	top.add_child(UIKit.icon(PixelArt.machine_texture(db, mid, 2), 40))
	var names := UIKit.vb(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UIKit.lbl(str(def["name"]), UIKit.C_BORDER, 20))
	var status := "Rented: %s per batch" % UIKit.money(st.machine_rent(mid)) if owned == 0 else "Owned x%d - runs for free" % owned
	names.add_child(UIKit.lbl(status, UIKit.C_GOOD if owned > 0 else UIKit.C_MUTED, 15))
	top.add_child(names)
	var buy_label := "Buy %s" % UIKit.money(int(def["buy_cost"])) if owned == 0 else "+1 slot %s" % UIKit.money(int(def["buy_cost"]))
	var buy := UIKit.btn(buy_label, _buy.bind(mid), str(def.get("desc", "")))
	var why := st.machine_buy_error(mid)
	buy.disabled = why != ""
	if why != "":
		buy.tooltip_text = why
	top.add_child(buy)
	v.add_child(top)

	var q: Array = m["queue"]
	if not q.is_empty():
		var slots := st.machine_slots(mid)
		var row := UIKit.vb(2)
		for i in q.size():
			var job: Dictionary = q[i]
			var r: Dictionary = db.recipes[job["recipe"]]
			var line := UIKit.hb(6)
			var out_id: String = r["outputs"].keys()[0]
			line.add_child(UIKit.icon(PixelArt.item_texture(db, out_id, 2), 24))
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 18)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.max_value = float(r["time"])
			bar.value = float(r["time"]) - float(job["remaining"]) if i < slots else 0.0
			line.add_child(bar)
			if i < slots:
				_bars.append([bar, mid, i])
			else:
				line.add_child(UIKit.lbl("waiting", UIKit.C_MUTED, 14))
			row.add_child(line)
			if i >= 5:
				row.add_child(UIKit.lbl("+ %d more queued" % (q.size() - 6), UIKit.C_MUTED, 14))
				break
		v.add_child(row)

	for rid in st.available_recipes(mid):
		var r: Dictionary = db.recipes[rid]
		var line := UIKit.hb(6)
		line.add_child(ingredient_strip(r["inputs"]))
		line.add_child(UIKit.lbl("->", UIKit.C_MUTED))
		line.add_child(ingredient_strip(r["outputs"]))
		line.add_child(UIKit.expander())
		line.add_child(UIKit.lbl("%ds" % int(r["time"]), UIKit.C_MUTED, 15))
		for n in [1, 5]:
			var b := UIKit.btn("x%d" % n, _queue.bind(mid, rid, n))
			var err := st.queue_error(mid, rid)
			b.disabled = err != ""
			if err != "":
				b.tooltip_text = err
			line.add_child(b)
		v.add_child(line)
	return card


func tick() -> void:
	for b in _bars:
		var q: Array = st.machines[b[1]]["queue"]
		if b[2] < q.size():
			var r: Dictionary = db.recipes[q[b[2]]["recipe"]]
			(b[0] as ProgressBar).value = float(r["time"]) - float(q[b[2]]["remaining"])


func _buy(mid: String) -> void:
	var err := st.buy_machine(mid)
	if err != "":
		toast(err)


func _queue(mid: String, rid: String, n: int) -> void:
	if st.queue_job(mid, rid, n) == 0:
		toast(st.queue_error(mid, rid))
