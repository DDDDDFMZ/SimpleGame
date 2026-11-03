extends SceneTree

const LEVELS := [
	{"path": "res://data/levels/level_01.json", "guilds": ["iron"]},
	{"path": "res://data/levels/level_02.json", "guilds": ["iron", "verdant"]},
	{"path": "res://data/levels/level_03.json", "guilds": ["iron", "verdant", "arcane"]},
]
const SPAM := ["archer", "mage", "swordsman", "spearman", "rogue", "cleric", "knight", "catapult"]


func _initialize() -> void:
	var all_won := true
	for entry in LEVELS:
		var level := _load_json(String(entry["path"]))
		var result := _run_level(level, entry["guilds"])
		print("%s: finished=%s winner=%d t=%.1f base=%s wave=%d/%d gold=%.1f cap=%d/%d" % [
			String(entry["path"]).get_file(), result["finished"], result["winner"], result["elapsed"],
			str(result["base"]), result["wave"], result["wave_count"], result["gold"],
			result["pop"], result["pop_max"],
		])
		if not result["finished"] or result["winner"] != BattleSim.PLAYER:
			all_won = false

	var endless_level := {
		"mode": "endless",
		"base_hp": 20,
		"base_damage": 1,
		"starting_gold": 180,
		"stipend": 3.0,
		"available_guilds": ["iron", "verdant", "arcane"],
		"waves": [],
	}
	var endless := _run_level(endless_level, ["iron", "verdant", "arcane"])
	print("endless: waves=%d finished=%s winner=%d base=%s score=%d" % [
		endless["endless_wave"], endless["finished"], endless["winner"], str(endless["base"]), endless["score"],
	])
	if int(endless["endless_wave"]) < 10:
		all_won = false
	quit(0 if all_won else 1)


func _run_level(level: Dictionary, guilds: Array) -> Dictionary:
	var sim := BattleSim.new(12345, 20, 1, level, true, {"unlocked_guilds": guilds})
	var lines_set := false

	for i in range(18000):
		var route_count := sim.player_spawns.size()
		var use_routes := mini(route_count, 2)
		if not lines_set:
			for route_index in range(use_routes):
				sim.queue_set_advance_line(route_index, 800.0)
			lines_set = true

		# Establish cheap contacts first; only expand when the war chest is healthy.
		for guild_id in guilds:
			if int(sim.guild_tier.get(String(guild_id), -1)) < 0:
				sim.queue_guild_action(String(guild_id))
		if sim.gold > 60.0:
			for guild_id in guilds:
				if int(sim.guild_tier.get(String(guild_id), -1)) < 2:
					sim.queue_guild_action(String(guild_id))
					break
		if sim.rep_rank < sim.promo_kills.size() and sim.gold > 120.0 and sim.fame >= int(sim.promo_kills[sim.rep_rank]):
			sim.queue_promote()

		for def_id in SPAM:
			for route_index in range(use_routes):
				sim.queue_spawn(BattleSim.PLAYER, route_index, String(def_id))
		sim.tick()
		if sim.is_finished():
			break

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
		"endless_wave": sim.endless_wave,
		"score": sim.score if sim.endless_mode else 0,
	}


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
