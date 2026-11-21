class_name OrdersPanel
extends PanelBase


func _build() -> void:
	if st.fxb("no_orders"):
		content.add_child(UIKit.wrap_lbl("No contracts in this run (Free Market).", UIKit.C_MUTED))
		return
	content.add_child(UIKit.wrap_lbl("Contracts pay well above market price. New ones appear each morning.", UIKit.C_MUTED))
	if st.orders.is_empty():
		content.add_child(UIKit.lbl("No open contracts right now.", UIKit.C_MUTED))
	for i in st.orders.size():
		var o: Dictionary = st.orders[i]
		var card := UIKit.card()
		var v := UIKit.vb(4)
		card.add_child(v)
		var top := UIKit.hb(8)
		top.add_child(UIKit.icon(PixelArt.item_texture(db, o["item"], 2), 36))
		var names := UIKit.vb(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UIKit.lbl("%d x %s" % [o["qty"], db.item_name(o["item"])], UIKit.C_TEXT, 20))
		var req := "Any quality" if int(o["min_q"]) == 0 else "%s quality or better" % FarmState.QUALITY_NAMES[int(o["min_q"])]
		names.add_child(UIKit.lbl(req, UIKit.quality_color(int(o["min_q"])) if int(o["min_q"]) > 0 else UIKit.C_MUTED, 15))
		top.add_child(names)
		top.add_child(UIKit.lbl(UIKit.money(int(o["reward"])), UIKit.C_GOLD, 22))
		v.add_child(top)
		var left: int = int(o["deadline"]) - st.day
		var row := UIKit.hb(6)
		row.add_child(UIKit.lbl("Due today!" if left <= 0 else "%d day%s left" % [left, "" if left == 1 else "s"],
				UIKit.C_BAD if left <= 1 else UIKit.C_MUTED, 15))
		row.add_child(UIKit.lbl("have %d" % st.count_item(o["item"], int(o["min_q"])), UIKit.C_MUTED, 15))
		row.add_child(UIKit.expander())
		var b := UIKit.btn("Deliver", _deliver.bind(i))
		var err := st.order_error(i)
		b.disabled = err != ""
		if err != "":
			b.tooltip_text = err
		row.add_child(b)
		v.add_child(row)
		content.add_child(card)


func _deliver(i: int) -> void:
	var err := st.fulfill_order(i)
	if err != "":
		toast(err)
