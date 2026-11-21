class_name UIKit
extends RefCounted
## Shared look & feel plus small helpers for building UI in code.

const C_PANEL := Color("#f3e2b8")
const C_PANEL_DARK := Color("#e2cb94")
const C_PANEL_DEEP := Color("#c9ad72")
const C_BORDER := Color("#6b4a2b")
const C_TEXT := Color("#3b2a1a")
const C_MUTED := Color("#8a7355")
const C_GOOD := Color("#3f7f2c")
const C_BAD := Color("#b8453f")
const C_GOLD := Color("#b87f0c")
const C_FINE := Color("#2f6fae")
const C_BTN := Color("#ebb85e")
const C_BTN_HOVER := Color("#f5cb7a")
const C_BTN_DOWN := Color("#c98f3a")
const C_BTN_OFF := Color("#d3c4a0")

const FONT_PATH := "res://assets/fonts/pixel.ttf"


static func box(bg: Color, border: Color = C_BORDER, bw: int = 3, mx: int = 8, my: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = false
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		t.default_font = load(FONT_PATH)
	t.default_font_size = 17
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", C_MUTED)
	t.set_color("font_color", "CheckButton", C_TEXT)
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_TEXT)

	t.set_stylebox("panel", "PanelContainer", box(C_PANEL))
	t.set_stylebox("panel", "PopupPanel", box(C_PANEL))
	t.set_stylebox("panel", "PopupMenu", box(C_PANEL))
	t.set_stylebox("hover", "PopupMenu", box(C_BTN_HOVER, C_BTN_HOVER, 1, 6, 2))
	t.set_stylebox("panel", "TooltipPanel", box(C_PANEL, C_BORDER, 2))

	t.set_stylebox("normal", "Button", box(C_BTN, C_BORDER, 3, 10, 4))
	t.set_stylebox("hover", "Button", box(C_BTN_HOVER, C_BORDER, 3, 10, 4))
	t.set_stylebox("pressed", "Button", box(C_BTN_DOWN, C_BORDER, 3, 10, 4))
	t.set_stylebox("disabled", "Button", box(C_BTN_OFF, C_MUTED, 3, 10, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", box(Color("#fff6dc"), C_BORDER, 3))
	t.set_stylebox("focus", "LineEdit", box(Color("#fff6dc"), C_GOLD, 3))

	t.set_stylebox("panel", "TabContainer", box(C_PANEL, C_BORDER, 3, 6, 6))
	t.set_stylebox("tab_selected", "TabContainer", box(C_PANEL, C_BORDER, 3, 12, 5))
	t.set_stylebox("tab_unselected", "TabContainer", box(C_PANEL_DEEP, C_BORDER, 3, 12, 5))
	t.set_stylebox("tab_hovered", "TabContainer", box(C_PANEL_DARK, C_BORDER, 3, 12, 5))
	t.set_stylebox("tab_disabled", "TabContainer", box(C_PANEL_DEEP, C_BORDER, 3, 12, 5))
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
	p.add_theme_stylebox_override("panel", box(bg, C_BORDER, 2, 8, 6))
	return p


static func heading(text: String) -> Label:
	var l := lbl(text, C_BORDER, 22)
	return l


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
