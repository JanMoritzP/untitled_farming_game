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
var fx: FxLayer
var _last_money := 0
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

	fx = FxLayer.new()
	add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	var h := UIKit.hb(12)
	bar.add_child(h)

	var coin_box := UIKit.hb(6)
	coin_box.add_child(UIKit.icon(PixelArt.coin_texture(3), 40))
	money_label = UIKit.pop_lbl("", Color("#ffd23a"), 32, 8)
	money_label.custom_minimum_size = Vector2(130, 0)
	coin_box.add_child(money_label)
	h.add_child(coin_box)

	var dv := UIKit.vb(0)
	date_label = UIKit.lbl("", UIKit.C_TEXT, 20)
	goal_label = UIKit.lbl("", UIKit.C_MUTED, 14)
	dv.add_child(date_label)
	dv.add_child(goal_label)
	dv.custom_minimum_size = Vector2(250, 0)
	h.add_child(dv)

	var wv := UIKit.vb(0)
	weather_label = UIKit.lbl("", UIKit.C_TEXT, 20)
	forecast_label = UIKit.lbl("", UIKit.C_MUTED, 14)
	wv.add_child(weather_label)
	wv.add_child(forecast_label)
	wv.custom_minimum_size = Vector2(130, 0)
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
	var speeds: Array = [["||", 0.0], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0]]
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
	h.add_child(UIKit.btn("Skip", func(): st.skip_to_evening(),
			"Skip to the end of the day. Crops and machines keep running."))
	h.add_child(UIKit.btn("Menu", _open_pause_menu))
	return bar


func _build_farm() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box(Color("#d9a05b"), Color("#4a2a12"), 5, 12, 12, 0, true))
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
		pv.ghost_provider = _ghost_tool
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
	var cap := UIKit.wrap_lbl("Pick seeds, then click or drag over empty plots. Click ripe crops to harvest.", UIKit.C_MUTED, 15)
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
	b.add_theme_constant_override("icon_max_width", 36)
	b.button_pressed = selected_tool == item_id
	var on_style := UIKit.box(UIKit.C_GREEN, UIKit.C_BORDER, 3, 12, 5, 0)
	b.add_theme_stylebox_override("pressed", on_style)
	b.add_theme_stylebox_override("hover_pressed", on_style)
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
	lines.append("Grows in about %d seconds" % int(round(float(c["grow_days"]) * st.day_length)))
	if not c["seasons"].has(st.season_id):
		lines.append("Can't be planted this season!")
	else:
		var left: int = st.season_len - st.season_day + 1
		if float(left) < float(c["grow_days"]):
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
	money_label.add_theme_color_override("font_color", Color("#ff6a5a") if st.money < 0 else Color("#ffd23a"))
	if st.money != _last_money:
		if st.money > _last_money:
			_pop_node(money_label, 1.35)
		_last_money = st.money
	var sdef: Dictionary = db.seasons[st.season_id]
	date_label.text = "%s - Day %d/%d - Year %d" % [sdef["name"], st.season_day, st.season_len, st.year]
	date_label.add_theme_color_override("font_color", Color(str(sdef.get("color", "#000000"))).darkened(0.55))
	var goal = st.cfg.get("goal", null)
	if typeof(goal) == TYPE_DICTIONARY:
		goal_label.text = "Goal %s | now %s | day %d/%d" % [
				UIKit.money(st.goal_target()), UIKit.money(st.net_worth()), st.run_day(), int(goal["days"])]
	else:
		goal_label.text = "Endless | worth %s | day %d" % [UIKit.money(st.net_worth()), st.run_day()]
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
		var item: String = db.crops[p["crop"]]["yield_item"]
		var before: int = int(st.today["harvested"].get(item, 0))
		if st.harvest(idx):
			var gained: int = int(st.today["harvested"].get(item, 0)) - before
			var col := Color(str(db.items[item].get("color", "#ffffff")))
			var center := _plot_center(idx)
			fx.burst(center, [col, col.lightened(0.4), Color("#fff6a8")], 16)
			fx.float_text(center - Vector2(0, 20), "+%d" % gained, Color("#ffffff"), 24)
			plot_views[idx].pop()
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
	elif err == "":
		plot_views[idx].pop()
		var soil := [Color("#8a4f26"), Color("#b87a42"), Color("#d9a566")]
		if selected_tool == "compost":
			soil = [Color("#4cc94a"), Color("#8cf04a"), Color("#6b4a2b")]
		fx.burst(_plot_center(idx) + Vector2(0, 14), soil, 8, 110.0)


func _ghost_tool() -> String:
	if selected_tool == "compost":
		return "compost"
	return str(db.crop_by_seed.get(selected_tool, ""))


func _plot_center(idx: int) -> Vector2:
	var pv: Control = plot_views[idx]
	return pv.global_position + pv.size / 2.0


func _pop_node(c: Control, amount: float) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(amount, amount)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Called by the panels after a sale or delivery: coin burst and floating amount at the mouse.
func fx_money(amount: int) -> void:
	var pos := get_global_mouse_position()
	fx.burst(pos, [Color("#ffd23a"), Color("#fff2a0"), Color("#f2a100")], 12, 150.0)
	fx.float_text(pos - Vector2(0, 24), "+" + UIKit.money(amount), Color("#ffd23a"), 28)


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
	var buy := UIKit.btn_primary("Buy  %s" % UIKit.money(pr["buy"]), func():
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
	v.add_child(UIKit.pop_lbl("Day %d complete" % int(s["run_day"]), Color("#ffd23a"), 34, 8))
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
	var go := UIKit.btn_primary("See results" if finished else "Start day %d" % (int(s["run_day"]) + 1), _next_day)
	go.custom_minimum_size = Vector2(0, 44)
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
	v.add_child(UIKit.pop_lbl("Run complete!" if ok else "Run over", Color("#ffd23a"), 38, 9))
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
	v.add_child(UIKit.btn_primary("Resume", close_modal))
	v.add_child(UIKit.btn("Save and quit to menu", func():
		Game.save_run()
		close_modal()
		exit_to_menu.emit()))
	v.add_child(UIKit.btn_danger("Abandon run", func():
		Game.delete_save()
		close_modal()
		exit_to_menu.emit()))
	open_modal(v, 320)
