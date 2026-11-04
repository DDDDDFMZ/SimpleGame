extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_advance_line_snap()
	_test_manual_move_combat_priority()
	_test_base_gate_hold()
	_test_heal_and_backstab()
	_test_target_rewards()
	_test_reputation_and_guilds()
	_test_favor_bonus()
	_test_endless()
	_test_level_data()

	if failures == 0:
		print("M4 SIM TESTS PASS")
		quit(0)
	else:
		printerr("M4 SIM TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _test_advance_line_snap() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_set_advance_line(0, 700.0)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(300):
		sim.tick()
	var u: SimUnit = sim.units[0]
	var rally: Dictionary = sim.rallies["north"]
	_check(u.edge_id == String(rally["edge_id"]) and absf(u.edge_s - float(rally["s"])) < 20.0, "unit stops near the graph rally")
	var held := u.pos
	for i in range(20):
		sim.tick()
	_check(u.pos.distance_to(held) < 2.0, "unit does not oscillate at the rally")


func _test_manual_move_combat_priority() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_set_advance_line(0, 300.0)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(40):
		sim.tick()
	var u: SimUnit = sim.units[0]
	sim.queue_move_squad([u.id], Vector2(900.0, 450.0))
	for i in range(20):
		sim.tick()
	_check(u.pos.distance_to(Vector2(140.0, 450.0)) > 30.0, "manual move leaves the base")
	sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()
	_check(u.manual_order, "manual order survives combat state changes")


func _test_base_gate_hold() -> void:
	var level := {"mode": "defense", "base_hp": 20, "waves": []}
	var sim := BattleSim.new(1, 20, 1, level, false)
	sim.queue_set_rally(0, sim.map_data.node_pos(sim.base_nodes[BattleSim.ENEMY]))
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	for i in range(900):
		sim.tick()
	var u: SimUnit = sim.units[0]
	_check(u.pos.distance_to(sim.map_data.node_pos(sim.base_nodes[BattleSim.ENEMY])) < 22.0, "unit reaches enemy base node")
	_check(u.at_base, "defense unit holds at enemy base")


func _test_heal_and_backstab() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim.queue_spawn(BattleSim.PLAYER, 0, "cleric")
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	var cleric: SimUnit = sim.units[0]
	var tank: SimUnit = sim.units[1]
	cleric.pos = Vector2(300.0, 450.0)
	tank.pos = Vector2(310.0, 450.0)
	tank.hp = 40.0
	for i in range(3):
		sim.tick()
	_check(tank.hp > 40.0, "cleric heals a wounded ally")

	_check(is_equal_approx(sim._damage_multiplier("melee", "backstab", cleric), 2.25), "rogue backstab doubles melee-vs-light")


func _test_target_rewards() -> void:
	var level := {
		"mode": "defense",
		"base_hp": 20,
		"waves": [],
		"available_guilds": ["iron"],
	}
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron"]})
	sim.queue_guild_action("iron")
	sim.tick()
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman", false, true)
	sim.tick()
	var enemy: SimUnit = sim.units[1]
	enemy.hp = 1.0
	var gold_before := sim.gold
	sim._apply_damage(enemy, 999.0, BattleSim.PLAYER)
	_check(sim.target_kills == 1, "target kill increments target counter")
	_check(sim.fame == 1, "target kill grants fame")
	_check(sim.gold > gold_before, "target kill pays bounty")


func _test_reputation_and_guilds() -> void:
	var level := {
		"mode": "defense",
		"base_hp": 20,
		"waves": [],
		"available_guilds": ["iron", "verdant", "arcane"],
		"starting_gold": 500,
	}
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron", "verdant", "arcane"]})
	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 0, "contacting a guild opens tier 0")
	_check(sim._unit_unlocked("swordsman"), "tier 0 unlocks its class")
	_check(not sim._unit_unlocked("spearman"), "tier 1 class stays locked")

	sim.fame = 5
	sim.queue_promote()
	sim.tick()
	_check(sim.rep_rank == 1, "reputation promotion works with fame and gold")
	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 1, "tier 1 unlocks after contact")
	_check(sim._unit_unlocked("spearman"), "tier 1 class unlocks")

	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 2, "tier 2 unlocks at rank 1")
	_check(sim._unit_unlocked("knight"), "tier 2 class unlocks")

	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 2, "tier 3 blocked before rank 2")
	sim.fame = 10
	sim.queue_promote()
	sim.tick()
	sim.queue_guild_action("iron")
	sim.tick()
	_check(int(sim.guild_tier["iron"]) == 3, "tier 3 unlocks at rank 2")


func _test_favor_bonus() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false, {"guild_favor": {"iron": 10}})
	var normal := sim._effective_def("swordsman")
	var base: Dictionary = sim.unit_defs["swordsman"]
	_check(float(normal["hp"]) > float(base["hp"]), "favor increases HP")
	_check(int(normal["cost"]) < int(base["cost"]), "favor reduces cost")


func _test_endless() -> void:
	var level := {
		"mode": "endless",
		"base_hp": 20,
		"base_damage": 1,
		"starting_gold": 180,
		"stipend": 3.0,
		"available_guilds": ["iron", "verdant", "arcane"],
		"waves": [],
	}
	var sim := BattleSim.new(1, 20, 1, level, true, {"unlocked_guilds": ["iron", "verdant", "arcane"]})
	for i in range(500):
		sim.tick()
	_check(sim.endless_wave >= 1, "endless spawns its first wave")
	_check(sim.endless_mode, "endless mode flag is set")


func _test_level_data() -> void:
	for path in ["res://data/levels/level_01.json", "res://data/levels/level_02.json", "res://data/levels/level_03.json"]:
		var level := _load_json(path)
		_check(level.has("contract") and level.has("brief"), path.get_file() + " has contract/brief")
		_check(level.get("available_guilds", []).size() > 0, path.get_file() + " has available guilds")
		var targets := 0
		for wave in level.get("waves", []):
			for spawn in wave.get("spawns", []):
				if bool(spawn.get("target", false)):
					targets += int(spawn.get("count", 1))
		_check(targets >= 3, path.get_file() + " has target enemies")


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
