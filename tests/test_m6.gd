extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_map_data()
	_test_sim_map_geometry()
	_test_selection_groups()
	await _test_map_editor_scene()
	if failures == 0:
		print("M6 TESTS PASS")
		quit(0)
	else:
		printerr("M6 TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _test_map_data() -> void:
	var map := MapData.load_file("res://data/maps/greyhaven_road.json")
	_check(map.errors.is_empty(), "greyhaven map validates")
	_check(map.route_count() == 2, "map has two routes")
	_check(is_equal_approx(map.base_x(0), 80.0), "player base x comes from map")
	_check(is_equal_approx(map.base_x(1), 1520.0), "enemy base x comes from map")
	_check(is_equal_approx(map.width_at(0, 900.0), 64.0), "width segment lookup works")
	_check(is_equal_approx(map.width_at(1, 800.0), 92.0), "second lane width segment works")
	_check(is_equal_approx(map.spawn_x(0, 0), 92.0), "player spawn comes from map")
	_check(is_equal_approx(map.spawn_x(0, 1), 1508.0), "enemy spawn comes from map")
	var roundtrip := MapData.new()
	roundtrip.apply_dict(map.to_dict())
	_check(roundtrip.errors.is_empty(), "map JSON roundtrip validates")

	var broken := MapData.new()
	var broken_dict: Dictionary = map.to_dict()
	broken_dict["routes"][0]["segments"] = [{"from": 300.0, "to": 500.0, "width": 80.0}]
	broken.apply_dict(broken_dict)
	_check(not broken.errors.is_empty(), "map validation catches uncovered bases")


func _test_sim_map_geometry() -> void:
	var data := GameData.new()
	_check(data.load_all(), "GameData loads maps with campaign")
	_check(data.get_map_count() >= 2, "campaign references multiple maps")
	var level := _load_json("res://data/levels/level_01.json")
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron"]}, data)
	_check(sim.map_data.id == "greyhaven_road", "sim loads the level map")
	_check(is_equal_approx(sim.player_base_x, 80.0), "sim uses map player base")
	_check(is_equal_approx(sim.enemy_base_x, 1520.0), "sim uses map enemy base")
	_check(sim.lane_count == 2, "sim keeps two lanes")
	_check(is_equal_approx(float(sim.advance_lines[0]), 92.0), "advance line starts at map spawn")
	var snapshot := sim.get_snapshot()
	_check(snapshot.get("map", {}).get("routes", []).size() == 2, "snapshot carries route data")
	_check(is_equal_approx(float(snapshot.get("world_width", 0.0)), 1600.0), "snapshot world width comes from map")
	sim.queue_guild_action("iron")
	sim.tick()
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	var unit: SimUnit = sim.units[0]
	_check(unit != null and is_equal_approx(unit.x, 92.0), "unit spawns at map player spawn")


func _test_selection_groups() -> void:
	var hud := BattleHUD.new()
	hud.size = Vector2(640, 360)
	root.add_child(hud)
	hud.snapshot = {
		"units": [
			{"id": 1, "team": 0, "lane": 0, "x": 300.0, "hp": 100.0, "max_hp": 200.0, "def_id": "swordsman", "name": "剑士", "guild": "iron", "guild_name": "铁誓", "role": "vanguard", "attack_type": "melee", "armor_type": "heavy", "state": "advance"},
			{"id": 2, "team": 0, "lane": 0, "x": 350.0, "hp": 50.0, "max_hp": 85.0, "def_id": "archer", "name": "弓手", "guild": "verdant", "guild_name": "绿荫", "role": "ranged", "attack_type": "ranged", "armor_type": "light", "state": "attack"},
			{"id": 3, "team": 0, "lane": 1, "x": 360.0, "hp": 70.0, "max_hp": 85.0, "def_id": "archer", "name": "弓手", "guild": "verdant", "guild_name": "绿荫", "role": "ranged", "attack_type": "ranged", "armor_type": "light", "state": "engage"},
		],
		"catalog": [],
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
	hud._handle_ui_click(Vector2(500.0, 128.0))
	_check(picked.size() == 1 and picked[0].size() == 2, "clicking a group emits its unit ids")
	var tab_rect := hud._selection_tab_rect(2)
	hud._handle_ui_click(tab_rect.get_center())
	_check(hud.selection_tab == 2, "clicking a category tab changes the grouping")
	hud.queue_free()


func _test_map_editor_scene() -> void:
	var editor: Node = load("res://main/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	_check(editor.map != null, "map editor loads a map")
	_check(editor.map_paths.size() >= 2, "map editor lists map files")
	_check(not editor.levels.is_empty(), "map editor finds levels referencing the map")
	editor._validate_map()
	_check(editor.validation_errors.is_empty(), "map editor validates current map")

	var test_path := "user://m6_editor_save_test.json"
	editor.map.source_path = test_path
	editor.selected_kind = "segment"
	editor.selected_lane = 0
	editor.selected_segment = 0
	var old_width := float(editor.map.route(0)["segments"][0]["width"])
	editor._adjust_width(4.0)
	_check(float(editor.map.route(0)["segments"][0]["width"]) > old_width, "map editor adjusts segment width")
	editor._save_map()
	_check(FileAccess.file_exists(test_path), "map editor saves JSON")
	var saved := MapData.load_file(test_path)
	_check(saved.errors.is_empty(), "saved map reloads and validates")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	editor.queue_free()
	await process_frame


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
