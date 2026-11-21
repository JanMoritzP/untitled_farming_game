class_name PixelArt
extends RefCounted
## Procedural placeholder pixel art. Every sprite is generated from the data files
## (colour + shape), so new content always has an icon. Drop a PNG at
## res://assets/items/<id>.png (or res://assets/machines/<id>.png) to override.

const OUTLINE := Color("#4a3322")
const GREEN := Color("#5fae48")
const LEAF := Color("#6dbf4b")
const STEM := Color("#4f8f3a")
const BROWN := Color("#8a5a2b")
const CREAM := Color("#f4e8c8")

static var _cache: Dictionary = {}


# ------------------------------------------------------------------ public

static func item_texture(db: ContentDB, id: String, scale: int = 2) -> Texture2D:
	var ck := "i:%s:%d" % [id, scale]
	if _cache.has(ck):
		return _cache[ck]
	var img: Image = _load_override("res://assets/items/%s.png" % id)
	if img == null:
		var def: Dictionary = db.items.get(id, {})
		img = make_shape(str(def.get("shape", "round")), Color(str(def.get("color", "#cccccc"))))
	return _store(ck, img, scale)


static func machine_texture(db: ContentDB, id: String, scale: int = 2) -> Texture2D:
	var ck := "m:%s:%d" % [id, scale]
	if _cache.has(ck):
		return _cache[ck]
	var img: Image = _load_override("res://assets/machines/%s.png" % id)
	if img == null:
		img = make_shape("building", Color(str(db.machines.get(id, {}).get("color", "#b9a27a"))))
	return _store(ck, img, scale)


static func star_texture(filled: bool, scale: int = 3) -> Texture2D:
	var ck := "star:%s:%d" % [filled, scale]
	if _cache.has(ck):
		return _cache[ck]
	var rows := [
		"....#....", "....#....", "...###...", "#########", ".#######.",
		"..#####..", "..##.##..", ".##...##.", ".#.....#."]
	var img := _blank(11, 11)
	var col := Color("#f2c53a") if filled else Color("#b9a98a")
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				img.set_pixel(x + 1, y + 1, col)
	_finish(img)
	return _store(ck, img, scale)


static func soil_texture(level: int, variant: int) -> Texture2D:
	level = clampi(level, 0, 4)
	var ck := "soil:%d:%d" % [level, variant]
	if _cache.has(ck):
		return _cache[ck]
	var base := Color("#b08a5b").lerp(Color("#5e3d22"), float(level) / 4.0)
	var img := _blank(24, 24)
	for y in 24:
		for x in 24:
			var h: int = ((x * 73856093) ^ (y * 19349663) ^ ((variant + 1) * 83492791)) & 255
			var c := base
			if h < 28:
				c = base.darkened(0.18)
			elif h > 228:
				c = base.lightened(0.14)
			if y % 6 == 5:
				c = c.darkened(0.12)
			if x == 0 or y == 0 or x == 23 or y == 23:
				c = base.darkened(0.35)
			img.set_pixel(x, y, c)
	return _store(ck, img, 4)


static func grass_tile() -> Texture2D:
	if _cache.has("grass"):
		return _cache["grass"]
	var base := Color("#78b35d")
	var img := _blank(16, 16)
	for y in 16:
		for x in 16:
			var h: int = ((x * 2654435761) ^ (y * 40503) ^ 7919) & 255
			var c := base
			if h < 30:
				c = base.darkened(0.1)
			elif h > 235:
				c = base.lightened(0.12)
			img.set_pixel(x, y, c)
	return _store("grass", img, 4)


static func crop_texture(db: ContentDB, cid: String, stage: int) -> Texture2D:
	stage = clampi(stage, 0, 3)
	var ck := "crop:%s:%d" % [cid, stage]
	if _cache.has(ck):
		return _cache[ck]
	var c: Dictionary = db.crops[cid]
	var col := Color(str(db.items[c["yield_item"]].get("color", "#ffffff")))
	var img := _blank(24, 24)
	match str(c.get("look", "bush")):
		"tall":
			var h: int = [3, 7, 11, 15][stage]
			for x in [6, 11, 16]:
				_rect(img, x, 22 - h, 2, h, STEM)
				if stage >= 1:
					_rect(img, x - 2, 22 - h / 2, 2, 1, LEAF)
					_rect(img, x + 2, 22 - h / 2 - 2, 2, 1, LEAF)
				if stage >= 2:
					_rect(img, x - 1, 22 - h - 3, 4, 5, col if stage == 3 else LEAF)
		"ground":
			var rx: float = [2.0, 4.0, 6.0, 7.0][stage]
			var ry: float = [1.5, 3.0, 4.0, 4.5][stage]
			_ell(img, 12, 18, rx, ry, LEAF)
			if stage >= 2:
				_ell(img, 12, 17, rx * 0.6, ry * 0.5, STEM)
			if stage == 3:
				_ell(img, 12, 15, 5.5, 5.0, col)
				_rect(img, 11, 8, 2, 3, STEM)
		_:
			var r: float = [2.0, 4.0, 6.0, 7.0][stage]
			_ell(img, 12, 17, r, r * 0.8, LEAF)
			if stage >= 2:
				_ell(img, 10, 16, r * 0.4, r * 0.3, STEM)
				_ell(img, 15, 18, r * 0.4, r * 0.3, STEM)
			if stage == 3:
				for p in [Vector2(8, 15), Vector2(15, 14), Vector2(11, 19), Vector2(17, 19), Vector2(12, 12)]:
					_ell(img, int(p.x), int(p.y), 1.9, 1.9, col)
	_finish(img)
	return _store(ck, img, 4)


# ------------------------------------------------------------------ item shapes

static func make_shape(shape: String, col: Color) -> Image:
	var img := _blank(16, 16)
	var dark := col.darkened(0.3)
	var light := col.lightened(0.35)
	match shape:
		"round":
			_ell(img, 8, 9, 5.5, 5.0, col)
			_rect(img, 7, 2, 2, 3, GREEN)
			_px(img, 9, 3, GREEN)
			_px(img, 10, 3, GREEN)
			_px(img, 5, 8, dark)
			_px(img, 10, 11, dark)
		"grain":
			_rect(img, 8, 5, 1, 10, Color("#b8a050"))
			_ell(img, 8, 5, 2.0, 4.0, col)
			for p in [Vector2(6, 7), Vector2(9, 7), Vector2(6, 10), Vector2(9, 10)]:
				_rect(img, int(p.x), int(p.y), 2, 2, col)
		"cob":
			_ell(img, 8, 7, 3.0, 6.0, col)
			_rect(img, 5, 9, 2, 5, GREEN)
			_rect(img, 10, 9, 2, 5, GREEN)
			_rect(img, 7, 12, 2, 3, GREEN)
			for p in [Vector2(7, 4), Vector2(9, 5), Vector2(7, 7), Vector2(9, 8)]:
				_px(img, int(p.x), int(p.y), light)
		"berry":
			_ell(img, 8, 8, 5.0, 4.5, col)
			_rect(img, 6, 11, 5, 2, col)
			_rect(img, 7, 13, 3, 1, col)
			_rect(img, 5, 3, 6, 2, GREEN)
			_rect(img, 7, 2, 2, 2, GREEN)
			for p in [Vector2(6, 8), Vector2(9, 7), Vector2(8, 10), Vector2(10, 9)]:
				_px(img, int(p.x), int(p.y), Color("#f6e27a"))
		"pumpkin":
			_ell(img, 8, 9, 6.5, 5.0, col)
			for x in [5, 8, 11]:
				for y in range(5, 14):
					if img.get_pixel(x, y).a > 0.5:
						img.set_pixel(x, y, col.darkened(0.15))
			_rect(img, 7, 2, 2, 3, STEM)
		"leaf":
			_ell(img, 8, 9, 6.0, 5.5, col)
			_line(img, 8, 4, 8, 13, light)
			_line(img, 5, 7, 7, 9, light)
			_line(img, 11, 7, 9, 9, light)
		"bundle":
			for i in 4:
				_line(img, 4 + i * 2, 14, 3 + i * 3, 2, col if i % 2 == 0 else col.darkened(0.15))
				_line(img, 5 + i * 2, 14, 4 + i * 3, 2, col if i % 2 == 0 else col.darkened(0.15))
			_rect(img, 3, 8, 10, 2, BROWN)
		"pile":
			_ell(img, 8, 11, 6.0, 3.5, col)
			_ell(img, 8, 9, 4.0, 2.5, col.lightened(0.12))
			_px(img, 5, 10, light)
			_px(img, 10, 11, light)
		"egg":
			_ell(img, 8, 9, 4.3, 5.5, col)
		"bottle":
			_rect(img, 6, 1, 4, 2, BROWN)
			_rect(img, 6, 3, 4, 3, col)
			_rect(img, 4, 7, 8, 7, col)
			_rect(img, 5, 6, 6, 1, col)
			_rect(img, 5, 9, 6, 3, Color("#7aaed8"))
		"block":
			_rect(img, 2, 7, 12, 7, col)
			_rect(img, 3, 4, 11, 3, col.lightened(0.2))
			for p in [Vector2(5, 10), Vector2(10, 11), Vector2(8, 9)]:
				_px(img, int(p.x), int(p.y), dark)
		"sack":
			_ell(img, 8, 10, 5.5, 5.0, col)
			_rect(img, 6, 3, 4, 4, col)
			_rect(img, 5, 2, 6, 2, col)
			_rect(img, 6, 6, 4, 1, BROWN)
		"loaf":
			_ell(img, 8, 9, 7.0, 4.5, col)
			_line(img, 4, 7, 5, 9, light)
			_line(img, 7, 6, 8, 8, light)
			_line(img, 10, 6, 11, 8, light)
		"jar":
			_rect(img, 4, 5, 8, 9, col)
			_rect(img, 4, 2, 8, 3, Color("#b5834a"))
			_rect(img, 5, 8, 6, 4, CREAM)
			_px(img, 5, 6, light)
		"pie":
			_ell(img, 8, 10, 7.0, 4.0, Color("#d9b06a"))
			_ell(img, 8, 9, 5.0, 2.5, col)
			_line(img, 4, 8, 10, 11, Color("#d9b06a"))
			_line(img, 6, 7, 12, 10, Color("#d9b06a"))
		"cake":
			_rect(img, 3, 8, 10, 6, col.darkened(0.1))
			_ell(img, 8, 8, 5.0, 2.0, col.lightened(0.25))
			_rect(img, 3, 10, 10, 2, CREAM)
			_ell(img, 8, 5, 1.6, 1.6, Color("#d9363e"))
		"fries":
			_rect(img, 4, 3, 2, 7, col)
			_rect(img, 7, 2, 2, 8, col)
			_rect(img, 10, 4, 2, 6, col)
			_rect(img, 3, 9, 10, 6, Color("#c8453b"))
		"bowl":
			for y in range(8, 15):
				for x in 16:
					var dx := (float(x) - 8.0) / 7.0
					var dy := (float(y) - 8.0) / 6.5
					if dx * dx + dy * dy <= 1.0:
						img.set_pixel(x, y, BROWN)
			_ell(img, 8, 8, 6.0, 2.0, col)
			for p in [Vector2(6, 4), Vector2(7, 3), Vector2(9, 5), Vector2(10, 4)]:
				_px(img, int(p.x), int(p.y), CREAM)
		"packet":
			_rect(img, 3, 2, 10, 13, CREAM)
			_rect(img, 3, 2, 10, 2, col)
			_ell(img, 8, 9, 3.0, 3.0, col)
			_px(img, 8, 6, GREEN)
		"building":
			_rect(img, 2, 8, 12, 7, col)
			_rect(img, 1, 6, 14, 3, col.darkened(0.35))
			_rect(img, 3, 4, 10, 2, col.darkened(0.35))
			_rect(img, 5, 2, 6, 2, col.darkened(0.35))
			_rect(img, 6, 10, 4, 5, BROWN)
			_rect(img, 3, 10, 2, 2, Color("#bfe3f2"))
			_rect(img, 11, 10, 2, 2, Color("#bfe3f2"))
		_:
			_ell(img, 8, 8, 5.0, 5.0, col)
	_finish(img)
	return img


# ------------------------------------------------------------------ drawing helpers

static func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var steps: int = maxi(absi(x1 - x0), absi(y1 - y0))
	if steps == 0:
		_px(img, x0, y0, c)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_px(img, int(round(lerpf(x0, x1, t))), int(round(lerpf(y0, y1, t))), c)


static func _opaque(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.5


## Cheap pixel-art shading (light from the top-left) followed by a 1px outline.
static func _finish(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if not _opaque(src, x, y):
				continue
			var c := src.get_pixel(x, y)
			if not _opaque(src, x, y - 1) or not _opaque(src, x - 1, y):
				c = c.lightened(0.2)
			elif not _opaque(src, x, y + 1) or not _opaque(src, x + 1, y):
				c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	var shaded: Image = img.duplicate()
	for y in h:
		for x in w:
			if _opaque(shaded, x, y):
				continue
			if _opaque(shaded, x - 1, y) or _opaque(shaded, x + 1, y) \
					or _opaque(shaded, x, y - 1) or _opaque(shaded, x, y + 1):
				img.set_pixel(x, y, OUTLINE)


static func _load_override(path: String) -> Image:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t.get_image()
	return null


static func _store(key: String, img: Image, scale: int) -> Texture2D:
	if scale != 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
