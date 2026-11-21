extends Control
## Root scene: owns the theme and swaps between the menu and the game screen.

var _current: Control


func _ready() -> void:
	theme = UIKit.make_theme()
	_show_menu()


func _clear() -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
		_current = null


func _show_menu() -> void:
	_clear()
	var menu := Menu.new()
	add_child(menu)
	menu.setup(Game.db, Game.journal)
	menu.start_run.connect(func(cfg):
		Game.start_run(cfg)
		_enter_game())
	menu.continue_run.connect(func():
		if Game.load_run() != null:
			_enter_game())
	menu.quit_game.connect(func(): get_tree().quit())
	_current = menu


func _enter_game() -> void:
	_clear()
	var gs := GameScreen.new()
	add_child(gs)
	gs.setup(Game.db, Game.state, Game.journal)
	gs.exit_to_menu.connect(_show_menu)
	_current = gs


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_run()
