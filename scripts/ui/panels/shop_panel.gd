class_name ShopPanel
extends PanelBase


func _build() -> void:
	content.add_child(UIKit.heading("Seeds"))
	content.add_child(UIKit.wrap_lbl("Buy seeds here, select them on the toolbar below the farm, then click or drag across empty plots.", UIKit.C_MUTED))
	for cid in st.available_crops():
		var c: Dictionary = db.crops[cid]
		var seed: String = c["seed"]
		var price: int = int(db.items[seed].get("buy_price", 5))
		var in_season: bool = c["seasons"].has(st.season_id)
		var card := UIKit.card()
		var v := UIKit.vb(4)
		card.add_child(v)
		var top := UIKit.hb(8)
		top.add_child(UIKit.icon(PixelArt.item_texture(db, seed, 2), 32))
		var names := UIKit.vb(0)
		names.add_child(UIKit.lbl(db.item_name(seed)))
		var seasons_text: Array = []
		for s in c["seasons"]:
			seasons_text.append(str(db.seasons[s]["name"]))
		names.add_child(UIKit.lbl("%s  -  %ds" % [", ".join(seasons_text), int(round(float(c["grow_days"]) * st.day_length))],
				UIKit.C_GOOD if in_season else UIKit.C_BAD, 15))
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(names)
		top.add_child(UIKit.lbl("have %d" % st.count_item(seed), UIKit.C_MUTED))
		v.add_child(top)
		var buy_row := UIKit.hb(6)
		buy_row.add_child(UIKit.lbl("$%d each" % price, UIKit.C_GOLD))
		buy_row.add_child(UIKit.expander())
		for n in [1, 5, 10]:
			var b := UIKit.btn_primary("Buy %d" % n, _buy.bind(seed, price, n))
			b.disabled = st.money < price * n
			buy_row.add_child(b)
		v.add_child(buy_row)
		content.add_child(card)
	content.add_child(UIKit.heading("Land"))
	content.add_child(UIKit.wrap_lbl("Click a locked plot on the farm to lease it for a season or buy it for good. Leases renew automatically at the start of each season.", UIKit.C_MUTED))
	var cb := CheckButton.new()
	cb.text = "Auto-renew leases"
	cb.button_pressed = st.auto_renew
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on): st.auto_renew = on)
	content.add_child(cb)
	var leased := 0
	var fees := 0
	for p in st.plots:
		if p["state"] == "leased":
			leased += 1
			fees += int(p["fee"])
	content.add_child(UIKit.lbl("Leased plots: %d  (renewal cost %s per season)" % [leased, UIKit.money(fees)], UIKit.C_TEXT))


func _buy(seed: String, price: int, n: int) -> void:
	if st.money < price * n:
		toast("Not enough money")
		return
	st._spend(price * n)
	st._add_item(seed, n, 0)
	st.changed.emit()
