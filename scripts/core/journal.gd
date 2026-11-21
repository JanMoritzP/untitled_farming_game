class_name Journal
extends RefCounted
## The farm journal: everything the player has discovered, persisted across runs.

signal discovered(kind: String, id: String)

const PATH := "user://journal.dat"
const KINDS := ["items", "crops", "recipes", "weather", "seasons", "machines"]

var entries: Dictionary = {}   # kind -> {id -> {"count": int}}
var best_scores: Dictionary = {}   # run key -> int
var lifetime: Dictionary = {"runs": 0, "wins": 0, "days": 0, "income": 0, "harvested": 0, "crafted": 0}
var save_path: String = PATH


func _init() -> void:
	for k in KINDS:
		entries[k] = {}


func has(kind: String, id: String) -> bool:
	return entries.get(kind, {}).has(id)


func count_of(kind: String, id: String) -> int:
	return int(entries.get(kind, {}).get(id, {}).get("count", 0))


func discover(kind: String, id: String) -> bool:
	if not entries.has(kind):
		entries[kind] = {}
	var is_new: bool = not entries[kind].has(id)
	if is_new:
		entries[kind][id] = {"count": 0}
	entries[kind][id]["count"] = int(entries[kind][id]["count"]) + 1
	if is_new:
		discovered.emit(kind, id)
	return is_new


func total(kind: String) -> int:
	return entries.get(kind, {}).size()


func record_run(run_key: String, score: int, success: bool, days: int) -> bool:
	lifetime["runs"] += 1
	lifetime["days"] += days
	if success:
		lifetime["wins"] += 1
	var best: bool = score > int(best_scores.get(run_key, 0))
	if best:
		best_scores[run_key] = score
	return best


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({"entries": entries, "best": best_scores, "lifetime": lifetime})


func load_from_disk() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var d = f.get_var()
	if typeof(d) != TYPE_DICTIONARY:
		return
	for kind in d.get("entries", {}):
		entries[kind] = d["entries"][kind]
	best_scores = d.get("best", {})
	for k in d.get("lifetime", {}):
		lifetime[k] = d["lifetime"][k]
