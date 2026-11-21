class_name MarketPanel
extends PanelBase


func _build() -> void:
	content.add_child(UIKit.wrap_lbl("Prices fall as you sell and recover overnight. Better quality and processed goods pay more.", UIKit.C_MUTED))
	var any := false
	for k in st.inventory_keys_sorted():
		var id := FarmState.key_item(k)
		var q := FarmState.key_quality(k)
		var n: int = int(st.inventory[k])
		var card := UIKit.card()
		var v := UIKit.vb(4)
		card.add_child(v)
		var top := UIKit.hb(6)
		top.add_child(item_row(id, q))
		top.add_child(UIKit.expander())
		top.add_child(UIKit.lbl("x%d" % n, UIKit.C_TEXT, 20))
		v.add_child(top)
		if st.sellable(id):
			var dem: float = st.demand.get(id, 1.0)
			var unit := st.unit_price(id, q, dem)
			var row := UIKit.hb(6)
			var pct := int(round(dem * 100.0))
			var trend_color := UIKit.C_GOOD if dem >= 1.05 else (UIKit.C_BAD if dem <= 0.9 else UIKit.C_MUTED)
			row.add_child(UIKit.lbl("$%.1f each" % unit, UIKit.C_GOLD))
			row.add_child(UIKit.lbl("demand %d%%" % pct, trend_color, 15))
			row.add_child(UIKit.expander())
			row.add_child(UIKit.btn_primary("Sell 1", _sell.bind(k, 1)))
			if n > 1:
				row.add_child(UIKit.btn_primary("Sell all (%s)" % UIKit.money(st.sell_value(k, n)), _sell.bind(k, n)))
			v.add_child(row)
		else:
			v.add_child(UIKit.lbl("Not for sale" if db.items[id].get("category", "") == "seed" else "Used on the farm", UIKit.C_MUTED, 15))
		content.add_child(card)
		any = true
	if not any:
		content.add_child(UIKit.lbl("Your barn is empty. Plant something!", UIKit.C_MUTED))


func _sell(k: String, n: int) -> void:
	var got := st.sell(k, n)
	if got > 0 and screen != null and screen.has_method("fx_money"):
		screen.fx_money(got)
