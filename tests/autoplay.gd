extends SceneTree

const LEVELS := [
	"res://data/levels/level_01.json",
	"res://data/levels/level_02.json",
	"res://data/levels/level_03.json",
]


func _initialize() -> void:
	var all_won := true
	for path in LEVELS:
		var level := _load_json(path)
		var result := _run_level(level)
		print("%s: finished=%s winner=%d t=%.1f base=%s wave=%d/%d gold=%.1f pop=%d/%d" % [
			path.get_file(), result["finished"], result["winner"], result["elapsed"],
			str(result["base"]), result["wave"], result["wave_count"], result["gold"],
			result["pop"], result["pop_max"],
		])
		if not result["finished"] or result["winner"] != BattleSim.PLAYER:
			all_won = false
	quit(0 if all_won else 1)


func _run_level(level: Dictionary) -> Dictionary:
	var sim := BattleSim.new(12345, 20, 1, level, true)
	var line_x := 700.0
	var stall_ticks := 0
	var last_enemy_count := 0
	var last_wave := -1
	sim.queue_set_advance_line(0, line_x)
	sim.queue_set_advance_line(1, line_x)

	for i in range(9000):
		var t := sim.elapsed
		if sim.next_wave_index != last_wave:
			last_wave = sim.next_wave_index
			print("  wave %d/%d at t=%.1f base=%s" % [last_wave, sim.wave_count, t, str(sim.base_hp)])
		var enemy_count := 0
		for u in sim.units:
			if u.alive and u.team == BattleSim.ENEMY:
				enemy_count += 1
		if enemy_count > 0 and enemy_count == last_enemy_count:
			stall_ticks += 1
		else:
			stall_ticks = 0
		last_enemy_count = enemy_count
		if stall_ticks > 100 and line_x < 1400.0:
			line_x += 150.0
			sim.queue_set_advance_line(0, line_x)
			sim.queue_set_advance_line(1, line_x)
			stall_ticks = 0
		if t >= 1.0 and int(sim.buildings[0]["level"]) == 0:
			sim.queue_build(0)
		if t >= 5.0 and int(sim.buildings[2]["level"]) == 0:
			sim.queue_build(2)
		if t >= 10.0 and int(sim.buildings[1]["level"]) == 0:
			sim.queue_build(1)
		if t >= 20.0 and int(sim.buildings[3]["level"]) == 0:
			sim.queue_build(3)
		if t >= 30.0 and int(sim.buildings[0]["level"]) == 1:
			sim.queue_build(0)
		if t >= 40.0 and int(sim.buildings[1]["level"]) == 1:
			sim.queue_build(1)
		if t >= 50.0 and int(sim.buildings[2]["level"]) == 1:
			sim.queue_build(2)
		if t >= 60.0 and int(sim.buildings[3]["level"]) == 1:
			sim.queue_build(3)

		# Keep every lane busy; the sim's gold/pop/cooldown checks throttle this.
		sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
		sim.queue_spawn(BattleSim.PLAYER, 0, "archer")
		sim.queue_spawn(BattleSim.PLAYER, 1, "swordsman")
		sim.queue_spawn(BattleSim.PLAYER, 1, "archer")
		sim.queue_spawn(BattleSim.PLAYER, 0, "mage")
		sim.queue_spawn(BattleSim.PLAYER, 1, "mage")

		sim.tick()
		if sim.is_finished():
			break

	if not sim.is_finished():
		print("DEBUG alive units:")
		for u in sim.units:
			print("  team=%d lane=%d x=%.1f state=%s hold=%s manual=%s target=%d hp=%.1f" % [u.team, u.lane, u.x, u.state, str(u.hold_position), str(u.manual_order), u.target_id, u.hp])
		print("  projectiles=%d" % sim.projectiles.size())

	return {
		"finished": sim.is_finished(),
		"winner": sim.winner,
		"elapsed": sim.elapsed,
		"base": sim.base_hp.duplicate(),
		"wave": sim.next_wave_index,
		"wave_count": sim.wave_count,
		"gold": sim.gold,
		"pop": sim.get_pop_used(),
		"pop_max": sim.pop_max,
	}


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
