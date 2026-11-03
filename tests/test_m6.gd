extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_map_data()
	_test_sim_map_geometry()
	_test_selection_groups()
	await _test_map_editor_scene()
	if failures == 0:
		print("M6/M7 GRAPH TESTS PASS")
		quit(0)
	else:
		printerr("M6/M7 GRAPH TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _test_map_data() -> void:
	var map := MapData.load_file("res://data/maps/greyhaven_road.json")
	_check(map.errors.is_empty(), "greyhaven graph validates")
	_check(map.spawns_for_team(0).size() == 2, "map has two player routes")
	_check(map.spawns_for_team(1).size() == 2, "map has two enemy routes")
	_check(is_equal_approx(map.base_x(0), 140.0), "player base x comes from graph")
	_check(is_equal_approx(map.base_x(1), 1460.0), "enemy base x comes from graph")
	_check(is_equal_approx(map.edge_width("p_jn"), 80.0), "edge width loaded")
	_check(map.edge_capacity("p_jn", 12.0, 12) == 6, "width derives capacity")
	_check(map.node_by_id.has("j_north"), "junction node loaded")
	_check(map.edge_by_id.has("jn_js"), "cross edge loaded")
	var roundtrip := MapData.new()
	roundtrip.apply_dict(map.to_dict())
	_check(roundtrip.errors.is_empty(), "graph JSON roundtrip validates")
	var broken_dict: Dictionary = map.to_dict()
	broken_dict["edges"].erase(broken_dict["edges"][0])
	var broken := MapData.new()
	broken.apply_dict(broken_dict)
	_check(not broken.errors.is_empty(), "graph validation catches broken connections")


func _test_sim_map_geometry() -> void:
	var data := GameData.new()
	_check(data.load_all(), "GameData loads graph maps")
	_check(data.get_map_count() >= 2, "campaign references multiple maps")
	var level := _load_json("res://data/levels/level_01.json")
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron"]}, data)
	_check(sim.map_data.id == "greyhaven_crossroads", "sim loads the level graph")
	_check(is_equal_approx(sim.map_data.base_x(0), 140.0), "sim uses graph player base")
	_check(is_equal_approx(sim.map_data.base_x(1), 1460.0), "sim uses graph enemy base")
	_check(sim.player_spawns.size() == 2, "sim has two player routes")
	var snapshot := sim.get_snapshot()
	_check(snapshot.get("map", {}).get("nodes", []).size() >= 4, "snapshot carries graph nodes")
	_check(snapshot.get("routes", []).size() == 2, "snapshot carries routes")
	_check(is_equal_approx(float(snapshot.get("world_width", 0.0)), 1600.0), "snapshot world width")
	sim.queue_guild_action("iron")
	sim.tick()
	sim.queue_spawn(BattleSim.PLAYER, "north", "swordsman")
	sim.tick()
	_check(sim.units.size() == 1, "unit spawns on graph")
	if sim.units.size() > 0:
		var unit: SimUnit = sim.units[0]
		_check(unit.route_id == "north", "unit remembers spawn route")
		_check(unit.edge_id == "p_jn", "unit enters its route entry edge")
		for i in range(40):
			sim.tick()
		_check(unit.pos != Vector2(140.0, 450.0), "unit leaves base toward route")


func _test_selection_groups() -> void:
	var hud := BattleHUD.new()
	hud.size = Vector2(640, 360)
	root.add_child(hud)
	hud.snapshot = {
		"units": [
			{"id": 1, "team": 0, "pos": [300.0, 300.0], "x": 300.0, "y": 300.0, "hp": 100.0, "max_hp": 200.0, "def_id": "swordsman", "name": "剑士", "guild": "iron", "guild_name": "铁誓", "role": "vanguard", "attack_type": "melee", "armor_type": "heavy", "state": "advance", "edge_id": "p_jn"},
			{"id": 2, "team": 0, "pos": [350.0, 300.0], "x": 350.0, "y": 300.0, "hp": 50.0, "max_hp": 85.0, "def_id": "archer", "name": "弓手", "guild": "verdant", "guild_name": "绿荫", "role": "ranged", "attack_type": "ranged", "armor_type": "light", "state": "attack", "edge_id": "p_jn"},
			{"id": 3, "team": 0, "pos": [360.0, 320.0], "x": 360.0, "y": 320.0, "hp": 70.0, "max_hp": 85.0, "def_id": "archer", "name": "弓手", "guild": "verdant", "guild_name": "绿荫", "role": "ranged", "attack_type": "ranged", "armor_type": "light", "state": "engage", "edge_id": "p_js"},
		],
		"catalog": [],
		"routes": [],
		"finished": false,
	}
	hud.set_selection([1, 2, 3])
	_check(hud._selected_units().size() == 3, "selection panel finds selected units")
	var factions := hud.selection_groups(0)
	_check(factions.size() == 2, "selection groups by faction/guild")
	var ranged := hud.selection_groups(1)
	_check(ranged.size() == 2 and int(ranged[0]["count"]) == 2, "selection groups by attack type")
	var armor := hud.selection_groups(2)
	_check(armor.size() == 2, "selection groups by armor type")
	var classes := hud.selection_groups(3)
	_check(classes.size() == 2, "selection groups by class")
	var picked: Array = []
	hud.selection_changed.connect(func(ids: Array) -> void: picked.append(ids))
	hud.selection_tab = 0
	var row := hud._selection_row_rect(0)
	hud._handle_ui_click(row.get_center())
	_check(picked.size() == 1 and picked[0].size() == 2, "clicking a group emits its unit ids")
	hud.selection_tab = 2
	hud.queue_free()


func _test_map_editor_scene() -> void:
	var editor: Node = load("res://main/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	_check(editor.map != null, "map editor loads a graph map")
	_check(editor.map_paths.size() >= 2, "map editor lists map files")
	_check(not editor.levels.is_empty(), "map editor finds levels referencing the map")
	editor._validate_map()
	_check(editor.validation_errors.is_empty(), "map editor validates current map")
	editor.selected_edge = "p_jn"
	var old_width := float(editor.map.edge("p_jn").get("width", 80.0))
	editor._adjust_width(4.0)
	_check(float(editor.map.edge("p_jn").get("width", 80.0)) > old_width, "map editor adjusts edge width")
	var test_path := "user://m7_editor_save_test.json"
	editor.map.source_path = test_path
	editor._save_map()
	_check(FileAccess.file_exists(test_path), "map editor saves graph JSON")
	var saved := MapData.load_file(test_path)
	_check(saved.errors.is_empty(), "saved graph map reloads and validates")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	editor.queue_free()
	await process_frame


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
