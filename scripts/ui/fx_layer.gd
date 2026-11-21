class_name FxLayer
extends Control
## Screen-space juice: pixel particle bursts and floating text.

var _parts: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pixel confetti burst at a global position.
func burst(gpos: Vector2, colors: Array, count: int = 14, speed: float = 170.0) -> void:
	var origin := get_global_transform().affine_inverse() * gpos
	for i in count:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * randf_range(speed * 0.4, speed)
		v.y -= speed * 0.5
		_parts.append({"pos": origin, "vel": v, "color": colors[randi() % colors.size()],
				"life": randf_range(0.45, 0.85), "age": 0.0, "size": [4.0, 6.0, 8.0][randi() % 3]})


func float_text(gpos: Vector2, text: String, color: Color, size: int = 26) -> void:
	var l := UIKit.pop_lbl(text, color, size, 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 10
	add_child(l)
	l.position = get_global_transform().affine_inverse() * gpos - Vector2(l.size.x / 2.0, 10.0)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 56.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	var keep: Array = []
	for p in _parts:
		p["age"] += delta
		if p["age"] < p["life"]:
			p["vel"].y += 520.0 * delta
			p["pos"] += p["vel"] * delta
			keep.append(p)
	_parts = keep
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		var c: Color = p["color"]
		c.a = clampf(a * 1.6, 0.0, 1.0)
		var s: float = p["size"]
		var pos: Vector2 = (p["pos"] / 4.0).floor() * 4.0
		draw_rect(Rect2(pos - Vector2(s, s) / 2.0 - Vector2.ONE, Vector2(s + 2, s + 2)), Color(0.2, 0.1, 0.03, c.a))
		draw_rect(Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s)), c)
