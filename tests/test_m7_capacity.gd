extends SceneTree

var failures := 0


func _initialize() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	for i in range(8):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(8):
		sim.tick()
	var on_edge := 0
	var waiting := 0
	for u in sim.units:
		if u.edge_id == "p_jn":
			on_edge += 1
		if u.waiting:
			waiting += 1
	_check(on_edge <= sim.map_data.edge_slot_count("p_jn", sim.edge_slot_width, sim.edge_slot_padding), "edge capacity limits units")
	_check(waiting > 0, "overflow units wait at the base node")

	# Free one slot and make sure the queued archer enters before the queued cleric.
	sim.set_station_order(["archer", "cleric", "swordsman", "spearman", "rogue", "knight", "mage", "catapult"])
	sim._spawn_unit(BattleSim.PLAYER, 0, "archer")
	sim._spawn_unit(BattleSim.PLAYER, 0, "cleric")
	for i in range(2):
		sim.tick()
	var archer: SimUnit = null
	var cleric: SimUnit = null
	for u in sim.units:
		if u.def_id == "archer":
			archer = u
		elif u.def_id == "cleric":
			cleric = u
	_check(archer != null and cleric != null, "queued test units exist")
	var victim: SimUnit = null
	for u in sim.units:
		if u.edge_id == "p_jn" and u.def_id == "swordsman":
			victim = u
			break
	_check(victim != null, "an occupying unit exists")
	if victim != null:
		sim._apply_damage(victim, 9999.0, BattleSim.ENEMY)
		sim._process_all_queues()
		var archer_in := archer.edge_id == "p_jn"
		var cleric_in := cleric.edge_id == "p_jn"
		_check(archer_in and not cleric_in, "station order lets the front class enter first")

	var custom := ["cleric", "archer", "swordsman", "spearman", "rogue", "knight", "mage", "catapult"]
	sim.set_station_order(custom)
	_check(sim.station_rank_by_id["cleric"] == 0, "custom station order updates ranks")
	_check(sim.station_rank_by_id["archer"] == 1, "custom station order preserves order")

	_test_shared_slots_between_teams()

	if failures == 0:
		print("M7 CAPACITY TESTS PASS")
		quit(0)
	else:
		printerr("M7 CAPACITY TESTS FAIL: %d" % failures)
		quit(1)


func _test_shared_slots_between_teams() -> void:
	var sim := BattleSim.new(2, 20, 1, {}, false)
	for i in range(8):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(12):
		sim.tick()
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	var enemy: SimUnit = sim.units[sim.units.size() - 1]
	# Place the enemy at the far junction so both teams contend for p_jn
	# without triggering a base-leak resolution.
	enemy.node_id = "j_north"
	enemy.edge_id = ""
	enemy.forced_entry = "p_jn"
	enemy.route_id = "enemy_north"
	enemy.path = []
	enemy.goal_dirty = true
	enemy.set_position(sim.map_data.node_pos("j_north"))
	sim.tick()
	_check(enemy.waiting, "enemy queues when shared edge slots are full")

	var killed := 0
	for u in sim.units:
		if killed >= 3:
			break
		if u.team == BattleSim.PLAYER and u.edge_id == "p_jn":
			sim._apply_damage(u, 9999.0, BattleSim.ENEMY)
			killed += 1
	sim._cleanup_dead()
	sim._process_all_queues()
	_check(enemy.edge_id == "p_jn" and not enemy.waiting, "enemy enters freed shared slot")

	var slots := {}
	var unique := true
	for u in sim.units:
		if u.alive and u.edge_id == "p_jn":
			if slots.has(u.edge_slot):
				unique = false
			slots[u.edge_slot] = true
	_check(unique, "both teams occupy unique shared slots")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
