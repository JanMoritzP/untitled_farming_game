class_name GameScreen
extends Control
## The in-game screen: top bar, farm grid, toolbar and the side tabs.
## Mouse only: click or drag on plots, buttons everywhere else.

signal exit_to_menu

var db: ContentDB
var st: FarmState
var journal: Journal

var speed := 1.0
var selected_tool := ""        # a seed item id, "compost", or "" for none
var modal_open := false
var _dirty := true
var _redraw_t := 0.0
var _pending_result: Dictionary = {}

var money_label: Label
var date_label: Label
var goal_label: Label
var weather_label: Label
var forecast_label: Label
var timer_bar: ProgressBar
var timer_label: Label
var pause_button: Button
var plot_views: Array = []
var overlay: WeatherOverlay
var tool_box: HBoxContainer
var tabs: TabContainer
var panels: Array = []
var toast_box: VBoxContainer
var modal_layer: Control
var _speed_buttons: Array = []
var _tool_buttons: Dictionary = {}
var _last_day_tab_refresh := -1


func setup(p_db: ContentDB, p_st: FarmState, p_journal: Journal) -> void:
	db = p_db
	st = p_st
	journal = p_journal
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := TextureRect.new()
	bg.texture = PixelArt.grass_tile()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var col := UIKit.vb(8)
	margin.add_child(col)
	col.add_child(_build_topbar())
	var mid := UIKit.hb(10)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)
	var left := UIKit.vb(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)
	left.add_child(_build_farm())
	left.add_child(_build_toolbar())
	mid.add_child(_build_tabs())

	toast_box = UIKit.vb(4)
	toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_box.position = Vector2(size.x - 560, 76)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	st.changed.connect(func(): _dirty = true)
	st.event.connect(toast)
	st.day_ended.connect(_on_day_ended)
	st.run_finished.connect(func(r): _pending_result = r)
	_refresh_all()
	if st.waiting_next_day:
		call_deferred("_show_summary_again")


func _show_summary_again() -> void:
	_on_day_ended({"day": st.day, "run_day": st.run_day(), "season": st.season_id, "weather": st.weather_today,
			"income": st.today["income"], "expenses": st.today["expenses"], "sold": st.today["sold"],
			"harvested": st.today["harvested"], "crafted": st.today["crafted"], "notes": st.today["notes"],
			"money": st.money, "net_worth": st.net_worth(),
			"tomorrow": "" if st.fxb("no_forecast") else st.weather_tomorrow})


# ------------------------------------------------------------------ building

func _build_topbar() -> Control:
	var bar := PanelContainer.new()
	var h := UIKit.hb(18)
	bar.add_child(h)

	money_label = UIKit.lbl("", UIKit.C_GOLD, 30)
	money_label.custom_minimum_size = Vector2(150, 0)
	h.add_child(money_label)

	var dv := UIKit.vb(0)
	date_label = UIKit.lbl("", UIKit.C_TEXT, 20)
	goal_label = UIKit.lbl("", UIKit.C_MUTED, 14)
	dv.add_child(date_label)
	dv.add_child(goal_label)
	dv.custom_minimum_size = Vector2(290, 0)
	h.add_child(dv)

	var wv := UIKit.vb(0)
	weather_label = UIKit.lbl("", UIKit.C_TEXT, 20)
	forecast_label = UIKit.lbl("", UIKit.C_MUTED, 14)
	wv.add_child(weather_label)
	wv.add_child(forecast_label)
	wv.custom_minimum_size = Vector2(170, 0)
	h.add_child(wv)

	var tv := UIKit.vb(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 20)
	timer_bar.show_percentage = false
	timer_bar.max_value = 1.0
	timer_label = UIKit.lbl("", UIKit.C_TEXT, 14)
	tv.add_child(timer_bar)
	tv.add_child(timer_label)
	h.add_child(tv)

	var group := ButtonGroup.new()
	var allow_pause: bool = bool(db.difficulties[st.cfg.get("difficulty", "normal")].get("allow_pause", false))
	var speeds: Array = [["||", 0.0], ["1x", 1.0], ["2x", 2.0], ["3x", 3.0]]
	for s in speeds:
		if s[1] == 0.0 and not allow_pause:
			continue
		var b := Button.new()
		b.text = s[0]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = s[1] == 1.0
		b.tooltip_text = "Pause" if s[1] == 0.0 else "Game speed %dx" % int(s[1])
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): speed = s[1])
		h.add_child(b)
		_speed_buttons.append(b)
	h.add_child(UIKit.btn("Menu", _open_pause_menu))
	return bar


func _build_farm() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box(Color("#8b6a43"), Color("#3b2a1a"), 4, 10, 10))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := Control.new()
	var gw := FarmState.COLS * PlotView.SIZE + (FarmState.COLS - 1) * 6
	var gh := FarmState.ROWS * PlotView.SIZE + (FarmState.ROWS - 1) * 6
	holder.custom_minimum_size = Vector2(gw, gh)
	frame.add_child(holder)
	var grid := GridContainer.new()
	grid.columns = FarmState.COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(grid)
	for i in st.plots.size():
		var pv := PlotView.new()
		pv.idx = i
		pv.st = st
		pv.db = db
		pv.pressed.connect(_plot_action.bind(false))
		pv.drag_over.connect(_plot_action.bind(true))
		grid.add_child(pv)
		plot_views.append(pv)
	overlay = WeatherOverlay.new()
	overlay.custom_minimum_size = holder.custom_minimum_size
	overlay.size = holder.custom_minimum_size
	holder.add_child(overlay)
	return frame


func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	var v := UIKit.vb(4)
	bar.add_child(v)
	var cap := UIKit.lbl("Tools - pick seeds, then click or drag over empty plots. Ripe crops harvest on click.", UIKit.C_MUTED, 15)
	v.add_child(cap)
	tool_box = UIKit.hb(6)
	v.add_child(tool_box)
	return bar


func _rebuild_toolbar() -> void:
	UIKit.clear(tool_box)
	_tool_buttons.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for cid in st.available_crops():
		var c: Dictionary = db.crops[cid]
		_add_tool_button(group, c["seed"], "%d" % st.count_item(c["seed"]), _seed_tooltip(cid),
				c["seasons"].has(st.season_id))
	if st.machine_available("composter"):
		_add_tool_button(group, "compost", "%d" % st.count_item("compost"),
				"Compost\nClick a plot to restore soil fertility.", true)
	if selected_tool != "" and not _tool_buttons.has(selected_tool):
		selected_tool = ""


func _add_tool_button(group: ButtonGroup, item_id: String, count_text: String, tip: String, usable: bool) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.icon = PixelArt.item_texture(db, item_id, 2)
	b.text = count_text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_constant_override("icon_max_width", 32)
	b.button_pressed = selected_tool == item_id
	if not usable:
		b.modulate = Color(1, 1, 1, 0.55)
	b.toggled.connect(func(on):
		selected_tool = item_id if on else "")
	tool_box.add_child(b)
	_tool_buttons[item_id] = b


func _seed_tooltip(cid: String) -> String:
	var c: Dictionary = db.crops[cid]
	var lines: Array = [db.item_name(c["seed"])]
	var names: Array = []
	for s in c["seasons"]:
		names.append(str(db.seasons[s]["name"]))
	lines.append("Grows in: " + ", ".join(names))
	lines.append("Takes %d days" % int(c["grow_days"]))
	if not c["seasons"].has(st.season_id):
		lines.append("Can't be planted this season!")
	else:
		var left: int = st.season_len - st.season_day + 1
		if left < int(c["grow_days"]):
			lines.append("Warning: may not finish before the season ends (%d days left)" % left)
	if c.get("frost_sensitive", false):
		lines.append("Frost kills this crop.")
	return "\n".join(lines)


func _build_tabs() -> Control:
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var defs: Array = [["Shop", ShopPanel], ["Machines", MachinesPanel], ["Market", MarketPanel],
			["Orders", OrdersPanel], ["Journal", JournalPanel]]
	for d in defs:
		var p: PanelBase = d[1].new()
		p.name = d[0]
		tabs.add_child(p)
		p.setup(db, st, journal, self)
		panels.append(p)
	tabs.tab_changed.connect(func(i): panels[i].refresh())
	return tabs


# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	if st == null:
		return
	if not modal_open and speed > 0.0:
		st.tick(delta * speed)
	_update_clock()
	if _dirty:
		_dirty = false
		_refresh_all()
	_redraw_t += delta
	if _redraw_t > 0.2:
		_redraw_t = 0.0
		for pv in plot_views:
			pv.refresh()
		panels[tabs.current_tab].tick()


func _update_clock() -> void:
	var frac := st.day_fraction()
	timer_bar.value = frac
	var left: float = maxf(0.0, st.day_length - st.day_time)
	timer_label.text = "%d:%02d left today" % [int(left) / 60, int(left) % 60]
	var fill := UIKit.box(UIKit.C_GOOD.lerp(UIKit.C_BAD, smoothstep(0.55, 1.0, frac)), UIKit.C_BORDER, 0, 0, 0)
	timer_bar.add_theme_stylebox_override("fill", fill)
	overlay.dusk = smoothstep(0.65, 1.0, frac)


func _refresh_all() -> void:
	money_label.text = UIKit.money(st.money)
	money_label.add_theme_color_override("font_color", UIKit.C_BAD if st.money < 0 else UIKit.C_GOLD)
	var sdef: Dictionary = db.seasons[st.season_id]
	date_label.text = "%s - Day %d/%d - Year %d" % [sdef["name"], st.season_day, st.season_len, st.year]
	date_label.add_theme_color_override("font_color", Color(str(sdef.get("color", "#000000"))).darkened(0.55))
	var goal = st.cfg.get("goal", null)
	if typeof(goal) == TYPE_DICTIONARY:
		goal_label.text = "Goal: %s net worth by day %d (day %d)  |  now %s" % [
				UIKit.money(st.goal_target()), int(goal["days"]), st.run_day(), UIKit.money(st.net_worth())]
	else:
		goal_label.text = "Endless  |  day %d  |  net worth %s" % [st.run_day(), UIKit.money(st.net_worth())]
	var wdef: Dictionary = db.weather[st.weather_today]
	weather_label.text = str(wdef["name"])
	weather_label.add_theme_color_override("font_color", UIKit.C_BAD if wdef.get("bad", false) else UIKit.C_TEXT)
	forecast_label.text = "Forecast hidden" if st.fxb("no_forecast") else "Tomorrow: %s" % db.weather[st.weather_tomorrow]["name"]
	overlay.set_weather(wdef)
	_rebuild_toolbar()
	for pv in plot_views:
		pv.refresh()
	panels[tabs.current_tab].refresh()


# ------------------------------------------------------------------ plot actions

func _plot_action(idx: int, dragging: bool) -> void:
	if modal_open:
		return
	var p: Dictionary = st.plots[idx]
	if p["state"] == "locked":
		if not dragging:
			_show_plot_modal(idx)
		return
	if p["ready"]:
		st.harvest(idx)
		return
	if selected_tool == "":
		return
	var err := ""
	if selected_tool == "compost":
		err = st.fertilize(idx)
	elif p["crop"] == "":
		err = st.plant(idx, db.crop_by_seed.get(selected_tool, ""))
	if err != "" and not dragging:
		toast(err, "bad")


# ------------------------------------------------------------------ toasts

func toast(text: String, kind: String = "info") -> void:
	if toast_box == null:
		return
	while toast_box.get_child_count() >= 5:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var colors := {"info": Color("#f3e2b8"), "good": Color("#d6efc0"), "bad": Color("#f6c9c3"), "journal": Color("#d9e4f7")}
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(colors.get(kind, colors["info"]), UIKit.C_BORDER, 3, 10, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.lbl(text, UIKit.C_BAD.darkened(0.2) if kind == "bad" else UIKit.C_TEXT, 17)
	p.add_child(l)
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(3.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ modals

func open_modal(content: Control, min_width: int = 420) -> void:
	close_modal()
	modal_open = true
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.C_PANEL, UIKit.C_BORDER, 4, 18, 14))
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.add_child(content)
	center.add_child(panel)


func close_modal() -> void:
	UIKit.clear(modal_layer)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_open = false


func _show_plot_modal(idx: int) -> void:
	var pr := st.plot_prices()
	var v := UIKit.vb(10)
	v.add_child(UIKit.lbl("Claim this plot", UIKit.C_BORDER, 26))
	v.add_child(UIKit.wrap_lbl("Lease it for a season (renews automatically while you can pay), or buy it outright. Owned plots also add to your net worth.", UIKit.C_TEXT))
	if st.unlocked_count() >= st.max_plots():
		v.add_child(UIKit.lbl("Plot limit reached (%d)." % st.max_plots(), UIKit.C_BAD))
	var row := UIKit.hb(10)
	var lease := UIKit.btn("Lease  %s / season" % UIKit.money(pr["lease"]), func():
		_claim(idx, true))
	var buy := UIKit.btn("Buy  %s" % UIKit.money(pr["buy"]), func():
		_claim(idx, false))
	lease.disabled = st.plot_unlock_error(idx, true) != ""
	buy.disabled = st.plot_unlock_error(idx, false) != ""
	lease.tooltip_text = st.plot_unlock_error(idx, true)
	buy.tooltip_text = st.plot_unlock_error(idx, false)
	row.add_child(lease)
	row.add_child(buy)
	row.add_child(UIKit.expander())
	row.add_child(UIKit.btn("Cancel", close_modal))
	v.add_child(row)
	open_modal(v, 460)


func _claim(idx: int, lease: bool) -> void:
	var err := st.buy_plot(idx, lease)
	if err != "":
		toast(err, "bad")
	close_modal()


func _on_day_ended(s: Dictionary) -> void:
	Game.save_run()
	var v := UIKit.vb(8)
	var season_name: String = str(db.seasons[s["season"]]["name"])
	v.add_child(UIKit.lbl("Day %d complete" % int(s["run_day"]), UIKit.C_BORDER, 30))
	v.add_child(UIKit.lbl("%s  -  %s" % [season_name, db.weather[s["weather"]]["name"]], UIKit.C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	var net: int = int(s["income"]) - int(s["expenses"])
	for pair in [["Sales", UIKit.money(int(s["income"])), UIKit.C_GOOD], ["Expenses", UIKit.money(-int(s["expenses"])) if int(s["expenses"]) > 0 else "$0", UIKit.C_BAD],
			["Net today", UIKit.money(net), UIKit.C_GOOD if net >= 0 else UIKit.C_BAD],
			["Money", UIKit.money(int(s["money"])), UIKit.C_GOLD], ["Net worth", UIKit.money(int(s["net_worth"])), UIKit.C_GOLD]]:
		grid.add_child(UIKit.lbl(pair[0]))
		grid.add_child(UIKit.lbl(pair[1], pair[2]))
	v.add_child(grid)
	for entry in [["Harvested", s["harvested"]], ["Crafted", s["crafted"]], ["Sold", s["sold"]]]:
		if not entry[1].is_empty():
			v.add_child(UIKit.wrap_lbl("%s: %s" % [entry[0], UIKit.counts_text(db, entry[1])], UIKit.C_TEXT, 15))
	for n in s["notes"]:
		v.add_child(UIKit.wrap_lbl("- " + str(n), UIKit.C_MUTED, 15))
	if str(s["tomorrow"]) != "":
		v.add_child(UIKit.lbl("Tomorrow: %s" % db.weather[s["tomorrow"]]["name"], UIKit.C_TEXT))
	var finished: bool = st.finished
	var go := UIKit.btn("See results" if finished else "Start day %d" % (int(s["run_day"]) + 1), _next_day)
	v.add_child(go)
	open_modal(v, 460)


func _next_day() -> void:
	close_modal()
	if st.finished:
		_show_result()
	else:
		st.start_next_day()


func _show_result() -> void:
	var r := _pending_result
	var v := UIKit.vb(10)
	var ok: bool = bool(r.get("success", false))
	v.add_child(UIKit.lbl("Run complete!" if ok else "Run over", UIKit.C_BORDER, 32))
	var stars := UIKit.hb(6)
	for i in 3:
		stars.add_child(UIKit.icon(PixelArt.star_texture(i < int(r.get("stars", 0)), 4), 44))
	v.add_child(stars)
	v.add_child(UIKit.lbl("Net worth %s  (goal %s)" % [UIKit.money(int(r["net_worth"])), UIKit.money(int(r["target"]))]))
	v.add_child(UIKit.lbl("Score %s  (x%.2f challenge bonus)" % [UIKit.money(int(r["score"])), float(r["multiplier"])], UIKit.C_GOLD, 22))
	if r.get("new_best", false):
		v.add_child(UIKit.lbl("New personal best!", UIKit.C_GOOD))
	var row := UIKit.hb(10)
	row.add_child(UIKit.btn("Keep farming", func():
		close_modal()
		st.continue_endless()
		st.start_next_day()))
	row.add_child(UIKit.expander())
	row.add_child(UIKit.btn("Main menu", func():
		Game.delete_save()
		close_modal()
		exit_to_menu.emit()))
	v.add_child(row)
	open_modal(v, 440)


func _open_pause_menu() -> void:
	var v := UIKit.vb(10)
	v.add_child(UIKit.lbl("Paused", UIKit.C_BORDER, 28))
	v.add_child(UIKit.btn("Resume", close_modal))
	v.add_child(UIKit.btn("Save and quit to menu", func():
		Game.save_run()
		close_modal()
		exit_to_menu.emit()))
	v.add_child(UIKit.btn("Abandon run", func():
		Game.delete_save()
		close_modal()
		exit_to_menu.emit()))
	open_modal(v, 320)
