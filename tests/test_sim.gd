extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_graph_movement()
	_test_heal_2d()
	_test_hud_input()
	_test_camera()
	_test_level_data()

	if failures == 0:
		print("TESTS PASS")
		quit(0)
	else:
		printerr("TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _test_graph_movement() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_set_advance_line(0, 700.0)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(300):
		sim.tick()
	var u: SimUnit = sim.units[0]
	var rally: Dictionary = sim.rallies["north"]
	_check(u.edge_id == String(rally["edge_id"]) and absf(u.edge_s - float(rally["s"])) < 20.0, "unit reaches graph rally")
	var held := u.pos
	for i in range(20):
		sim.tick()
	_check(u.pos.distance_to(held) < 2.0, "unit holds without oscillation")
	sim.queue_move_squad([u.id], Vector2(800.0, 450.0))
	for i in range(100):
		sim.tick()
	_check(u.pos.distance_to(Vector2(140.0, 450.0)) > 40.0, "manual move changes position")


func _test_heal_2d() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "cleric")
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	var cleric: SimUnit = sim.units[0]
	var tank: SimUnit = sim.units[1]
	cleric.pos = Vector2(300.0, 450.0)
	tank.pos = Vector2(315.0, 450.0)
	tank.hp = 30.0
	for i in range(3):
		sim.tick()
	_check(tank.hp > 30.0, "cleric heals by 2D distance")


func _test_hud_input() -> void:
	var hud := BattleHUD.new()
	hud.size = Vector2(640, 360)
	root.add_child(hud)
	hud.snapshot = {
		"catalog": [
			{"id": "swordsman", "name": "剑士", "cost": 30, "pop": 1, "unlocked": true, "requirement": "", "role": "vanguard", "attack_type": "melee", "armor_type": "heavy"},
		],
		"cooldowns": {"north": {}},
		"routes": [{"id": "north", "name": "北线", "used": 0, "capacity": 6, "rally": {}}],
		"guilds": [
			{"id": "iron", "name": "铁誓会", "tier": 0, "max_tier": 3, "unlocked": true, "next_cost": 60, "next_cap": 2, "next_unit_names": ["矛兵"], "favor": 0, "usage": 0, "rank_gate": 0, "identity_cn": "前排与重甲"},
		],
		"finished": false,
		"mode": "defense",
		"promo_kills": 1,
		"promo_cost": 40,
		"rep_rank": 0,
		"max_rank": 3,
		"world_width": 1600.0,
		"world_height": 900.0,
		"units": [],
		"map": {"edges": [], "nodes": []},
	}
	hud.active_route = 0
	hud.panel_open = false

	var spawned: Array = []
	hud.spawn_requested.connect(func(def_id: String) -> void: spawned.append(def_id))
	_click(hud, Vector2(40.0, 330.0))
	_check(spawned == ["swordsman"], "HUD card click requests spawn")

	var clicks: Array = []
	hud.minimap_clicked.connect(func(world_pos: Vector2) -> void: clicks.append(world_pos))
	_click(hud, Vector2(590.0, 40.0))
	_check(clicks.size() == 1, "HUD minimap click sends world point")

	var selections: Array = []
	hud.minimap_select.connect(func(rect: Rect2, additive: bool) -> void: selections.append(rect))
	_press(hud, Vector2(490.0, 30.0))
	_motion(hud, Vector2(570.0, 60.0))
	_release(hud, Vector2(570.0, 60.0))
	_check(selections.size() == 1 and selections[0].size.x > 0.0, "HUD minimap drag sends world rect")

	var orders: Array = []
	hud.minimap_order.connect(func(world_pos: Vector2, shift: bool) -> void: orders.append(shift))
	_right_click(hud, Vector2(590.0, 40.0), true)
	_check(orders.size() == 1 and bool(orders[0]), "HUD minimap right click requests rally")

	hud.panel_open = true
	var guild_actions: Array = []
	hud.guild_action_requested.connect(func(guild_id: String) -> void: guild_actions.append(guild_id))
	_click(hud, Vector2(200.0, 140.0))
	_check(guild_actions == ["iron"], "HUD guild row requests guild action")

	var promotions: Array = []
	hud.promote_requested.connect(func() -> void: promotions.append(true))
	_click(hud, Vector2(450.0, 94.0))
	_check(promotions.size() == 1, "HUD promote button requests promotion")

	var zoom: Array = []
	hud.zoom_requested.connect(func(delta: float) -> void: zoom.append(delta))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(300.0, 150.0)
	hud._gui_input(wheel)
	_check(zoom.size() == 1 and float(zoom[0]) > 0.0, "HUD wheel requests zoom")

	hud.snapshot["station_order"] = ["swordsman", "archer", "mage"]
	hud.snapshot["catalog"] = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "archer", "name": "弓手"},
		{"id": "mage", "name": "法师"},
	]
	var order_changes: Array = []
	hud.station_order_changed.connect(func(order: Array) -> void: order_changes.append(order))
	hud.open_station_order()
	_click(hud, hud._station_down_rect(0).get_center())
	_check(order_changes.size() == 1 and String(order_changes[0][0]) == "archer", "station order UI reorders classes")
	hud.queue_free()


func _test_camera() -> void:
	var cam := CameraRig.new()
	root.add_child(cam)
	cam.set_world_size(Vector2(1600, 900))
	cam.set_zoom_level(0.8)
	cam.jump_to(Vector2(0, 0))
	_check(cam.position.x >= 399.0 and cam.position.y >= 224.0, "camera clamps to zoomed half-view")
	cam.jump_to(Vector2(800, 450))
	_check(cam.camera_rect().size.x > 640.0, "camera rect reflects zoom")
	cam.set_world_size(Vector2(1600, 900))
	var snapshot := {"routes": [{"id": "north", "rally": {"pos": [300.0, 300.0]}}], "units": []}
	cam.focus_route(snapshot, 0)
	_check(cam.position.x > 300.0, "camera focuses active route rally")
	cam.queue_free()


func _test_level_data() -> void:
	for path in ["res://data/levels/level_01.json", "res://data/levels/level_02.json", "res://data/levels/level_03.json"]:
		var level := _load_json(path)
		_check(level.has("contract") and level.has("available_guilds"), path.get_file() + " has contract schema")
		_check(String(level.get("map", "")).ends_with(".json"), path.get_file() + " references a graph map")


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _click(hud: BattleHUD, pos: Vector2) -> void:
	_press(hud, pos)
	_release(hud, pos)


func _press(hud: BattleHUD, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	hud._gui_input(event)


func _release(hud: BattleHUD, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = pos
	hud._gui_input(event)


func _motion(hud: BattleHUD, pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	hud._gui_input(event)


func _right_click(hud: BattleHUD, pos: Vector2, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.shift_pressed = shift
	event.position = pos
	hud._gui_input(event)
