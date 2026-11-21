class_name PlotView
extends Control
## One clickable farm plot. Draws soil, swaying crops, ripe glow and sparkles,
## a ghost preview of the selected tool, and a "for sale" sign when locked.

signal pressed(idx: int)
signal drag_over(idx: int)

const SIZE := 96

var idx: int = 0
var st: FarmState
var db: ContentDB
var ghost_provider: Callable   # returns a crop id, "compost" or "" for the active tool
var hovering := false
var _pop := 0.0


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


## Squash-and-stretch bounce, used when planting or harvesting.
func pop() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	if st == null:
		return
	_pop = maxf(0.0, _pop - delta * 3.5)
	var p: Dictionary = st.plots[idx]
	if p["crop"] != "" or hovering or _pop > 0.0:
		queue_redraw()


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
	var t := Time.get_ticks_msec() / 1000.0
	if p["state"] == "locked":
		_draw_locked(rect)
		if hovering:
			draw_rect(rect, Color(1, 1, 1, 0.18))
		draw_rect(rect, Color("#3a7a2a"), false, 3.0)
		return

	var level: int = int(round(float(p["fertility"]) * 4.0))
	draw_texture_rect(PixelArt.soil_texture(level, idx % 4), rect, false)

	if p["crop"] != "":
		var ready: bool = p["ready"]
		var stage: int = 3 if ready else mini(2, int(float(p["progress"]) * 3.0))
		if ready:
			var glow := 0.14 + 0.10 * sin(t * 5.0 + idx)
			draw_rect(rect.grow(-5), Color(1.0, 0.92, 0.35, glow))
		# sway in whole pixels so it stays pixel-art, bounce when ripe, squash when popped
		var sway: float = round(sin(t * 2.0 + float(idx) * 0.7) * 1.5 / 2.0) * 2.0
		var bounce: float = floorf(absf(sin(t * 4.0 + float(idx))) * 3.0) * 2.0 if ready else 0.0
		var sq: float = sin(_pop * PI) * 0.28
		var pivot := Vector2(size.x / 2.0 + sway, size.y - 8.0 - bounce)
		draw_set_transform(pivot, 0.0, Vector2(1.0 + sq, 1.0 - sq * 0.7))
		draw_texture_rect(PixelArt.crop_texture(db, p["crop"], stage),
				Rect2(-size.x / 2.0, -(size.y - 8.0), size.x, size.y), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if ready:
			_draw_sparkles(t)
		else:
			var bar := Rect2(10, size.y - 14, size.x - 20, 7)
			draw_rect(bar.grow(2), Color("#3a2210"))
			draw_rect(bar, Color("#8f6a3f"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(p["progress"]), bar.size.y)), Color("#8cf04a"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(p["progress"]), 2)), Color("#d6ff8a"))
	elif hovering and ghost_provider.is_valid():
		var tool: String = ghost_provider.call()
		if tool == "compost":
			draw_rect(rect, Color(0.55, 0.35, 0.15, 0.35))
		elif tool != "" and db.crops.has(tool) and st.plant_error(idx, tool) == "":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(PixelArt.crop_texture(db, tool, 1), rect, false, Color(1, 1, 1, 0.55))

	if p["state"] == "leased":
		draw_rect(Rect2(4, 4, 12, 12), Color("#3a2210"))
		draw_rect(Rect2(6, 6, 8, 8), Color("#4aa8ff"))
	if hovering:
		draw_rect(rect, Color(1, 1, 1, 0.16))
	draw_rect(rect, Color("#fff2a0") if hovering else Color("#4a2a12"), false, 4.0 if hovering else 3.0)


func _draw_sparkles(t: float) -> void:
	var tex := PixelArt.sparkle_texture()
	for i in 3:
		var phase := fposmod(t * 0.9 + float(i) * 0.33 + float(idx) * 0.1, 1.0)
		var pos := Vector2(size.x * (0.2 + 0.28 * float(i)), size.y * (0.62 - 0.45 * phase))
		draw_texture(tex, pos, Color(1, 1, 1, 1.0 - phase))


func _draw_locked(rect: Rect2) -> void:
	draw_texture_rect(PixelArt.grass_tile(), rect, true)
	draw_rect(rect, Color(0.2, 0.45, 0.15, 0.18))
	var c := Vector2(size.x / 2.0, size.y / 2.0)
	# wooden "for sale" sign
	draw_rect(Rect2(c.x - 4, c.y + 6, 8, 34), Color("#3a2210"))
	draw_rect(Rect2(c.x - 2, c.y + 6, 4, 34), Color("#9a6430"))
	var board := Rect2(c.x - 30, c.y - 28, 60, 36)
	draw_rect(board.grow(3), Color("#3a2210"))
	draw_rect(board, Color("#e8b060"))
	draw_rect(Rect2(board.position, Vector2(board.size.x, 4)), Color("#f6cf8a"))
	draw_rect(Rect2(board.position.x, board.end.y - 4, board.size.x, 4), Color("#c88a40"))
	var f := get_theme_default_font()
	draw_string(f, Vector2(board.position.x, board.position.y + 14), "FOR SALE", HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 12, Color("#3a2210"))
	draw_string(f, Vector2(board.position.x, board.position.y + 31), "$%d" % st.plot_prices()["buy"], HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 20, Color("#7a1f12"))
