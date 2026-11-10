extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_unlimited_path_and_rows()
	_test_station_order()
	if failures == 0:
		print("M7 PATH TESTS PASS")
		quit(0)
	else:
		printerr("M7 PATH TESTS FAIL: %d" % failures)
		quit(1)


func _test_unlimited_path_and_rows() -> void:
	var sim := BattleSim.new(1, 20, 1, {}, false)
	for i in range(12):
		sim._spawn_unit(BattleSim.PLAYER, 0, "swordsman")
	for i in range(400):
		sim.tick()
	var lanes := sim.map_data.edge_slot_count("p_jn", sim.edge_slot_width, sim.edge_slot_padding)
	var on_edge := 0
	var waiting := 0
	var rows := {}
	for u in sim.units:
		if u.edge_id == "p_jn":
			on_edge += 1
			var row_s := snappedf(u.edge_s, 0.5)
			if not rows.has(row_s):
				rows[row_s] = []
			(rows[row_s] as Array).append(u)
		if u.waiting:
			waiting += 1
	_check(on_edge == 12, "a path holds more units than one row's width")
	_check(on_edge > lanes, "path total capacity is not limited by lane count")
	_check(waiting == 0, "units never enter the node queue for path width")
	_check(rows.size() >= 2, "overflow units form additional rows")
	for row_s in rows:
		_check((rows[row_s] as Array).size() <= lanes, "each row respects the road-width lane limit")
	var used_slots := {}
	for u in sim.units:
		used_slots[u.station_slot] = true
	_check(used_slots.size() == 12, "station slots are unique per route")


func _test_station_order() -> void:
	var sim := BattleSim.new(2, 20, 1, {}, false)
	sim.set_station_order(["archer", "cleric", "swordsman", "spearman", "rogue", "knight", "mage", "catapult"])
	_check(sim.station_rank_by_id["cleric"] == 1, "station order updates ranks")
	sim.set_station_order(["cleric", "archer", "swordsman", "spearman", "rogue", "knight", "mage", "catapult"])
	_check(sim.station_rank_by_id["cleric"] == 0, "custom station order updates ranks")
	_check(sim.station_rank_by_id["archer"] == 1, "custom station order preserves order")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
