class_name PanelBase
extends ScrollContainer
## Base for the side-panel tabs. Subclasses override _build(); refresh() rebuilds.

var db: ContentDB
var st: FarmState
var journal: Journal
var screen: Node   # GameScreen (for toasts); may be null in the menu
var content: VBoxContainer


func setup(p_db: ContentDB, p_st: FarmState, p_journal: Journal, p_screen: Node = null) -> void:
	db = p_db
	st = p_st
	journal = p_journal
	screen = p_screen
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = UIKit.vb(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	refresh()


func refresh() -> void:
	var keep := scroll_vertical
	UIKit.clear(content)
	_build()
	if keep > 0:
		await get_tree().process_frame
		scroll_vertical = keep


func tick() -> void:
	pass


func _build() -> void:
	pass


func toast(text: String, kind: String = "bad") -> void:
	if screen != null and screen.has_method("toast"):
		screen.toast(text, kind)


func item_row(item_id: String, q: int = -1) -> HBoxContainer:
	var row := UIKit.hb(6)
	row.add_child(UIKit.icon(PixelArt.item_texture(db, item_id, 2), 32))
	var name_color := UIKit.C_TEXT if q < 0 else UIKit.quality_color(q)
	var name := db.item_name(item_id)
	if q > 0:
		name += " (%s)" % FarmState.QUALITY_NAMES[q]
	row.add_child(UIKit.lbl(name, name_color))
	return row


func ingredient_strip(d: Dictionary) -> HBoxContainer:
	var row := UIKit.hb(4)
	var first := true
	for k in d:
		if not first:
			row.add_child(UIKit.lbl("+", UIKit.C_MUTED))
		first = false
		row.add_child(UIKit.lbl(str(int(d[k])), UIKit.C_TEXT))
		var ic := UIKit.icon(PixelArt.item_texture(db, str(k), 2), 28)
		ic.tooltip_text = db.item_name(str(k))
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(ic)
	return row
