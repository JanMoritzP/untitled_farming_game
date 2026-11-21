class_name PlotView
extends Control
## One clickable farm plot. Draws soil, crop growth, locked/leased state.

signal pressed(idx: int)
signal drag_over(idx: int)

const SIZE := 96

var idx: int = 0
var st: FarmState
var db: ContentDB
var hovering := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(func():
		hovering = false
		queue_redraw())


func _on_enter() -> void:
	hovering = true
	queue_redraw()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		drag_over.emit(idx)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(idx)


func refresh() -> void:
	var p: Dictionary = st.plots[idx]
	tooltip_text = _tooltip(p)
	queue_redraw()


func _tooltip(p: Dictionary) -> String:
	if p["state"] == "locked":
		var pr := st.plot_prices()
		return "Locked plot\nClick to lease ($%d/season) or buy ($%d)" % [pr["lease"], pr["buy"]]
	var lines: Array = []
	lines.append("%s plot" % ("Leased" if p["state"] == "leased" else "Owned"))
	lines.append("Soil fertility: %d%%" % int(round(float(p["fertility"]) * 100.0)))
	if p["crop"] != "":
		var c: Dictionary = db.crops[p["crop"]]
		var name := db.item_name(c["yield_item"])
		if p["ready"]:
			lines.append("%s: ready to harvest!" % name)
		else:
			lines.append("%s: %d%% grown" % [name, int(float(p["progress"]) * 100.0)])
	else:
		lines.append("Empty. Select seeds below, then click or drag.")
	return "\n".join(lines)


func _draw() -> void:
	if st == null:
		return
	var p: Dictionary = st.plots[idx]
	var rect := Rect2(Vector2.ZERO, size)
	var level: int = int(round(float(p["fertility"]) * 4.0))
	draw_texture_rect(PixelArt.soil_texture(level, idx % 4), rect, false)
	if p["state"] == "locked":
		draw_rect(rect, Color(0.12, 0.08, 0.04, 0.62))
		_draw_lock()
		var pr := st.plot_prices()
		_text("$%d" % pr["buy"], Vector2(0, size.y - 12), Color("#ffe9a8"))
	else:
		if p["crop"] != "":
			var stage: int = 3 if p["ready"] else mini(2, int(float(p["progress"]) * 3.0))
			draw_texture_rect(PixelArt.crop_texture(db, p["crop"], stage), rect, false)
			if not p["ready"]:
				var bar := Rect2(10, size.y - 14, size.x - 20, 6)
				draw_rect(bar.grow(2), Color("#3b2a1a"))
				draw_rect(bar, Color("#8a7355"))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(p["progress"]), bar.size.y)), Color("#7fd04a"))
			else:
				var bob: float = sin(Time.get_ticks_msec() / 220.0) * 3.0
				draw_rect(Rect2(size.x - 24, 6 + bob, 16, 16), Color("#3b2a1a"))
				draw_rect(Rect2(size.x - 22, 8 + bob, 12, 12), Color("#ffd84a"))
				draw_rect(Rect2(size.x - 17, 10 + bob, 2, 5), Color("#3b2a1a"))
				draw_rect(Rect2(size.x - 17, 17 + bob, 2, 2), Color("#3b2a1a"))
		if p["state"] == "leased":
			draw_rect(Rect2(4, 4, 10, 10), Color("#3b2a1a"))
			draw_rect(Rect2(6, 6, 6, 6), Color("#6ab0e8"))
	var border := Color("#3b2a1a")
	var bw := 3.0
	if hovering:
		border = Color("#fff2b0")
		bw = 4.0
	draw_rect(rect, border, false, bw)


func _draw_lock() -> void:
	var c := Vector2(size.x / 2.0, size.y / 2.0 - 8)
	draw_rect(Rect2(c.x - 12, c.y - 2, 24, 18), Color("#3b2a1a"))
	draw_rect(Rect2(c.x - 10, c.y, 20, 14), Color("#e0b040"))
	draw_rect(Rect2(c.x - 8, c.y - 14, 4, 14), Color("#3b2a1a"))
	draw_rect(Rect2(c.x + 4, c.y - 14, 4, 14), Color("#3b2a1a"))
	draw_rect(Rect2(c.x - 8, c.y - 16, 16, 4), Color("#3b2a1a"))
	draw_rect(Rect2(c.x - 2, c.y + 4, 4, 5), Color("#3b2a1a"))


func _text(s: String, pos: Vector2, color: Color) -> void:
	var f := get_theme_default_font()
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, color)
