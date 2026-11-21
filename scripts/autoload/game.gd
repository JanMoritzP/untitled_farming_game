extends Node
## Global session holder: content, journal and the current run.

const SAVE_PATH := "user://run.dat"

var db: ContentDB
var journal: Journal
var state: FarmState


func _ready() -> void:
	db = ContentDB.new()
	db.load_all()
	journal = Journal.new()
	journal.load_from_disk()


func start_run(cfg: Dictionary) -> FarmState:
	state = FarmState.create(db, cfg, journal)
	return state


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run() -> void:
	if state == null or state.finished:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(state.to_dict())
	journal.save()


func load_run() -> FarmState:
	if not has_save():
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = f.get_var() if f != null else null
	if typeof(d) != TYPE_DICTIONARY:
		return null
	state = FarmState.restore(db, d, journal)
	return state


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## The daily challenge: same seed and modifiers for everyone on a given date.
func daily_config() -> Dictionary:
	var date := Time.get_date_dict_from_system()
	var seed_value: int = int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var ids: Array = db.modifiers.keys()
	var picked: Array = []
	while picked.size() < 2 and picked.size() < ids.size():
		var m: String = ids[r.randi_range(0, ids.size() - 1)]
		if not picked.has(m):
			picked.append(m)
	return {"mode": "daily", "difficulty": "normal", "modifiers": picked, "seed": seed_value,
			"goal": db.modes["daily"]["goal"]}
