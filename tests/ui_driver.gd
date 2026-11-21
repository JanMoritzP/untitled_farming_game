extends Node
## Drives the real UI under a (virtual) display and saves screenshots.
## xvfb-run -a godot --path . tests/ui_driver.tscn -- /output/dir

var out_dir := "/tmp"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run()


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await shot("01_title")
	var menu: Menu = main._current
	menu._show_setup()
	await shot("02_setup")
	var cfg := {"mode": "classic", "difficulty": "normal", "modifiers": [], "seed": 7,
			"goal": {"type": "net_worth", "target": 2200, "days": 28}}
	menu.start_run.emit(cfg)
	await get_tree().process_frame
	var gs: GameScreen = main._current
	await shot("03_game_start")
	# plant on all owned plots
	gs.selected_tool = "wheat_seed"
	for i in gs.st.plots.size():
		if gs.st.plots[i].state == "owned":
			gs._plot_action(i, true)
	await shot("04_planted")
	gs.tabs.current_tab = 1
	await shot("05_machines_tab")
	gs.tabs.current_tab = 0
	# fast-forward growth
	gs.st.tick(150.0)
	await shot("06_growing")
	gs.st.tick(100.0)   # end of day 1 -> summary modal
	await shot("07_day_summary")
	gs._next_day()
	gs.st.tick(120.0)
	await shot("08_day2")
	for i in gs.st.plots.size():
		if gs.st.plots[i].ready:
			gs._plot_action(i, false)
	gs.tabs.current_tab = 2
	await shot("09_market")
	gs.tabs.current_tab = 3
	await shot("10_orders")
	gs.tabs.current_tab = 4
	await shot("11_journal")
	gs._show_plot_modal(23)
	await shot("12_plot_modal")
	gs.close_modal()
	# a rainy autumn day with a crowded farm
	gs.st.money = 5000
	for i in gs.st.plots.size():
		if gs.st.plots[i].state == "locked":
			gs.st.buy_plot(i, i % 2 == 0)
	gs.st.weather_today = "rain"
	gs.st.day = 15
	gs.st._apply_season(15)
	gs.st._add_item("pumpkin_seed", 30)
	gs.st._add_item("flour", 7, 1)
	gs.st._add_item("bread", 9, 2)
	gs.selected_tool = "pumpkin_seed"
	for i in gs.st.plots.size():
		gs._plot_action(i, true)
	gs.st.tick(60.0)
	gs.st.buy_machine("mill")
	gs.st.queue_job("mill", "flour", 3)
	gs.tabs.current_tab = 1
	gs._dirty = true
	await shot("13_autumn_rain")
	await get_tree().create_timer(0.3).timeout
	await shot("14_autumn_rain_b")

	# --- run end: result screen ---
	main._show_menu()
	await get_tree().process_frame
	menu = main._current
	menu.start_run.emit({"mode": "sprint", "difficulty": "cozy", "modifiers": ["vegan", "harsh"], "seed": 3,
			"goal": {"type": "net_worth", "target": 100, "days": 1}})
	await get_tree().process_frame
	gs = main._current
	gs.st.tick(1000.0)
	await shot("15_last_day_summary")
	gs._next_day()
	await shot("16_result")
	gs.close_modal()

	# --- save then Continue ---
	main._show_menu()
	await get_tree().process_frame
	menu = main._current
	menu.start_run.emit({"mode": "endless", "difficulty": "hard", "modifiers": ["blind", "no_bakery"], "seed": 5, "goal": null})
	await get_tree().process_frame
	gs = main._current
	gs.st.tick(500.0)
	await get_tree().process_frame
	var money_before: int = gs.st.money
	Game.save_run()
	main._show_menu()
	await shot("17_title_with_continue")
	menu = main._current
	menu.continue_run.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	gs = main._current
	print("continue ok: ", gs is GameScreen, " money match: ", gs.st.money == money_before, " waiting: ", gs.st.waiting_next_day, " modal: ", gs.modal_open)
	await shot("18_continued")
	gs._next_day()
	await shot("19_continued_day2")
	gs._open_pause_menu()
	await shot("20_pause_menu")
	gs.close_modal()
	Game.delete_save()
	get_tree().quit(0)
