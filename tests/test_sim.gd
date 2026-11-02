extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_movement_snap()
	_test_combat_priority()
	_test_guild_and_reputation()
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


func _test_movement_snap() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_set_advance_line(0, 700.0)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(300):
		sim.tick()
	var u: SimUnit = sim.units[0]
	_check(is_equal_approx(u.x, 700.0), "unit snaps to advance line")
	var x := u.x
	for i in range(20):
		sim.tick()
	_check(is_equal_approx(sim.units[0].x, x), "unit does not oscillate")


func _test_combat_priority() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_set_advance_line(0, 400.0)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(100):
		sim.tick()
	var u: SimUnit = sim.units[0]
	u.x = 700.0
	u.manual_order = true
	u.move_target_x = 900.0
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman", false, false)
	var enemy: SimUnit = sim.units[1]
	enemy.x = 760.0
	enemy.hp = 10.0
	for i in range(30):
		sim.tick()
	_check(not enemy.alive or enemy.hp < 10.0, "combat interrupts movement")
	for i in range(200):
		sim.tick()
	if not u.alive:
		u = sim.get_unit_by_id(u.id)
	_check(u == null or u.x > 800.0, "movement resumes after combat")


func _test_guild_and_reputation() -> void:
	var level := {
		"mode": "defense",
		"base_hp": 20,
		"starting_gold": 500,
		"available_guilds": ["iron", "verdant", "arcane"],
		"waves": [],
	}
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron", "verdant", "arcane"]})
	sim.queue_guild_action("iron")
	sim.tick()
	_check(sim._unit_unlocked("swordsman"), "guild contact unlocks tier 0 class")
	sim.fame = 5
	sim.queue_promote()
	sim.tick()
	_check(sim.rep_rank == 1, "reputation promotion requires fame and gold")
	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 1, "guild tier 1 unlocks")


func _test_hud_input() -> void:
	var hud := BattleHUD.new()
	hud.size = Vector2(640, 360)
	root.add_child(hud)
	hud.snapshot = {
		"catalog": [
			{"id": "swordsman", "name": "Swordsman", "cost": 30, "pop": 1, "unlocked": true, "requirement": ""},
		],
		"cooldowns": [{}, {}],
		"guilds": [
			{"id": "iron", "name": "Iron Oath", "tier": 0, "max_tier": 3, "unlocked": true, "next_cost": 60, "next_cap": 2, "next_units": ["spearman"], "favor": 0, "usage": 0},
		],
		"finished": false,
		"mode": "defense",
		"promo_kills": 1,
		"promo_cost": 40,
	}
	hud.panel_open = false

	var spawned: Array = []
	hud.spawn_requested.connect(func(def_id: String) -> void: spawned.append(def_id))
	_click(hud, Vector2(40.0, 330.0))
	_check(spawned == ["swordsman"], "HUD card click requests spawn")

	var lanes: Array = []
	hud.minimap_clicked.connect(func(lane: int, x: float) -> void: lanes.append(lane))
	_click(hud, Vector2(590.0, 40.0))
	_check(lanes == [1], "HUD minimap click requests lane switch")

	var selections: Array = []
	hud.minimap_select.connect(func(lane: int, x1: float, x2: float, additive: bool) -> void: selections.append([lane, x1, x2]))
	_press(hud, Vector2(500.0, 40.0))
	_motion(hud, Vector2(560.0, 40.0))
	_release(hud, Vector2(560.0, 40.0))
	_check(selections.size() == 1 and int(selections[0][0]) == 1, "HUD minimap drag requests selection")

	var orders: Array = []
	hud.minimap_order.connect(func(lane: int, x: float, shift: bool) -> void: orders.append([lane, x, shift]))
	_right_click(hud, Vector2(590.0, 40.0), true)
	_check(orders.size() == 1 and bool(orders[0][2]), "HUD minimap right click requests line order")

	hud.panel_open = true
	var guild_actions: Array = []
	hud.guild_action_requested.connect(func(guild_id: String) -> void: guild_actions.append(guild_id))
	_click(hud, Vector2(200.0, 120.0))
	_check(guild_actions == ["iron"], "HUD guild row requests guild action")

	var promotions: Array = []
	hud.promote_requested.connect(func() -> void: promotions.append(true))
	_click(hud, Vector2(450.0, 94.0))
	_check(promotions.size() == 1, "HUD promote button requests promotion")

	hud.queue_free()


func _test_camera() -> void:
	var cam := CameraRig.new()
	root.add_child(cam)
	var snapshot := {"advance_lines": [92.0, 92.0], "units": [{"team": 0, "lane": 0, "x": 1500.0}]}
	cam.focus_lane(snapshot, 0)
	_check(is_equal_approx(cam.position.x, 1280.0), "camera follows front unit and clamps")
	cam.jump_to(0.0)
	_check(is_equal_approx(cam.position.x, 320.0), "camera jumps to left edge")
	cam.queue_free()


func _test_level_data() -> void:
	for path in ["res://data/levels/level_01.json", "res://data/levels/level_02.json", "res://data/levels/level_03.json"]:
		var level := _load_json(path)
		_check(level.has("contract") and level.has("available_guilds"), path.get_file() + " has contract schema")


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
