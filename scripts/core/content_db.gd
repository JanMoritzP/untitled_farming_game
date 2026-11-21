class_name ContentDB
extends RefCounted
## Loads every piece of game content from JSON.
## Base content lives in res://data, mods in user://mods/<name>/data.
## A mod file with the same name as a base file (e.g. items.json) adds new entries;
## an entry with an existing id replaces it, or patches it when it has "_patch": true.

const KINDS := ["items", "crops", "machines", "recipes", "weather", "seasons",
		"modifiers", "difficulties", "modes", "scenarios"]
const MODS_DIR := "user://mods"

var items: Dictionary = {}
var crops: Dictionary = {}
var machines: Dictionary = {}
var recipes: Dictionary = {}
var weather: Dictionary = {}
var seasons: Dictionary = {}
var modifiers: Dictionary = {}
var difficulties: Dictionary = {}
var modes: Dictionary = {}
var scenarios: Dictionary = {}

var crop_by_seed: Dictionary = {}
var errors: Array = []
var sources: Array = []


func load_all(include_mods: bool = true) -> void:
	_load_dir("res://data", "base")
	if include_mods and DirAccess.dir_exists_absolute(MODS_DIR):
		var dirs := DirAccess.get_directories_at(MODS_DIR)
		dirs.sort()
		for d in dirs:
			_load_dir(MODS_DIR.path_join(d).path_join("data"), d)
	_validate()
	for err in errors:
		push_warning("Content: " + str(err))


func _load_dir(dir: String, source: String) -> void:
	var any := false
	for kind in KINDS:
		var path: String = dir.path_join(kind + ".json")
		if not FileAccess.file_exists(path):
			continue
		any = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_ARRAY:
			errors.append("%s: %s is not a JSON array" % [source, path])
			continue
		var store: Dictionary = get(kind)
		for entry in parsed:
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
				errors.append("%s: entry without id in %s" % [source, path])
				continue
			var id := str(entry["id"])
			entry["_source"] = source
			if entry.get("_patch", false) and store.has(id):
				var existing: Dictionary = store[id]
				for k in entry:
					existing[k] = entry[k]
			else:
				store[id] = entry
	if any:
		sources.append(source)


func _validate() -> void:
	for sid in seasons.keys():
		var wd: Dictionary = seasons[sid].get("weather", {})
		for w in wd.keys():
			if not weather.has(w):
				errors.append("season %s references unknown weather %s" % [sid, w])
				wd.erase(w)
	for cid in crops.keys():
		var c: Dictionary = crops[cid]
		var ok: bool = items.has(c.get("seed", "")) and items.has(c.get("yield_item", ""))
		if not ok:
			errors.append("crop %s has unknown seed or yield item" % cid)
			crops.erase(cid)
			continue
		var valid_seasons: Array = []
		for s in c.get("seasons", []):
			if seasons.has(s):
				valid_seasons.append(s)
		c["seasons"] = valid_seasons
		crop_by_seed[c["seed"]] = cid
	for rid in recipes.keys():
		var r: Dictionary = recipes[rid]
		var ok: bool = machines.has(r.get("machine", ""))
		for k in r.get("inputs", {}):
			ok = ok and items.has(k)
		for k in r.get("outputs", {}):
			ok = ok and items.has(k)
		if not ok:
			errors.append("recipe %s references unknown machine or item" % rid)
			recipes.erase(rid)
	if seasons.is_empty():
		errors.append("no seasons defined")


func season_ids() -> Array:
	var ids: Array = seasons.keys()
	ids.sort_custom(func(a, b): return int(seasons[a].get("order", 0)) < int(seasons[b].get("order", 0)))
	return ids


func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


func item_tags(id: String) -> Array:
	return items.get(id, {}).get("tags", [])


func recipes_for(machine_id: String) -> Array:
	var out: Array = []
	for rid in recipes:
		if recipes[rid].machine == machine_id:
			out.append(rid)
	return out
