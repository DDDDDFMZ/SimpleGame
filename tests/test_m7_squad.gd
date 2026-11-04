extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_mixed_speed_and_slots()
	_test_cross_route_groups()
	_test_new_order_clears_queue_and_hold_dissolves()
	_test_retaliation_and_ranged_assist()
	_test_leader_promotion()
	_test_formation_spacing_and_reverse()
	_test_member_death_updates_speed_cap()
	if failures == 0:
		print("M7 SQUAD TESTS PASS")
		quit(0)
	else:
		printerr("M7 SQUAD TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _test_mixed_speed_and_slots() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "rogue")
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.PLAYER, 0, "catapult")
	for i in range(8):
		sim.tick()
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 280.0))
	sim.tick()
	var squad: Dictionary = sim.squads.values()[0] if not sim.squads.is_empty() else {}
	_check(not squad.is_empty(), "squad created")
	_check(is_equal_approx(float(squad.get("speed_cap", 0.0)), 30.0), "squad speed capped to slowest member")
	var target_s: Array = []
	for u in sim.units:
		_check(u.squad_id == int(squad.get("id", -1)), "all selected units join the squad")
		target_s.append(u.target_edge_s)
		_check(u.move_speed_cap <= u.speed, "member speed cap never exceeds base speed")
	target_s.sort()
	_check(target_s.size() == 3, "squad has three members")
	# Slots are unique while sharing the same edge.
	var slot_values: Array = []
	for u in sim.units:
		if u.edge_id == "p_jn":
			_check(not slot_values.has(u.edge_slot), "shared edge slot is unique")
			slot_values.append(u.edge_slot)
	_check(not slot_values.is_empty(), "units use shared collision slots")


func _test_cross_route_groups() -> void:
	var sim := BattleSim.new(2, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.PLAYER, 1, "archer")
	for i in range(5):
		sim.tick()
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 450.0))
	sim.tick()
	_check(sim.squads.size() == 2, "cross-route selection creates independent route subgroups")
	var routes := {}
	for squad in sim.squads.values():
		routes[String(squad.get("route_id", ""))] = true
	_check(routes.has("north") and routes.has("south"), "subgroups keep their route ids")


func _test_new_order_clears_queue_and_hold_dissolves() -> void:
	var sim := BattleSim.new(3, 20, 1, {}, false)
	for i in range(8):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(6):
		sim.tick()
	var waiting_before := 0
	for u in sim.units:
		if u.waiting:
			waiting_before += 1
	_check(waiting_before > 0, "some units are waiting before re-order")
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 280.0))
	sim.tick()
	var stale_wait := 0
	for u in sim.units:
		if u.waiting and (not u.manual_order or u.target_edge_id == ""):
			stale_wait += 1
	_check(stale_wait == 0, "new move replaces stale node waits with the new target")
	sim.queue_hold_squad(ids)
	sim.tick()
	var squad_members := 0
	for u in sim.units:
		if u.squad_id >= 0:
			squad_members += 1
	_check(squad_members == 0, "hold dissolves squad membership")


func _test_retaliation_and_ranged_assist() -> void:
	var sim := BattleSim.new(4, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.PLAYER, 0, "archer")
	sim._spawn_unit(BattleSim.ENEMY, 0, "swordsman")
	sim.tick()
	var tank: SimUnit = sim.units[0]
	var ranged: SimUnit = sim.units[1]
	var enemy: SimUnit = sim.units[2]
	tank.edge_id = "p_jn"
	tank.edge_s = 200.0
	tank.set_position(sim.map_graph.edge_point("p_jn", 200.0))
	ranged.edge_id = "p_jn"
	ranged.edge_s = 150.0
	ranged.set_position(sim.map_graph.edge_point("p_jn", 150.0))
	enemy.edge_id = "p_jn"
	enemy.edge_s = 220.0
	enemy.set_position(sim.map_graph.edge_point("p_jn", 220.0))
	enemy.hp = 9999.0
	sim._apply_damage(tank, 5.0, BattleSim.ENEMY, enemy.id)
	var tank_target := sim._find_target(tank)
	var ranged_target := sim._find_target(ranged)
	_check(tank_target != null and tank_target.id == enemy.id, "melee retaliates against its attacker")
	_check(ranged_target != null and ranged_target.id == enemy.id, "nearby ranged assists against attacker")


func _test_leader_promotion() -> void:
	var sim := BattleSim.new(5, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.PLAYER, 0, "archer")
	for i in range(5):
		sim.tick()
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 280.0))
	sim.tick()
	var squad: Dictionary = sim.squads.values()[0]
	var old_leader := int(squad.get("leader_id", -1))
	var leader_unit := sim._unit_by_id(old_leader)
	if leader_unit != null:
		sim._apply_damage(leader_unit, 99999.0, BattleSim.ENEMY)
		sim.tick()
	var new_leader := -1
	if not sim.squads.is_empty():
		new_leader = int(sim.squads.values()[0].get("leader_id", -1))
	_check(new_leader != old_leader and new_leader >= 0, "squad promotes a new leader after leader death")


func _test_formation_spacing_and_reverse() -> void:
	var sim := BattleSim.new(6, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "rogue")
	sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	sim._spawn_unit(BattleSim.PLAYER, 0, "catapult")
	for i in range(8):
		sim.tick()
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 280.0))
	for i in range(90):
		sim.tick()
	var squad: Dictionary = sim.squads.values()[0]
	var members: Array = []
	for id in squad.get("member_ids", []):
		var u := sim._unit_by_id(int(id))
		if u != null:
			members.append(u)
	members.sort_custom(func(a: SimUnit, b: SimUnit) -> bool: return a.squad_rank < b.squad_rank)
	_check(members.size() == 3, "formation keeps all members")
	_check(is_equal_approx(float(squad.get("speed_cap", 0.0)), 30.0), "formation speed cap tracks slowest member")
	var leader: SimUnit = members[0]
	var same_edge := leader.edge_id != ""
	for i in range(1, members.size()):
		var u: SimUnit = members[i]
		if u.edge_id != leader.edge_id:
			same_edge = false
			continue
		_check(u.edge_s <= leader.edge_s + 0.6, "follower cannot overtake the leader")
	if same_edge:
		var gap_one := leader.edge_s - (members[1] as SimUnit).edge_s
		var gap_two := (members[1] as SimUnit).edge_s - (members[2] as SimUnit).edge_s
		_check(gap_one >= 8.0, "first follower keeps formation spacing")
		_check(gap_two >= 8.0, "second follower keeps formation spacing")
		# A far-behind tail makes the leader wait instead of running away.
		var tail: SimUnit = members[2]
		tail.edge_s = maxf(0.0, tail.edge_s - 220.0)
		tail.set_position(sim.map_graph.edge_point(tail.edge_id, tail.edge_s))
		sim.tick()
		_check(leader.squad_wait or String(sim.squads.values()[0].get("state", "")) == "waiting", "leader waits for a far-behind tail")
	# A new order behind the column must reverse the squad instead of walking on.
	var leader_before := leader.edge_s
	sim.queue_move_squad(ids, Vector2(220.0, 430.0))
	for i in range(15):
		sim.tick()
	var new_squad: Dictionary = sim.squads.values()[0]
	var new_members: Array = []
	for id in new_squad.get("member_ids", []):
		var u := sim._unit_by_id(int(id))
		if u != null:
			new_members.append(u)
	new_members.sort_custom(func(a: SimUnit, b: SimUnit) -> bool: return a.squad_rank < b.squad_rank)
	var rear_leader: SimUnit = new_members[0]
	if rear_leader.edge_id == leader.edge_id:
		_check(rear_leader.edge_s < leader_before, "squad reverses toward a destination behind it")
	else:
		_check(rear_leader.edge_id != "", "squad stays on the road while reversing")


func _test_member_death_updates_speed_cap() -> void:
	var sim := BattleSim.new(7, 20, 1, {}, false)
	sim._spawn_unit(BattleSim.PLAYER, 0, "rogue")
	sim._spawn_unit(BattleSim.PLAYER, 0, "catapult")
	for i in range(8):
		sim.tick()
	var ids: Array = []
	for u in sim.units:
		ids.append(u.id)
	sim.queue_move_squad(ids, Vector2(760.0, 280.0))
	sim.tick()
	var squad: Dictionary = sim.squads.values()[0]
	_check(is_equal_approx(float(squad.get("speed_cap", 0.0)), 30.0), "slow member caps the squad")
	var slow: SimUnit = null
	for id in squad.get("member_ids", []):
		var u := sim._unit_by_id(int(id))
		if u != null and is_equal_approx(u.speed, 30.0):
			slow = u
			break
	if slow != null:
		sim._apply_damage(slow, 99999.0, BattleSim.ENEMY)
		sim.tick()
	var remaining: Dictionary = sim.squads.values()[0]
	_check(is_equal_approx(float(remaining.get("speed_cap", 0.0)), 90.0), "speed cap rises after the slow member dies")
