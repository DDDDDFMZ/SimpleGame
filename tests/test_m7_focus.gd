extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_target_range()
	_test_transitive_threat()
	_test_move_priority()
	_test_reverse_to_other_edge()
	_test_rally_retarget()
	_test_squad_arrival_line()
	_test_lateral_formation()
	if failures == 0:
		print("M7 FOCUS TESTS PASS")
		quit(0)
	else:
		printerr("M7 FOCUS TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _place_edge(u: SimUnit, sim: BattleSim, edge_id: String, s: float) -> void:
	u.edge_id = edge_id
	u.edge_s = s
	u.node_id = ""
	u.edge_dir = 1
	u.set_position(sim.map_graph.edge_point(edge_id, s))


func _test_target_range() -> void:
	var sim := BattleSim.new(11, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "archer")
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	var archer: SimUnit = sim.units[0]
	var enemy: SimUnit = sim.units[1]
	_place_edge(archer, sim, "p_jn", 100.0)
	_place_edge(enemy, sim, "p_jn", 280.0)
	sim._build_combat_clusters()
	_check(sim._find_target(archer) != null, "target within 120% range is acquired")
	_place_edge(enemy, sim, "p_jn", 360.0)
	sim._build_combat_clusters()
	_check(sim._find_target(archer) == null, "target beyond 120% range is not chased")


func _test_transitive_threat() -> void:
	var sim := BattleSim.new(12, 20, 1, {}, false)
	for def_id in ["catapult", "swordsman", "swordsman"]:
		sim._spawn_unit(BattleSim.PLAYER, 0, def_id)
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	var a: SimUnit = sim.units[0]
	var b: SimUnit = sim.units[1]
	var c: SimUnit = sim.units[2]
	var nearest: SimUnit = sim.units[3]
	var attacker: SimUnit = sim.units[4]
	a.pos = Vector2(200.0, 450.0)
	b.pos = Vector2(340.0, 450.0)
	c.pos = Vector2(460.0, 450.0)
	nearest.pos = Vector2(300.0, 450.0)
	attacker.pos = Vector2(380.0, 450.0)
	sim._apply_damage(c, 1.0, BattleSim.ENEMY, attacker.id)
	sim._build_combat_clusters()
	_check(a.cluster_id == c.cluster_id, "nearby allies link transitively")
	var target := sim._find_target(a)
	_check(target != null and target.id == attacker.id, "transitive attacker sharing overrides a nearer idle enemy")


func _test_move_priority() -> void:
	var sim := BattleSim.new(13, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	var player: SimUnit = sim.units[0]
	var enemy: SimUnit = sim.units[1]
	_place_edge(player, sim, "p_jn", 300.0)
	_place_edge(enemy, sim, "p_jn", 305.0)
	player.hp = 9999.0
	enemy.hp = 9999.0
	enemy.damage = 0.0
	sim.queue_move_squad([player.id], sim.map_graph.edge_point("p_jn", 100.0))
	for i in range(20):
		sim.tick()
	_check(player.move_priority, "manual move keeps move priority while travelling")
	_check(player.edge_s < 280.0, "move priority overrides attack-in-range stopping")
	for i in range(300):
		sim.tick()
		if not player.move_priority:
			break
	_check(not player.move_priority, "move priority clears on arrival")


func _test_reverse_to_other_edge() -> void:
	var sim := BattleSim.new(21, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	var unit: SimUnit = sim.units[0]
	_place_edge(unit, sim, "p_jn", 300.0)
	unit.edge_dir = 1
	sim.queue_move_squad([unit.id], sim.map_graph.edge_point("p_js", 100.0))
	sim.tick()
	_check(unit.edge_dir == -1, "manual move behind the column reverses along the current edge")
	for i in range(10):
		sim.tick()
	_check(unit.edge_s < 290.0, "reversed unit makes progress toward the near node")


func _test_rally_retarget() -> void:
	var sim := BattleSim.new(22, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(30):
		sim.tick()
	var unit: SimUnit = sim.units[0]
	_check(unit.edge_id == "p_jn" and unit.edge_s < 70.0, "unit holds at the default rally first")
	sim.queue_set_advance_line(0, 500.0)
	for i in range(200):
		sim.tick()
	_check(absf(unit.edge_s - float(sim.rallies["north"]["s"])) < 3.0, "rally change retargets units already on the edge")


func _test_squad_arrival_line() -> void:
	var sim := BattleSim.new(19, 20, 1, {}, false)
	for i in range(3):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(3):
		_place_edge(sim.units[i], sim, "p_jn", 200.0 + float(i) * 10.0)
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, sim.map_graph.edge_point("p_jn", 260.0))
	for i in range(160):
		sim.tick()
		if not sim.squads.is_empty() and bool(sim.squads.values()[0].get("arrived", false)):
			break
	_check(not sim.squads.is_empty(), "arrived squad still exists")
	if not sim.squads.is_empty():
		var squad: Dictionary = sim.squads.values()[0]
		_check(bool(squad.get("arrived", false)), "squad marks arrival")
		_check(not bool(squad.get("move_priority", false)), "squad clears move priority on arrival")
		var targets_ok := true
		for id in squad.get("member_ids", []):
			var member := sim._unit_by_id(int(id))
			if member == null or absf(member.target_edge_s - 260.0) > 0.1:
				targets_ok = false
		_check(targets_ok, "squad members share the final line target")
	for i in range(120):
		sim.tick()
	var laterals := {}
	for u in sim.units:
		if absf(u.edge_s - 260.0) < 1.5:
			laterals[snappedf(u.lateral_target, 0.1)] = true
	_check(laterals.size() == 3, "arrived squad spreads into a line across the road")


func _test_lateral_formation() -> void:
	var sim := BattleSim.new(16, 20, 1, {}, false)
	for i in range(3):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for u in sim.units:
		_place_edge(u, sim, "p_jn", 100.0)
	sim._update_lateral_positions(2.0)
	var targets := {}
	for u in sim.units:
		targets[snappedf(u.lateral_target, 0.1)] = true
	_check(targets.size() == 3, "three overlapping allies get distinct lateral slots")
	_check(targets.has(-13.0) and targets.has(0.0) and targets.has(13.0), "lateral slots center on the road")

	var single := BattleSim.new(17, 20, 1, {}, false)
	single._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	var solo: SimUnit = single.units[0]
	_place_edge(solo, single, "p_jn", 100.0)
	single._update_lateral_positions(2.0)
	_check(absf(solo.lateral_target) < 0.01, "a lone unit defaults to the road centerline")

	var mixed := BattleSim.new(18, 20, 1, {}, false)
	mixed._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	mixed._spawn_unit(BattleSim.PLAYER, 0, "archer")
	mixed._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	mixed._spawn_unit(BattleSim.ENEMY, 0, "archer")
	for u in mixed.units:
		_place_edge(u, mixed, "p_jn", 100.0)
		u.edge_dir = 1
	mixed._update_lateral_positions(2.0)
	for team in [BattleSim.PLAYER, BattleSim.ENEMY]:
		var negative := false
		var positive := false
		for u in mixed.units:
			if u.team == team:
				negative = negative or u.lateral_target < 0.0
				positive = positive or u.lateral_target > 0.0
		_check(negative and positive, "one-direction units spread around center without yielding to the enemy")

	var opposing := BattleSim.new(23, 20, 1, {}, false)
	opposing._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	opposing._spawn_unit(BattleSim.PLAYER, 0, "archer")
	var first: SimUnit = opposing.units[0]
	var second: SimUnit = opposing.units[1]
	_place_edge(first, opposing, "p_jn", 100.0)
	_place_edge(second, opposing, "p_jn", 100.0)
	first.edge_dir = 1
	second.edge_dir = -1
	opposing._update_lateral_positions(2.0)
	_check(first.lateral_target * second.lateral_target < 0.0, "friendly opposite directions yield to opposite sides")
