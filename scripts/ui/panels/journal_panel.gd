class_name JournalPanel
extends PanelBase
## The farm journal. Works with or without a running game (st may be null).


func _build() -> void:
	var items_total := 0
	for iid in db.items:
		if db.items[iid].get("category", "") != "seed":
			items_total += 1
	content.add_child(UIKit.wrap_lbl("Everything you discover is remembered across runs.", UIKit.C_MUTED))

	content.add_child(UIKit.heading("Goods  %d / %d" % [_known_items(), items_total]))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for iid in db.items:
		if db.items[iid].get("category", "") == "seed":
			continue
		grid.add_child(_item_cell(iid))
	content.add_child(grid)

	content.add_child(UIKit.heading("Recipes  %d / %d" % [journal.total("recipes"), db.recipes.size()]))
	for rid in db.recipes:
		var r: Dictionary = db.recipes[rid]
		var known := journal.has("recipes", rid)
		var line := UIKit.hb(6)
		if known:
			line.add_child(ingredient_strip(r["inputs"]))
			line.add_child(UIKit.lbl("->", UIKit.C_MUTED))
			line.add_child(ingredient_strip(r["outputs"]))
			line.add_child(UIKit.expander())
			line.add_child(UIKit.lbl("made %d" % journal.count_of("recipes", rid), UIKit.C_MUTED, 14))
		else:
			line.add_child(UIKit.lbl("???  (%s)" % db.machines[r["machine"]]["name"], UIKit.C_MUTED))
		content.add_child(line)

	content.add_child(UIKit.heading("Weather & Seasons"))
	var wrow := HFlowContainer.new()
	wrow.add_theme_constant_override("h_separation", 12)
	for wid in db.weather:
		var known := journal.has("weather", wid)
		wrow.add_child(UIKit.lbl(str(db.weather[wid]["name"]) if known else "???", UIKit.C_TEXT if known else UIKit.C_MUTED))
	for sid in db.season_ids():
		var known := journal.has("seasons", sid)
		wrow.add_child(UIKit.lbl(str(db.seasons[sid]["name"]) if known else "???",
				Color(str(db.seasons[sid].get("color", "#888888"))).darkened(0.35) if known else UIKit.C_MUTED))
	content.add_child(wrow)

	content.add_child(UIKit.heading("Career"))
	var lt: Dictionary = journal.lifetime
	content.add_child(UIKit.lbl("Runs: %d   Wins: %d   Days farmed: %d" % [lt["runs"], lt["wins"], lt["days"]]))
	content.add_child(UIKit.lbl("Earned: %s   Harvested: %d   Crafted: %d" % [UIKit.money(int(lt["income"])), lt["harvested"], lt["crafted"]]))
	if not journal.best_scores.is_empty():
		content.add_child(UIKit.lbl("Best scores", UIKit.C_BORDER))
		for k in journal.best_scores:
			content.add_child(UIKit.lbl("  %s: %s" % [_run_label(str(k)), UIKit.money(int(journal.best_scores[k]))], UIKit.C_MUTED, 15))


func _run_label(key: String) -> String:
	var parts := key.split(":")
	var mode: String = str(db.modes.get(parts[0], {}).get("name", parts[0]))
	if parts.size() == 3:
		mode += " / " + str(db.scenarios.get(parts[1], {}).get("name", parts[1]))
	return "%s (%s)" % [mode, parts[parts.size() - 1]]


func _known_items() -> int:
	var n := 0
	for iid in db.items:
		if db.items[iid].get("category", "") != "seed" and journal.has("items", iid):
			n += 1
	return n


func _item_cell(iid: String) -> Control:
	var known := journal.has("items", iid)
	var def: Dictionary = db.items[iid]
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UIKit.box(UIKit.C_PANEL_DARK if known else UIKit.C_PANEL_DEEP, UIKit.C_BORDER, 2, 4, 4))
	holder.custom_minimum_size = Vector2(64, 64)
	var ic := UIKit.icon(PixelArt.item_texture(db, iid, 3), 48)
	if not known:
		ic.modulate = Color(0.15, 0.1, 0.05, 0.55)
	holder.add_child(ic)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	if known:
		holder.tooltip_text = "%s\n%s\nBase price $%d" % [def["name"], def.get("desc", ""), int(def.get("base_price", 0))]
	else:
		holder.tooltip_text = "Undiscovered"
	return holder
