extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_spawn_and_advance()
	_test_lane_isolation()
	_test_melee_damage()
	_test_ranged_projectile()
	_test_damage_modifiers()
	_test_splash()
	_test_base_damage_and_win()
	_test_economy()
	_test_buildings()
	_test_kill_reward()
	_test_waves()
	_test_level_data()
	_test_level_no_input()
	_test_hud_input()
	_test_determinism()

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


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _test_spawn_and_advance() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	_check(sim.units.size() == 1, "spawn adds one unit")

	var start_x: float = sim.units[0].x
	sim.tick()
	_check(sim.units[0].x > start_x, "unit advances toward enemy base")


func _test_lane_isolation() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.queue_spawn(BattleSim.ENEMY, 1, "swordsman")
	sim.tick()

	sim.units[0].x = 300.0
	sim.units[1].x = 305.0
	var hp_before: float = sim.units[0].hp + sim.units[1].hp
	for i in range(30):
		sim.tick()
	var hp_after: float = 0.0
	for u in sim.units:
		hp_after += u.hp
	_check(is_equal_approx(hp_before, hp_after), "different lanes do not fight")


func _test_melee_damage() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()

	sim.units[0].x = 300.0
	sim.units[1].x = 320.0
	var hp_before: float = sim.units[0].hp + sim.units[1].hp
	sim.tick()
	var hp_after: float = 0.0
	for u in sim.units:
		hp_after += u.hp
	_check(hp_after < hp_before, "melee attack deals damage")


func _test_ranged_projectile() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "archer")
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()

	sim.units[0].x = 300.0
	sim.units[1].x = 400.0
	var enemy_id: int = sim.units[1].id
	var hp_before: float = sim.units[1].hp
	sim.tick()
	_check(sim.projectiles.size() > 0, "archer spawns a projectile")

	for i in range(30):
		sim.tick()
	var enemy := sim.get_unit_by_id(enemy_id)
	_check(enemy == null or enemy.hp < hp_before, "projectile damages target")


func _test_damage_modifiers() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	var target: SimUnit = sim.units[0]

	_check(is_equal_approx(sim._damage_multiplier("melee", "armor_pierce", target), 1.25), "armor_pierce overrides heavy penalty")
	_check(is_equal_approx(sim._damage_multiplier("ranged", "", target), 0.7), "shield_wall reduces ranged damage")
	_check(is_equal_approx(sim._damage_multiplier("siege", "siege_master", target), 1.875), "siege_master multiplies heavy damage")


func _test_splash() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "mage")
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()

	sim.units[0].x = 300.0
	sim.units[1].x = 400.0
	sim.units[2].x = 410.0
	var id_a: int = sim.units[1].id
	var id_b: int = sim.units[2].id
	var hp_a: float = sim.units[1].hp
	var hp_b: float = sim.units[2].hp

	for i in range(40):
		sim.tick()

	var a := sim.get_unit_by_id(id_a)
	var b := sim.get_unit_by_id(id_b)
	_check(a == null or a.hp < hp_a, "mage splash damages primary target")
	_check(b == null or b.hp < hp_b, "mage splash damages nearby target")


func _test_base_damage_and_win() -> void:
	var sim := BattleSim.new(1, 3, 1, {}, false)
	for i in range(3):
		sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
		sim.tick()
		if sim.units.size() > 0:
			sim.units[0].x = sim.enemy_base_x - 1.0
		sim.tick()
		if sim.is_finished():
			break

	_check(sim.is_finished(), "battle finishes at base hp 0")
	_check(sim.winner == BattleSim.PLAYER, "player wins when enemy base reaches 0")
	_check(int(sim.base_hp[BattleSim.ENEMY]) == 0, "enemy base hp reaches 0")


func _test_economy() -> void:
	var level := {
		"starting_gold": 100,
		"base_income": 10.0,
		"mode": "defense",
		"waves": [],
	}
	var sim := BattleSim.new(1, 20, 1, level, true)

	sim.tick()
	_check(sim.gold > 100.0, "base income adds gold")

	var gold_before: float = sim.gold
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	_check(sim.gold < gold_before, "spawning a unit costs gold")
	_check(sim.get_pop_used() == 1, "spawning a unit uses population")
	_check(sim.spawn_cd[0].has("swordsman"), "spawning starts a cooldown")

	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	_check(sim.get_pop_used() == 1, "cooldown blocks immediate duplicate spawn")

	for i in range(42):
		sim.tick()
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	_check(sim.get_pop_used() == 2, "unit can be spawned after cooldown")


func _test_buildings() -> void:
	var level := {
		"starting_gold": 200,
		"base_income": 4.0,
		"available_buildings": ["farm", "barracks"],
		"waves": [],
	}
	var sim := BattleSim.new(1, 20, 1, level, true)

	sim.queue_build(0)
	sim.tick()
	_check(int(sim.buildings[0]["level"]) == 1, "farm can be built")
	_check(is_equal_approx(sim.income_per_sec, 6.0), "farm increases income")

	sim.queue_build(0)
	sim.tick()
	_check(int(sim.buildings[0]["level"]) == 2, "farm can be upgraded")
	_check(is_equal_approx(sim.income_per_sec, 7.0), "farm level 2 increases income")

	sim.queue_build(2)
	sim.tick()
	_check(int(sim.buildings[2]["level"]) == 1, "barracks can be built")
	_check(sim.pop_max == 14, "barracks increases population cap")
	_check(is_equal_approx(float(sim.lane_cd_mult[0]), 0.9), "barracks reduces that lane's cooldown")


func _test_kill_reward() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, true)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()

	var enemy: SimUnit = sim.units[1]
	var gold_before: float = sim.gold
	sim._apply_damage(enemy, 999.0, BattleSim.PLAYER)
	_check(sim.gold > gold_before, "killing an enemy grants gold")


func _test_waves() -> void:
	var level := {
		"mode": "defense",
		"base_hp": 5,
		"base_damage": 1,
		"starting_gold": 0,
		"base_income": 0.0,
		"waves": [
			{
				"time": 0.0,
				"lane": 0,
				"message": "W1",
				"spawns": [{"unit": "swordsman", "count": 2}],
			},
		],
	}
	var sim := BattleSim.new(1, 5, 1, level, true)
	sim.tick()
	_check(sim.wave_count == 1, "level reports one wave")
	_check(sim.next_wave_index == 1, "wave spawns at its time")
	_check(sim.units.size() == 2, "wave spawns the requested enemies")
	_check(sim.wave_message == "W1", "wave message is exposed")

	for u in sim.units:
		u.alive = false
	sim.tick()
	_check(sim.is_finished(), "defense level ends when all waves are cleared")
	_check(sim.winner == BattleSim.PLAYER, "clearing waves wins a defense level")


func _test_level_data() -> void:
	var level := _load_json("res://data/levels/level_01.json")
	_check(int(level.get("base_hp", 0)) == 20, "level 1 base hp is 20")
	_check(int(level.get("starting_gold", 0)) == 120, "level 1 starting gold is 120")
	_check(level.get("waves", []).size() == 4, "level 1 has four waves")


func _test_level_no_input() -> void:
	var level := _load_json("res://data/levels/level_01.json")
	var sim := BattleSim.new(12345, 20, 1, level, true)
	for i in range(440):
		sim.tick()

	var player_units := 0
	var enemy_units := 0
	for u in sim.units:
		if u.team == BattleSim.PLAYER:
			player_units += 1
		else:
			enemy_units += 1
	print("level1 no input: t=%.1f player=%d enemy=%d pop=%d gold=%.1f wave=%d" % [sim.elapsed, player_units, enemy_units, sim.get_pop_used(), sim.gold, sim.next_wave_index])
	_check(player_units == 0, "no player units spawn without input")
	_check(enemy_units > 0, "enemy wave exists at 22 seconds")


func _test_hud_input() -> void:
	var hud := BattleHUD.new()
	hud.size = Vector2(640, 360)
	root.add_child(hud)
	hud.snapshot = {
		"catalog": [
			{"id": "swordsman", "name": "Swordsman", "cost": 30, "pop": 1},
			{"id": "archer", "name": "Archer", "cost": 40, "pop": 1},
		],
		"cooldowns": [{}, {}],
		"buildings": [],
		"finished": false,
	}
	hud.active_lane = 0

	var spawned: Array = []
	hud.spawn_requested.connect(func(def_id: String) -> void: spawned.append(def_id))
	_click(hud, Vector2(40.0, 330.0))
	_check(spawned == ["swordsman"], "HUD card click requests spawn")

	var lanes: Array = []
	hud.lane_requested.connect(func(lane: int) -> void: lanes.append(lane))
	_click(hud, Vector2(590.0, 30.0))
	_check(lanes == [1], "HUD lane tab requests lane switch")

	var built: Array = []
	hud.build_requested.connect(func(slot: int) -> void: built.append(slot))
	_click(hud, Vector2(600.0, 330.0))
	_check(hud.panel_open, "HUD build button opens panel")
	_click(hud, Vector2(200.0, 110.0))
	_check(built == [0], "HUD building row requests build")

	hud.queue_free()


func _click(hud: BattleHUD, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	hud._gui_input(event)


func _test_determinism() -> void:
	var a := BattleSim.new(7, 20, 1, {}, false)
	var b := BattleSim.new(7, 20, 1, {}, false)

	for i in range(6):
		a.queue_spawn(BattleSim.PLAYER, i % 2, "swordsman")
		a.queue_spawn(BattleSim.ENEMY, (i + 1) % 2, "archer")
		b.queue_spawn(BattleSim.PLAYER, i % 2, "swordsman")
		b.queue_spawn(BattleSim.ENEMY, (i + 1) % 2, "archer")

	for i in range(200):
		a.tick()
		b.tick()

	_check(JSON.stringify(a.get_snapshot()) == JSON.stringify(b.get_snapshot()), "same seed and commands are deterministic")
