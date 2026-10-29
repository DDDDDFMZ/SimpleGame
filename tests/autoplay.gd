extends SceneTree


func _initialize() -> void:
	var level := _load_json("res://data/levels/level_01.json")
	var sim := BattleSim.new(12345, 20, 1, level, true)

	var built := {0: false, 1: false, 2: false, 3: false}
	var upgraded := {0: false, 1: false}

	for i in range(6000):
		var t := sim.elapsed
		if t >= 1.0 and not built[0]:
			sim.queue_build(0)
			built[0] = true
		if t >= 5.0 and not built[2]:
			sim.queue_build(2)
			built[2] = true
		if t >= 10.0 and not built[1]:
			sim.queue_build(1)
			built[1] = true
		if t >= 20.0 and not built[3]:
			sim.queue_build(3)
			built[3] = true
		if t >= 30.0 and not upgraded[0]:
			sim.queue_build(0)
			upgraded[0] = true
		if t >= 40.0 and not upgraded[1]:
			sim.queue_build(1)
			upgraded[1] = true

		if i % 40 == 0:
			sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
		if i % 60 == 0:
			sim.queue_spawn(BattleSim.PLAYER, 0, "archer")
		if i % 80 == 0:
			sim.queue_spawn(BattleSim.PLAYER, 1, "spearman")
		if i % 100 == 0:
			sim.queue_spawn(BattleSim.PLAYER, 1, "archer")
		if i % 120 == 0:
			sim.queue_spawn(BattleSim.PLAYER, 0, "mage")

		sim.tick()
		if sim.is_finished():
			break

	print("autoplay: finished=%s winner=%d t=%.1f base=%s wave=%d/%d gold=%.1f pop=%d/%d" % [
		sim.is_finished(), sim.winner, sim.elapsed, str(sim.base_hp), sim.next_wave_index, sim.wave_count, sim.gold, sim.get_pop_used(), sim.pop_max
	])
	quit(0 if sim.is_finished() and sim.winner == BattleSim.PLAYER else 1)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
