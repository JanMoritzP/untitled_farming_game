class_name Menu
extends Control
## Title screen, run setup (mode, difficulty, challenge modifiers, seed) and journal.

signal start_run(cfg: Dictionary)
signal continue_run
signal quit_game

var db: ContentDB
var journal: Journal

var _mode_id := "classic"
var _difficulty_id := "normal"
var _scenario_id := ""
var _modifiers: Array = []
var _seed_edit: LineEdit
var _mult_label: Label
var _mod_box: VBoxContainer
var _mode_desc: Label
var _diff_desc: Label
var _scenario_opt: OptionButton
var _scenario_row: Control
var _mode_opt: OptionButton
var _diff_opt: OptionButton
var _root: Control


func setup(p_db: ContentDB, p_journal: Journal) -> void:
	db = p_db
	journal = p_journal
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = PixelArt.grass_tile()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_show_title()


func _swap(content: Control) -> void:
	UIKit.clear(_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	center.add_child(content)


# ------------------------------------------------------------------ title

func _show_title() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.C_PANEL, UIKit.C_BORDER, 4, 40, 30))
	var v := UIKit.vb(12)
	panel.add_child(v)
	var title := UIKit.lbl("Untitled Farming Game", UIKit.C_BORDER, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UIKit.lbl("Grow it. Mill it. Bake it. Sell it.", UIKit.C_MUTED, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var icons := UIKit.hb(10)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in ["wheat", "flour", "bread", "strawberry", "jam", "cake"]:
		icons.add_child(UIKit.icon(PixelArt.item_texture(db, id, 4), 56))
	v.add_child(icons)
	var cont := UIKit.btn("Continue", func(): continue_run.emit())
	cont.disabled = not Game.has_save()
	cont.custom_minimum_size = Vector2(300, 44)
	v.add_child(cont)
	for entry in [["New run", _show_setup], ["Farm journal", _show_journal]]:
		var b := UIKit.btn(entry[0], entry[1])
		b.custom_minimum_size = Vector2(300, 44)
		v.add_child(b)
	var q := UIKit.btn("Quit", func(): quit_game.emit())
	q.custom_minimum_size = Vector2(300, 44)
	v.add_child(q)
	var note := "Content: %d goods, %d recipes, %d challenges" % [db.items.size(), db.recipes.size(), db.modifiers.size()]
	if db.sources.size() > 1:
		note += "  |  mods: " + ", ".join(db.sources.slice(1))
	v.add_child(UIKit.lbl(note, UIKit.C_MUTED, 14))
	_swap(panel)


# ------------------------------------------------------------------ journal

func _show_journal() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 600)
	var v := UIKit.vb(8)
	panel.add_child(v)
	v.add_child(UIKit.lbl("Farm Journal", UIKit.C_BORDER, 32))
	var jp := JournalPanel.new()
	jp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(jp)
	jp.setup(db, null, journal)
	v.add_child(UIKit.btn("Back", _show_title))
	_swap(panel)


# ------------------------------------------------------------------ setup

func _show_setup() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.C_PANEL, UIKit.C_BORDER, 4, 24, 18))
	var outer := UIKit.vb(10)
	panel.add_child(outer)
	outer.add_child(UIKit.lbl("New run", UIKit.C_BORDER, 32))
	var cols := UIKit.hb(24)
	outer.add_child(cols)

	var left := UIKit.vb(8)
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)
	left.add_child(UIKit.heading("Mode"))
	_mode_opt = OptionButton.new()
	_mode_opt.focus_mode = Control.FOCUS_NONE
	var mode_ids: Array = db.modes.keys()
	for i in mode_ids.size():
		_mode_opt.add_item(str(db.modes[mode_ids[i]]["name"]), i)
	_mode_opt.select(maxi(0, mode_ids.find(_mode_id)))
	_mode_opt.item_selected.connect(func(i):
		_mode_id = mode_ids[i]
		_on_mode_changed())
	left.add_child(_mode_opt)
	_mode_desc = UIKit.wrap_lbl("", UIKit.C_MUTED, 15)
	left.add_child(_mode_desc)

	var srow := UIKit.vb(4)
	_scenario_row = srow
	_scenario_opt = OptionButton.new()
	_scenario_opt.focus_mode = Control.FOCUS_NONE
	var sc_ids: Array = db.scenarios.keys()
	for i in sc_ids.size():
		_scenario_opt.add_item(str(db.scenarios[sc_ids[i]]["name"]), i)
	_scenario_opt.item_selected.connect(func(i):
		_scenario_id = sc_ids[i]
		_refresh_descriptions())
	srow.add_child(_scenario_opt)
	left.add_child(srow)
	if not sc_ids.is_empty() and _scenario_id == "":
		_scenario_id = sc_ids[0]

	left.add_child(UIKit.heading("Difficulty"))
	_diff_opt = OptionButton.new()
	_diff_opt.focus_mode = Control.FOCUS_NONE
	var diff_ids: Array = db.difficulties.keys()
	for i in diff_ids.size():
		_diff_opt.add_item(str(db.difficulties[diff_ids[i]]["name"]), i)
	_diff_opt.select(maxi(0, diff_ids.find(_difficulty_id)))
	_diff_opt.item_selected.connect(func(i):
		_difficulty_id = diff_ids[i]
		_refresh_descriptions())
	left.add_child(_diff_opt)
	_diff_desc = UIKit.wrap_lbl("", UIKit.C_MUTED, 15)
	left.add_child(_diff_desc)

	left.add_child(UIKit.heading("Seed (optional)"))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	left.add_child(_seed_edit)
	left.add_child(UIKit.expander())
	_mult_label = UIKit.lbl("", UIKit.C_GOLD, 20)
	left.add_child(_mult_label)

	var right := UIKit.vb(6)
	right.custom_minimum_size = Vector2(430, 0)
	cols.add_child(right)
	right.add_child(UIKit.heading("Challenges"))
	right.add_child(UIKit.wrap_lbl("Pick any restrictions you like. Each one multiplies your final score.", UIKit.C_MUTED, 15))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_mod_box = UIKit.vb(2)
	_mod_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_mod_box)

	var buttons := UIKit.hb(10)
	outer.add_child(buttons)
	buttons.add_child(UIKit.btn("Back", _show_title))
	buttons.add_child(UIKit.expander())
	var go := UIKit.btn("Start farming", _start)
	go.custom_minimum_size = Vector2(220, 44)
	buttons.add_child(go)
	_swap(panel)
	_on_mode_changed()


func _on_mode_changed() -> void:
	var special: String = str(db.modes[_mode_id].get("special", ""))
	_scenario_row.visible = special == "scenario"
	_build_modifier_list(special)
	_refresh_descriptions()


func _build_modifier_list(special: String) -> void:
	UIKit.clear(_mod_box)
	var locked: bool = special == "daily" or special == "scenario"
	if special == "daily":
		_modifiers = Game.daily_config()["modifiers"].duplicate()
	elif special == "scenario":
		_modifiers = []
	for mid in db.modifiers:
		var m: Dictionary = db.modifiers[mid]
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = "%s  (x%.2f)" % [m["name"], float(m.get("score_mult", 1.0))]
		cb.tooltip_text = str(m.get("desc", ""))
		cb.button_pressed = _modifiers.has(mid)
		cb.disabled = locked
		cb.toggled.connect(func(on):
			if on and not _modifiers.has(mid):
				_modifiers.append(mid)
			elif not on:
				_modifiers.erase(mid)
			_refresh_descriptions())
		_mod_box.add_child(cb)
		var d := UIKit.wrap_lbl(str(m.get("desc", "")), UIKit.C_MUTED, 14)
		d.add_theme_constant_override("line_spacing", 0)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 32)
		pad.add_child(d)
		_mod_box.add_child(pad)


func _refresh_descriptions() -> void:
	var mode: Dictionary = db.modes[_mode_id]
	var text: String = str(mode.get("desc", ""))
	if str(mode.get("special", "")) == "scenario" and db.scenarios.has(_scenario_id):
		text += "\n" + str(db.scenarios[_scenario_id].get("desc", ""))
	_mode_desc.text = text
	_diff_desc.text = str(db.difficulties[_difficulty_id].get("desc", ""))
	var mult: float = float(db.difficulties[_difficulty_id].get("score_mult", 1.0))
	for mid in _modifiers:
		mult *= float(db.modifiers[mid].get("score_mult", 1.0))
	_mult_label.text = "Score multiplier: x%.2f" % mult


func _start() -> void:
	var mode: Dictionary = db.modes[_mode_id]
	var special: String = str(mode.get("special", ""))
	var cfg: Dictionary
	if special == "daily":
		cfg = Game.daily_config()
	else:
		var seed_value: int = int(Time.get_ticks_usec() % 1000000007)
		if _seed_edit.text.strip_edges() != "":
			seed_value = int(hash(_seed_edit.text.strip_edges()) & 0x7fffffff)
		cfg = {"mode": _mode_id, "difficulty": _difficulty_id, "modifiers": _modifiers.duplicate(),
				"seed": seed_value, "goal": mode.get("goal", null)}
		if special == "scenario":
			cfg["scenario"] = _scenario_id
			cfg["goal"] = db.scenarios[_scenario_id].get("goal", null)
	start_run.emit(cfg)
