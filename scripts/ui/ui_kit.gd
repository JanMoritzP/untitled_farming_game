class_name UIKit
extends RefCounted
## Shared look & feel plus small helpers for building UI in code.

const C_PANEL := Color("#fff3d1")
const C_PANEL_DARK := Color("#ffe6a8")
const C_PANEL_DEEP := Color("#f3cf80")
const C_BORDER := Color("#5a3519")
const C_TEXT := Color("#3a2210")
const C_MUTED := Color("#8f6a3f")
const C_GOOD := Color("#27a03a")
const C_BAD := Color("#e23d32")
const C_GOLD := Color("#f2a100")
const C_FINE := Color("#2a73d6")
const C_BTN := Color("#ffa833")
const C_BTN_HOVER := Color("#ffbf5c")
const C_BTN_DOWN := Color("#e58a14")
const C_BTN_OFF := Color("#dccaa0")
const C_GREEN := Color("#4cc94a")
const C_GREEN_HOVER := Color("#6ee06a")
const C_GREEN_DOWN := Color("#34a834")
const C_RED := Color("#f0584a")
const C_RED_HOVER := Color("#ff7a6c")
const C_RED_DOWN := Color("#c9402f")

const FONT_PATH := "res://assets/fonts/pixel.ttf"
const DIGITS_PATH := "res://assets/fonts/digits.ttf"   # clear pixel digits; the main font is the fallback for letters


## Chunky panel/button style: thick outline, optional bevel (thicker bottom edge) and soft drop shadow.
static func box(bg: Color, border: Color = C_BORDER, bw: int = 3, mx: int = 8, my: int = 5,
		bevel: int = 0, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.border_width_bottom = bw + bevel
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	if shadow:
		s.shadow_color = Color(0.1, 0.05, 0.0, 0.35)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 4)
	return s


static func _button_set(t: Theme, type: String, base: Color, hover: Color, down: Color) -> void:
	t.set_stylebox("normal", type, box(base, C_BORDER, 3, 12, 5, 4))
	t.set_stylebox("hover", type, box(hover, C_BORDER, 3, 12, 5, 4))
	var pressed := box(down, C_BORDER, 3, 12, 5, 0)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 4
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, box(C_BTN_OFF, C_MUTED, 3, 12, 5, 4))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, C_TEXT)
	t.set_color("font_hover_color", type, C_TEXT)
	t.set_color("font_pressed_color", type, C_TEXT)
	t.set_color("font_focus_color", type, C_TEXT)
	t.set_color("font_disabled_color", type, C_MUTED)


static func make_theme() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var main_font: Font = load(FONT_PATH)
		t.default_font = main_font
		if ResourceLoader.exists(DIGITS_PATH):
			var digits: FontFile = load(DIGITS_PATH)
			digits.fallbacks = [main_font]
			t.default_font = digits
	t.default_font_size = 19
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_color", "CheckButton", C_TEXT)
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_hover_color", "CheckBox", C_TEXT)
	t.set_color("font_pressed_color", "CheckBox", C_TEXT)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_TEXT)

	t.set_stylebox("panel", "PanelContainer", box(C_PANEL, C_BORDER, 3, 8, 6, 0, true))
	t.set_stylebox("panel", "PopupPanel", box(C_PANEL))
	t.set_stylebox("panel", "PopupMenu", box(C_PANEL))
	t.set_stylebox("hover", "PopupMenu", box(C_BTN_HOVER, C_BTN_HOVER, 1, 6, 2))
	t.set_stylebox("panel", "TooltipPanel", box(C_PANEL, C_BORDER, 2))

	_button_set(t, "Button", C_BTN, C_BTN_HOVER, C_BTN_DOWN)
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	_button_set(t, "PrimaryButton", C_GREEN, C_GREEN_HOVER, C_GREEN_DOWN)
	t.add_type("DangerButton")
	t.set_type_variation("DangerButton", "Button")
	_button_set(t, "DangerButton", C_RED, C_RED_HOVER, C_RED_DOWN)
	t.set_stylebox("normal", "LineEdit", box(Color("#fffaf0"), C_BORDER, 3))
	t.set_stylebox("focus", "LineEdit", box(Color("#fffaf0"), C_GOLD, 3))

	t.set_stylebox("panel", "TabContainer", box(C_PANEL, C_BORDER, 3, 6, 6, 0, true))
	t.set_stylebox("tab_selected", "TabContainer", box(C_PANEL, C_BORDER, 3, 14, 6))
	t.set_stylebox("tab_unselected", "TabContainer", box(C_PANEL_DEEP, C_BORDER, 3, 14, 6))
	t.set_stylebox("tab_hovered", "TabContainer", box(C_PANEL_DARK, C_BORDER, 3, 14, 6))
	t.set_stylebox("tab_disabled", "TabContainer", box(C_PANEL_DEEP, C_BORDER, 3, 14, 6))
	for c in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		t.set_color(c, "TabContainer", C_TEXT)

	t.set_stylebox("background", "ProgressBar", box(C_PANEL_DEEP, C_BORDER, 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(C_GOOD, C_GOOD, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", C_TEXT)
	return t


# ------------------------------------------------------------------ builders

static func lbl(text: String, color: Color = C_TEXT, size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


static func wrap_lbl(text: String, color: Color = C_TEXT, size: int = 0) -> Label:
	var l := lbl(text, color, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func btn(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func btn_primary(text: String, cb: Callable, tip: String = "") -> Button:
	var b := btn(text, cb, tip)
	b.theme_type_variation = "PrimaryButton"
	return b


static func btn_danger(text: String, cb: Callable, tip: String = "") -> Button:
	var b := btn(text, cb, tip)
	b.theme_type_variation = "DangerButton"
	return b


## Big label with a dark outline so it pops off any background.
static func pop_lbl(text: String, color: Color, size: int = 28, outline: int = 6) -> Label:
	var l := lbl(text, color, size)
	l.add_theme_color_override("font_outline_color", C_BORDER)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func hb(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vb(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func icon(tex: Texture2D, px: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func card(bg: Color = C_PANEL_DARK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, C_BORDER, 2, 8, 6, 3))
	return p


static func heading(text: String) -> Label:
	return lbl(text, C_BORDER, 24)


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + "$" + s + out


static func quality_color(q: int) -> Color:
	return [C_TEXT, C_FINE, C_GOLD][clampi(q, 0, 2)]


static func counts_text(db: ContentDB, d: Dictionary) -> String:
	var parts: Array = []
	for k in d:
		parts.append("%s x%d" % [db.item_name(str(k)), int(d[k])])
	return ", ".join(parts)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
