class_name WeatherOverlay
extends Control
## Draws weather tint, falling rain/snow and the dusk glow over the farm.

var tint := Color(0, 0, 0, 0)
var particles := ""
var dusk := 0.0
var _t := 0.0
var _drops: Array = []
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 110:
		_drops.append(Vector2(r.randf(), r.randf()))


func set_weather(def: Dictionary) -> void:
	tint = Color(str(def.get("tint", "#00000000")))
	particles = str(def.get("particles", ""))


func _process(delta: float) -> void:
	_t += delta
	if particles == "storm":
		_flash = maxf(0.0, _flash - delta * 2.5)
		if randf() < delta * 0.25:
			_flash = 0.5
	if particles != "" or dusk > 0.0 or _flash > 0.0:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), tint)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.55, 0.2, dusk * 0.26))
	match particles:
		"rain", "storm":
			var speed := 1.6 if particles == "storm" else 1.1
			for d in _drops:
				var y := fposmod(d.y + _t * speed, 1.0)
				var x := fposmod(d.x - y * 0.15, 1.0)
				var px := floorf(x * size.x / 4.0) * 4.0
				var py := floorf(y * size.y / 4.0) * 4.0
				draw_rect(Rect2(px, py, 2, 10), Color(0.7, 0.85, 1.0, 0.75))
		"snow":
			for d in _drops:
				var y := fposmod(d.y + _t * 0.18, 1.0)
				var x := fposmod(d.x + sin(_t + d.y * 9.0) * 0.02, 1.0)
				var px := floorf(x * size.x / 4.0) * 4.0
				var py := floorf(y * size.y / 4.0) * 4.0
				draw_rect(Rect2(px, py, 4, 4), Color(1, 1, 1, 0.9))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.9, _flash * 0.5))
