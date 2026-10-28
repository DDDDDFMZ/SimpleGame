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
	_test_autostart_battle()
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


func _test_spawn_and_advance() -> void:
	var sim := BattleSim.new(1, 20, 1)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	_check(sim.units.size() == 1, "spawn adds one unit")

	var start_x: float = sim.units[0].x
	sim.tick()
	_check(sim.units[0].x > start_x, "unit advances toward enemy base")


func _test_lane_isolation() -> void:
	var sim := BattleSim.new(1, 20, 1)
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
	var sim := BattleSim.new(1, 20, 1)
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
	var sim := BattleSim.new(1, 20, 1)
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
	var sim := BattleSim.new(1, 20, 1)
	sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	sim.tick()
	var target: SimUnit = sim.units[0]

	_check(is_equal_approx(sim._damage_multiplier("melee", "armor_pierce", target), 1.25), "armor_pierce overrides heavy penalty")
	_check(is_equal_approx(sim._damage_multiplier("ranged", "", target), 0.7), "shield_wall reduces ranged damage")
	_check(is_equal_approx(sim._damage_multiplier("siege", "siege_master", target), 1.875), "siege_master multiplies heavy damage")


func _test_splash() -> void:
	var sim := BattleSim.new(1, 20, 1)
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
	var sim := BattleSim.new(1, 3, 1)
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


func _test_autostart_battle() -> void:
	var sim := BattleSim.new(12345, 10, 5)
	for i in range(3):
		sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	for i in range(2):
		sim.queue_spawn(BattleSim.PLAYER, 1, "swordsman")
	for i in range(2):
		sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.queue_spawn(BattleSim.ENEMY, 1, "swordsman")

	var ticks := 0
	for i in range(1200):
		sim.tick()
		ticks += 1
		if sim.is_finished():
			break

	print("autostart: finished=%s winner=%d ticks=%d base=%s" % [sim.is_finished(), sim.winner, ticks, str(sim.base_hp)])
	_check(sim.is_finished(), "default M1 battle reaches a result")


func _test_determinism() -> void:
	var a := BattleSim.new(7, 20, 1)
	var b := BattleSim.new(7, 20, 1)

	for i in range(6):
		a.queue_spawn(BattleSim.PLAYER, i % 2, "swordsman")
		a.queue_spawn(BattleSim.ENEMY, (i + 1) % 2, "archer")
		b.queue_spawn(BattleSim.PLAYER, i % 2, "swordsman")
		b.queue_spawn(BattleSim.ENEMY, (i + 1) % 2, "archer")

	for i in range(200):
		a.tick()
		b.tick()

	_check(JSON.stringify(a.get_snapshot()) == JSON.stringify(b.get_snapshot()), "same seed and commands are deterministic")
