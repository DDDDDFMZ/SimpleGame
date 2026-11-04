class_name BattleSim
extends RefCounted

const PLAYER := 0
const ENEMY := 1
const TICK_DT := 0.05
const TICK_HZ := 20.0
const SQUAD_TRAIL_STEP := 2.0
const SQUAD_TRAIL_KEEP := 1200.0
const SQUAD_WAIT_LIMIT := 2.5

var seed: int = 1
var rng := RandomNumberGenerator.new()
var tick_count: int = 0
var elapsed: float = 0.0

var units: Array = []
var projectiles: Array = []
var commands: Array = []
var data: GameData
var unit_defs: Dictionary = {}
var guild_defs: Dictionary = {}
var unit_order: Array = []
var guild_order: Array = []
var promo_kills: Array = [1, 3, 5]
var promo_cost: Array = [40, 80, 120]
var counter_matrix: Dictionary = {}
var next_id: int = 1
var next_projectile_id: int = 1

var map_data: MapData
var map_graph: MapGraph
var map_snapshot: Dictionary = {}
var world_width: float = 1600.0
var world_height: float = 900.0
var player_spawns: Array = []
var enemy_spawns: Array = []
var base_nodes: Array = ["", ""]
var base_hp: Array = [20, 20]
var base_hp_max: int = 20
var base_damage: int = 1
var rallies: Dictionary = {}
var edge_slots: Dictionary = {}
var node_queues: Dictionary = {}
var station_order: Array = []
var station_rank_by_id: Dictionary = {}
var edge_slot_width: float = 14.0
var edge_slot_padding: float = 1.0
var station_spacing: float = 16.0
var squad_slot_tolerance: float = 3.0
var squad_regroup_distance: float = 80.0
var assist_radius: float = 150.0
var vision_radius: float = 180.0
var squads: Dictionary = {}
var next_squad_id: int = 1

var gold: float = 150.0
var stipend: float = 2.5
var pop_max: int = 8
var spawn_cd: Dictionary = {}

var fame: int = 0
var target_kills: int = 0
var target_total: int = 0
var target_leaks: int = 0
var leaks_by_unit: Dictionary = {}
var leaks_by_route: Dictionary = {}
var leaks_by_edge: Dictionary = {}
var leaks_by_wave: Dictionary = {}
var gold_spent_units: int = 0
var gold_spent_guilds: int = 0
var gold_spent_promote: int = 0
var rep_rank: int = 0
var guild_tier: Dictionary = {}
var guild_usage: Dictionary = {}
var meta_unlocked_guilds: Array = []
var guild_favor: Dictionary = {}
var level_available_guilds: Array = []

var level: Dictionary = {}
var waves: Array = []
var next_wave_index: int = 0
var wave_count: int = 0
var wave_message: String = ""
var message_timer: float = 0.0
var last_error: String = ""
var error_timer: float = 0.0
var defense_mode: bool = false
var endless_mode: bool = false
var economy_enabled: bool = true
var endless_wave: int = 0
var endless_timer: float = 10.0
var kills: int = 0
var score: int = 0

var finished: bool = false
var winner: int = -1


func _init(p_seed: int = 1, p_base_hp: int = 20, p_base_damage: int = 1, p_level: Dictionary = {}, p_economy: bool = true, p_profile: Dictionary = {}, p_data: GameData = null) -> void:
	seed = p_seed
	rng.seed = seed
	level = p_level
	economy_enabled = p_economy
	data = p_data
	if data == null:
		data = GameData.new()
		data.load_all()
	unit_defs = data.unit_defs
	guild_defs = data.guild_defs
	unit_order = data.unit_order
	guild_order = data.guild_order
	promo_kills = data.get_balance("promo_kills", [1, 3, 5])
	promo_cost = data.get_balance("promo_cost", [40, 80, 120])
	counter_matrix = data.counters
	pop_max = int(data.get_balance("base_pop", 8))
	edge_slot_width = float(data.get_balance("road_slot_width", 14.0))
	edge_slot_padding = float(data.get_balance("road_slot_padding", 1.0))
	station_spacing = float(data.get_balance("squad_spacing", 16.0))
	squad_slot_tolerance = float(data.get_balance("squad_slot_tolerance", 3.0))
	squad_regroup_distance = float(data.get_balance("squad_regroup_distance", 80.0))
	assist_radius = float(data.get_balance("assist_radius", 150.0))
	vision_radius = float(data.get_balance("vision_radius", 180.0))

	map_data = data.map_for_level(level)
	map_graph = MapGraph.new(map_data)
	map_snapshot = map_data.to_snapshot()
	world_width = map_data.world_width
	world_height = map_data.world_height
	base_nodes = [map_data.base_node_id(PLAYER), map_data.base_node_id(ENEMY)]
	player_spawns = map_data.spawns_for_team(PLAYER)
	enemy_spawns = map_data.spawns_for_team(ENEMY)
	station_order = _build_station_order(p_profile)
	for i in range(station_order.size()):
		station_rank_by_id[String(station_order[i])] = i
	edge_slots.clear()
	node_queues.clear()
	squads.clear()
	for edge_id in map_data.edge_by_id:
		var slot_count := map_data.edge_slot_count(String(edge_id), edge_slot_width, edge_slot_padding)
		var slots: Array = []
		for i in range(slot_count):
			slots.append(-1)
		edge_slots[String(edge_id)] = slots
	for node_id in map_data.node_by_id:
		node_queues[String(node_id)] = []
	for spawn_data in player_spawns:
		var spawn_id := String(spawn_data.get("id", ""))
		var entry := String(spawn_data.get("entry", ""))
		var entry_length := map_graph.edge_length(entry)
		var rally_s := minf(60.0, entry_length * 0.5)
		rallies[spawn_id] = {
			"edge_id": entry,
			"s": rally_s,
			"pos": map_graph.edge_point(entry, rally_s),
			"custom": false,
		}
	for spawn_data in player_spawns + enemy_spawns:
		spawn_cd[String(spawn_data.get("id", ""))] = {}

	base_hp_max = int(level.get("base_hp", p_base_hp))
	base_damage = int(level.get("base_damage", p_base_damage))
	base_hp = [base_hp_max, base_hp_max]
	stipend = float(level.get("stipend", 2.5))
	gold = float(level.get("starting_gold", 150.0))

	waves = level.get("waves", [])
	wave_count = waves.size()
	for wave in waves:
		for spawn in wave.get("spawns", []):
			if bool(spawn.get("target", false)):
				target_total += int(spawn.get("count", 1))
	var level_mode := String(level.get("mode", ""))
	defense_mode = level_mode == "defense" or level_mode == "endless"
	endless_mode = level_mode == "endless"
	wave_message = _preferred_text(level, "intro_message_cn", "intro_message")
	message_timer = 4.0

	meta_unlocked_guilds = p_profile.get("unlocked_guilds", [])
	guild_favor = p_profile.get("guild_favor", {})
	level_available_guilds = level.get("available_guilds", guild_order)
	for guild_id in guild_order:
		guild_tier[guild_id] = -1
		guild_usage[guild_id] = 0
	_recompute_cap()


func _build_station_order(profile: Dictionary) -> Array:
	var result: Array = []
	var custom: Variant = profile.get("station_order", [])
	if custom is Array:
		for value in custom:
			var def_id := String(value)
			if unit_defs.has(def_id) and not result.has(def_id):
				result.append(def_id)
	var defaults: Array = unit_order.duplicate()
	defaults.sort_custom(func(a, b) -> bool:
		var da: Dictionary = unit_defs.get(String(a), {})
		var db: Dictionary = unit_defs.get(String(b), {})
		var ra := int(da.get("station_rank", 99))
		var rb := int(db.get("station_rank", 99))
		if ra == rb:
			return String(a) < String(b)
		return ra < rb
	)
	for def_id in defaults:
		if not result.has(def_id):
			result.append(String(def_id))
	return result


func set_station_order(order: Array) -> void:
	station_order = _build_station_order({"station_order": order})
	station_rank_by_id.clear()
	for i in range(station_order.size()):
		station_rank_by_id[String(station_order[i])] = i
	for u in units:
		u.station_rank = int(station_rank_by_id.get(u.def_id, 99))
	_process_all_queues()


func _guild_is_unlocked(guild_id: String) -> bool:
	if not guild_defs.has(guild_id):
		return false
	if not level_available_guilds.has(guild_id):
		return false
	if meta_unlocked_guilds.is_empty():
		return true
	return meta_unlocked_guilds.has(guild_id)


func _unit_unlocked(def_id: String) -> bool:
	if not unit_defs.has(def_id):
		return false
	var def: Dictionary = unit_defs[def_id]
	if not bool(def.get("recruitable", true)):
		return false
	var guild_id := String(def.get("guild", ""))
	if not _guild_is_unlocked(guild_id):
		return false
	return int(guild_tier.get(guild_id, -1)) >= int(def.get("relation_tier", 0))


func _effective_def(def_id: String) -> Dictionary:
	var d: Dictionary = unit_defs[def_id].duplicate(true)
	var guild_id := String(d.get("guild", ""))
	var favor := int(guild_favor.get(guild_id, 0))
	if favor > 0:
		var stat_per_point := float(data.get_balance("favor_hp_damage_per_point", 0.01))
		var cost_per_point := float(data.get_balance("favor_cost_per_point", 0.005))
		var stat_mult := 1.0 + stat_per_point * favor
		var cost_mult := maxf(0.5, 1.0 - cost_per_point * favor)
		d["hp"] = float(d.get("hp", 100.0)) * stat_mult
		d["damage"] = float(d.get("damage", 10.0)) * stat_mult
		d["cost"] = int(round(float(d.get("cost", 0)) * cost_mult))
	return d


func _resolve_spawn(team: int, route_value: Variant) -> Dictionary:
	var list: Array = player_spawns if team == PLAYER else enemy_spawns
	if list.is_empty():
		return {}
	if route_value is String:
		var spawn_data := map_data.spawn(String(route_value))
		if not spawn_data.is_empty() and int(spawn_data.get("team", -1)) == team:
			return spawn_data
		return {}
	if route_value is int or route_value is float:
		var index := posmod(int(route_value), list.size())
		return list[index]
	return list[0]


func queue_spawn(team: int, route: Variant, def_id: String, elite: bool = false) -> void:
	if finished:
		return
	if not unit_defs.has(def_id):
		_error("未知职业")
		return
	var spawn_data := _resolve_spawn(team, route)
	if spawn_data.is_empty():
		_error("路线无效")
		return
	commands.append({"type": "spawn", "team": team, "route": String(spawn_data.get("id", "")), "def_id": def_id, "elite": elite})


func queue_guild_action(guild_id: String) -> void:
	if finished or not guild_defs.has(guild_id):
		return
	commands.append({"type": "guild_action", "guild": guild_id})


func queue_promote() -> void:
	if finished or rep_rank >= promo_kills.size():
		return
	commands.append({"type": "promote"})


func queue_set_rally(route: Variant, world_pos: Vector2) -> void:
	if finished:
		return
	var spawn_data := _resolve_spawn(PLAYER, route)
	if spawn_data.is_empty():
		return
	commands.append({
		"type": "rally",
		"route": String(spawn_data.get("id", "")),
		"pos": world_pos,
	})


func queue_set_advance_line(route: Variant, x: float) -> void:
	# Compatibility for old callers: project onto the active route's world.
	queue_set_rally(route, Vector2(x, map_data.base_y(PLAYER)))


func queue_move_squad(unit_ids: Array, world_pos: Variant) -> void:
	if finished:
		return
	var pos := _as_world_pos(world_pos)
	commands.append({"type": "move_squad", "ids": unit_ids.duplicate(), "pos": pos})


func queue_hold_squad(unit_ids: Array) -> void:
	if finished:
		return
	commands.append({"type": "hold_squad", "ids": unit_ids.duplicate()})


func queue_return_squad(unit_ids: Array) -> void:
	if finished:
		return
	commands.append({"type": "return_squad", "ids": unit_ids.duplicate()})


func _as_world_pos(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(float(value), map_data.base_y(PLAYER))


func tick() -> void:
	if finished:
		return
	elapsed += TICK_DT
	if economy_enabled:
		gold += stipend * TICK_DT
	_update_cooldowns(TICK_DT)
	_update_timers(TICK_DT)
	_apply_commands()
	_update_waves()
	_update_squads()
	for u in units:
		if u.alive:
			_update_unit(u, TICK_DT)
	_process_all_queues()
	_update_projectiles(TICK_DT)
	_cleanup_dead()
	_check_finished()
	if endless_mode:
		score = endless_wave * 100 + kills * 10 + int(base_hp[PLAYER]) * 50
	tick_count += 1


func _update_cooldowns(dt: float) -> void:
	for route_id in spawn_cd:
		var cooldowns: Dictionary = spawn_cd[route_id]
		for def_id in cooldowns.keys():
			var remaining := float(cooldowns[def_id]) - dt
			if remaining <= 0.0:
				cooldowns.erase(def_id)
			else:
				cooldowns[def_id] = remaining


func _update_timers(dt: float) -> void:
	if message_timer > 0.0:
		message_timer = maxf(0.0, message_timer - dt)
		if message_timer == 0.0:
			wave_message = ""
	if error_timer > 0.0:
		error_timer = maxf(0.0, error_timer - dt)
		if error_timer == 0.0:
			last_error = ""


func _apply_commands() -> void:
	for cmd in commands:
		match String(cmd.get("type", "")):
			"spawn":
				_spawn_unit(int(cmd["team"]), String(cmd["route"]), String(cmd["def_id"]), bool(cmd.get("elite", false)))
			"guild_action":
				_apply_guild_action(String(cmd["guild"]))
			"promote":
				_apply_promote()
			"rally":
				_apply_rally(String(cmd["route"]), cmd["pos"])
			"move_squad":
				_apply_move_squad(cmd["ids"], cmd["pos"])
			"hold_squad":
				_apply_hold_squad(cmd["ids"])
			"return_squad":
				_apply_return_squad(cmd["ids"])
	commands.clear()


func _apply_guild_action(guild_id: String) -> void:
	if not _guild_is_unlocked(guild_id):
		_error("协会尚未解锁")
		return
	var guild: Dictionary = guild_defs[guild_id]
	var tiers: Array = guild.get("tiers", [])
	var next_tier := int(guild_tier.get(guild_id, -1)) + 1
	if next_tier >= tiers.size():
		_error("协会已达最高等级")
		return
	var tier: Dictionary = tiers[next_tier]
	var rank_gate := int(tier.get("rank_gate", 0))
	if rep_rank < rank_gate:
		_error("需要声望等级 %d" % rank_gate)
		return
	var cost := int(tier.get("cost", 0))
	if economy_enabled and gold < cost:
		_error("金币不足")
		return
	if economy_enabled:
		gold -= cost
		gold_spent_guilds += cost
	guild_tier[guild_id] = next_tier
	_recompute_cap()


func _apply_promote() -> void:
	if rep_rank >= promo_kills.size():
		_error("声望已达最高等级")
		return
	var needed := int(promo_kills[rep_rank])
	var cost := int(promo_cost[rep_rank])
	if fame < needed:
		_error("需要击杀 %d 个悬赏目标" % needed)
		return
	if economy_enabled and gold < cost:
		_error("金币不足")
		return
	if economy_enabled:
		gold -= cost
		gold_spent_promote += cost
	rep_rank += 1
	_recompute_cap()
	wave_message = "声望提升至 %d 级" % rep_rank
	message_timer = 2.0


func _recompute_cap() -> void:
	var base_pop := int(data.get_balance("base_pop", 8))
	var pop_per_rank := int(data.get_balance("pop_per_rank", 2))
	pop_max = base_pop + rep_rank * pop_per_rank
	for guild_id in guild_order:
		var tier := int(guild_tier.get(guild_id, -1))
		if tier < 0 or not guild_defs.has(guild_id):
			continue
		var tiers: Array = guild_defs[guild_id].get("tiers", [])
		for i in range(mini(tier + 1, tiers.size())):
			pop_max += int(tiers[i].get("cap", 0))


func _apply_rally(route_id: String, world_pos: Vector2) -> void:
	var spawn_data := map_data.spawn(route_id)
	if spawn_data.is_empty() or int(spawn_data.get("team", -1)) != PLAYER:
		return
	var target_node: String = String(base_nodes[ENEMY])
	var near := map_graph.nearest_point_on_route(route_id, target_node, world_pos)
	if String(near.get("edge_id", "")) == "":
		return
	rallies[route_id] = {
		"edge_id": String(near["edge_id"]),
		"s": float(near["s"]),
		"pos": near["pos"],
		"custom": true,
	}
	for u in units:
		if u.alive and u.team == PLAYER and u.route_id == route_id and not u.manual_order:
			u.goal_dirty = true


func _apply_move_squad(unit_ids: Array, world_pos: Vector2) -> void:
	var members: Array = []
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		_remove_from_queue(u)
		_clear_unit_squad(u)
		members.append(u)
	if members.is_empty():
		return
	var near := map_graph.nearest_point(world_pos)
	var target_edge := String(near.get("edge_id", ""))
	if target_edge == "":
		return
	var target_s := float(near.get("s", 0.0))
	var target_length := map_graph.edge_length(target_edge)
	var groups: Dictionary = {}
	for u in members:
		var key: String = u.route_id if u.route_id != "" else "route_default"
		if not groups.has(key):
			groups[key] = []
		groups[key].append(u)
	for key_value in groups:
		var key := String(key_value)
		var group: Array = groups[key]
		var squad_id := next_squad_id
		next_squad_id += 1
		var costs := {}
		var speed_cap := INF
		for u in group:
			costs[u.id] = _route_cost_to_point(u, target_edge, target_s)
			speed_cap = minf(speed_cap, u.speed)
		group.sort_custom(func(a: SimUnit, b: SimUnit) -> bool:
			var ca := float(costs[a.id])
			var cb := float(costs[b.id])
			if is_equal_approx(ca, cb):
				return a.id < b.id
			return ca < cb
		)
		var leader: SimUnit = group[0]
		squads[squad_id] = {
			"id": squad_id,
			"route_id": String(key),
			"member_ids": [],
			"leader_id": leader.id,
			"speed_cap": speed_cap,
			"spacing": station_spacing,
			"target_edge_id": target_edge,
			"target_s": target_s,
			"target_pos": near["pos"],
			"state": "moving",
			"trail": [],
			"trail_total": 0.0,
			"wait_time": 0.0,
		}
		for i in range(group.size()):
			var u: SimUnit = group[i]
			u.squad_id = squad_id
			u.squad_rank = i
			u.squad_state = "moving"
			u.move_speed_cap = speed_cap
			u.target_edge_id = target_edge
			u.target_edge_s = clampf(target_s - float(i) * station_spacing, 0.0, target_length)
			u.manual_order = true
			u.hold_position = false
			u.at_base = false
			u.target_point = map_graph.edge_point(target_edge, u.target_edge_s)
			u.goal_node = ""
			u.goal_dirty = true
			u.path = []
			u.path_index = 0
			if u.edge_id == target_edge:
				u.goal_dirty = false
			elif u.edge_id == "":
				_assign_manual_goal(u)
			squads[squad_id]["member_ids"].append(u.id)


func _route_cost_to_point(u: SimUnit, target_edge: String, target_s: float) -> float:
	if u.edge_id == target_edge:
		return absf(u.edge_s - target_s)
	var target := map_data.edge(target_edge)
	var from_node := String(target.get("from", ""))
	var to_node := String(target.get("to", ""))
	var start_node := u.node_id
	var prefix := 0.0
	if u.edge_id != "":
		var edge := map_data.edge(u.edge_id)
		var edge_length := map_graph.edge_length(u.edge_id)
		var to_from := u.edge_s + map_graph.path_length(map_graph.shortest_path(String(edge.get("from", "")), from_node))
		var to_to := u.edge_s + map_graph.path_length(map_graph.shortest_path(String(edge.get("from", "")), to_node))
		var from_to := (edge_length - u.edge_s) + map_graph.path_length(map_graph.shortest_path(String(edge.get("to", "")), from_node))
		var to_to2 := (edge_length - u.edge_s) + map_graph.path_length(map_graph.shortest_path(String(edge.get("to", "")), to_node))
		var cost_from := minf(to_from, from_to) + target_s
		var cost_to := minf(to_to, to_to2) + (map_graph.edge_length(target_edge) - target_s)
		return minf(cost_from, cost_to)
	if start_node == "":
		return INF
	var a := map_graph.path_length(map_graph.shortest_path(start_node, from_node)) + target_s
	var b := map_graph.path_length(map_graph.shortest_path(start_node, to_node)) + (map_graph.edge_length(target_edge) - target_s)
	return minf(a, b)


func _clear_unit_squad(u: SimUnit) -> void:
	if u.squad_id >= 0:
		var squad: Dictionary = squads.get(u.squad_id, {})
		if not squad.is_empty():
			var ids: Array = squad.get("member_ids", [])
			ids.erase(u.id)
	u.squad_id = -1
	u.squad_rank = -1
	u.squad_state = ""
	u.move_speed_cap = INF


func _update_squads(p_formation: bool = true) -> void:
	for squad_id in squads.keys():
		var squad: Dictionary = squads[squad_id]
		var living: Array = []
		for id in squad.get("member_ids", []):
			var u := _unit_by_id(int(id))
			if u != null and u.alive:
				living.append(u)
		if living.is_empty():
			squads.erase(squad_id)
			continue
		living.sort_custom(func(a: SimUnit, b: SimUnit) -> bool: return a.squad_rank < b.squad_rank)
		var leader: SimUnit = living[0]
		var old_leader_id := int(squad.get("leader_id", -1))
		var speed_cap := INF
		for u in living:
			speed_cap = minf(speed_cap, u.speed)
		squad["speed_cap"] = speed_cap
		squad["spacing"] = station_spacing
		squad["member_ids"] = []
		for i in range(living.size()):
			var u: SimUnit = living[i]
			u.squad_id = int(squad_id)
			u.squad_rank = i
			u.move_speed_cap = speed_cap
			u.squad_wait = false
			squad["member_ids"].append(u.id)
		squad["leader_id"] = leader.id
		if old_leader_id != leader.id:
			# Promotion (or first build): the new leader resumes the squad's
			# objective and lays a fresh trail for the followers.
			leader.target_edge_id = String(squad.get("target_edge_id", ""))
			leader.target_edge_s = float(squad.get("target_s", -1.0))
			leader.goal_node = ""
			leader.forced_entry = ""
			leader.path = []
			leader.path_index = 0
			leader.goal_dirty = leader.edge_id != leader.target_edge_id
			leader.manual_order = true
			leader.hold_position = false
			leader.at_base = false
			_reset_squad_trail(squad, leader)
			squad["wait_time"] = 0.0
		if not p_formation:
			continue
		_sample_squad_trail(squad, leader)
		var trail_total := float(squad.get("trail_total", 0.0))
		var trail_ready := living.size() > 1 and trail_total >= float(living.size() - 1) * station_spacing
		for i in range(1, living.size()):
			var u: SimUnit = living[i]
			var target: Dictionary = {}
			if trail_ready:
				target = _squad_trail_target(squad, float(i) * station_spacing)
			if target.is_empty():
				if u.target_edge_id == "":
					continue
				target = {
					"edge_id": u.target_edge_id,
					"s": u.target_edge_s,
				}
			_apply_squad_target(u, target)
		var waiting := false
		if trail_ready and _squad_tail_far(squad, living):
			var wait_time := float(squad.get("wait_time", 0.0)) + TICK_DT
			if wait_time <= SQUAD_WAIT_LIMIT:
				leader.squad_wait = true
				waiting = true
			squad["wait_time"] = wait_time
		else:
			squad["wait_time"] = 0.0
		var trail_edges := {}
		var trail: Array = squad.get("trail", [])
		for point in trail:
			var trail_edge := String(point.get("edge_id", ""))
			if trail_edge != "":
				trail_edges[trail_edge] = true
		var state := "moving"
		if waiting:
			state = "waiting"
		else:
			for u in living:
				if u.target_id >= 0:
					state = "fighting"
					break
				# A member off the leader's trail is actively rejoining the
				# column; a member merely behind its slot is still moving.
				if trail_ready and u.edge_id != "" and not trail_edges.has(u.edge_id):
					state = "regroup"
		squad["state"] = state
		for u in living:
			u.squad_state = state


func _reset_squad_trail(squad: Dictionary, leader: SimUnit) -> void:
	squad["trail"] = [{
		"edge_id": leader.edge_id,
		"s": leader.edge_s,
		"pos": leader.pos,
		"dist": 0.0,
	}]
	squad["trail_total"] = 0.0


func _sample_squad_trail(squad: Dictionary, leader: SimUnit) -> void:
	var trail: Array = squad.get("trail", [])
	if trail.is_empty():
		_reset_squad_trail(squad, leader)
		return
	var last: Dictionary = trail[trail.size() - 1]
	var last_pos: Vector2 = last.get("pos", leader.pos)
	var moved := last_pos.distance_to(leader.pos)
	var same_edge := String(last.get("edge_id", "")) == leader.edge_id
	if moved < SQUAD_TRAIL_STEP and same_edge:
		return
	var total := float(squad.get("trail_total", 0.0)) + moved
	trail.append({
		"edge_id": leader.edge_id,
		"s": leader.edge_s,
		"pos": leader.pos,
		"dist": total,
	})
	while trail.size() > 2 and total - float(trail[0].get("dist", 0.0)) > SQUAD_TRAIL_KEEP:
		trail.pop_front()
	squad["trail"] = trail
	squad["trail_total"] = total


func _squad_trail_target(squad: Dictionary, behind: float) -> Dictionary:
	var trail: Array = squad.get("trail", [])
	if trail.is_empty():
		return {}
	var total := float(squad.get("trail_total", 0.0))
	var want := maxf(0.0, total - behind)
	var best: Dictionary = trail[0]
	for point in trail:
		var point_dist := float(point.get("dist", 0.0))
		if point_dist <= want:
			best = point
		else:
			break
	var edge_id := String(best.get("edge_id", ""))
	if edge_id == "":
		# The leader is crossing a node; keep the follower's current goal for
		# this tick and resume the trail as soon as the leader enters an edge.
		return {}
	return {
		"edge_id": edge_id,
		"s": float(best.get("s", 0.0)),
	}


func _squad_trail_progress(squad: Dictionary, pos: Vector2) -> float:
	var trail: Array = squad.get("trail", [])
	var best_distance := INF
	var best_progress := 0.0
	for point in trail:
		var point_pos: Vector2 = point.get("pos", Vector2.ZERO)
		var distance := point_pos.distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			best_progress = float(point.get("dist", 0.0))
	return best_progress


func _squad_tail_far(squad: Dictionary, living: Array) -> bool:
	var total := float(squad.get("trail_total", 0.0))
	if total <= 0.0:
		return false
	var min_progress := total
	for i in range(1, living.size()):
		var u: SimUnit = living[i]
		# A queued or fighting tail cannot catch up by definition. Waiting on
		# it would stall the whole squad, so the leader keeps advancing.
		if u.waiting or u.target_id >= 0 or u.hold_position:
			return false
		min_progress = minf(min_progress, _squad_trail_progress(squad, u.pos))
	return total - min_progress > squad_regroup_distance


func _apply_squad_target(u: SimUnit, target: Dictionary) -> void:
	var edge_id := String(target.get("edge_id", ""))
	if edge_id == "":
		return
	var target_s := float(target.get("s", 0.0))
	if u.edge_id == edge_id:
		u.goal_node = ""
		u.target_edge_id = edge_id
		u.target_edge_s = target_s
		u.goal_dirty = false
		u.path = []
		u.path_index = 0
		return
	if u.edge_id == "":
		var changed := u.target_edge_id != edge_id or absf(u.target_edge_s - target_s) > 0.25
		u.goal_node = ""
		u.target_edge_id = edge_id
		u.target_edge_s = target_s
		if changed or u.path_index >= u.path.size():
			_set_goal_edge(u, edge_id, target_s)
			u.manual_order = true
		return
	u.goal_node = ""
	u.target_edge_id = edge_id
	u.target_edge_s = target_s
	# On an edge the unit must reach a node before the path can change. The
	# dirty flag makes it replan as soon as it exits instead of every tick.
	u.goal_dirty = true


func _assign_manual_goal(u: SimUnit) -> void:
	if u.target_edge_id == "":
		u.path = []
		u.path_index = 0
		u.goal_dirty = false
		return
	u.goal_dirty = false
	if u.edge_id == u.target_edge_id:
		u.path = []
		u.path_index = 0
		return
	if u.edge_id != "":
		u.goal_dirty = true
		return
	_set_goal_edge(u, u.target_edge_id, u.target_edge_s)
	u.manual_order = true


func _apply_hold_squad(unit_ids: Array) -> void:
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		_clear_unit_squad(u)
		u.manual_order = true
		u.hold_position = true
		u.at_base = false
		u.path = []
		u.path_index = 0
		u.goal_dirty = false


func _apply_return_squad(unit_ids: Array) -> void:
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		_clear_unit_squad(u)
		u.manual_order = false
		u.hold_position = false
		u.at_base = false
		u.goal_dirty = true
		u.path = []
		u.path_index = 0


func _spawn_unit(team: int, route_value: Variant, def_id: String, elite: bool = false, is_target: bool = false, wave_number: int = 0) -> void:
	if not unit_defs.has(def_id):
		_error("未知职业")
		return
	var spawn_data := _resolve_spawn(team, route_value)
	if spawn_data.is_empty():
		_error("路线无效")
		return
	var route_id := String(spawn_data.get("id", ""))
	var def: Dictionary
	if team == PLAYER:
		if economy_enabled and not _unit_unlocked(def_id):
			_error("职业尚未解锁")
			return
		def = _effective_def(def_id)
	else:
		def = unit_defs[def_id]

	if team == PLAYER and economy_enabled:
		var cost := int(def.get("cost", 0))
		var pop := int(def.get("pop", 1))
		if gold < cost:
			_error("金币不足")
			return
		if get_pop_used() + pop > pop_max:
			_error("已达招募上限")
			return
		var route_cooldowns: Dictionary = spawn_cd.get(route_id, {})
		var cd := float(route_cooldowns.get(def_id, 0.0))
		if cd > 0.0:
			_error("该职业仍在冷却")
			return
		gold -= cost
		gold_spent_units += cost
		route_cooldowns[def_id] = float(def.get("cooldown", 3.0))
		spawn_cd[route_id] = route_cooldowns
		var guild_id := String(def.get("guild", ""))
		guild_usage[guild_id] = int(guild_usage.get(guild_id, 0)) + 1

	var base_id := String(spawn_data.get("base", ""))
	var spawn_pos := map_data.node_pos(base_id)
	var unit := SimUnit.new(next_id, team, def_id, def, spawn_pos, elite, is_target)
	unit.spawn_wave = wave_number
	unit.route_id = route_id
	unit.station_rank = int(station_rank_by_id.get(def_id, 99))
	unit.node_id = base_id
	unit.edge_id = ""
	unit.edge_s = 0.0
	unit.forced_entry = String(spawn_data.get("entry", ""))
	unit.goal_dirty = true
	if team == PLAYER and rallies.has(route_id):
		var rally: Dictionary = rallies[route_id]
		if String(rally.get("edge_id", "")) == unit.forced_entry:
			unit.goal_dirty = false
			unit.target_edge_id = unit.forced_entry
			unit.target_edge_s = clampf(float(rally.get("s", 0.0)) - float(unit.station_rank) * station_spacing, 0.0, map_graph.edge_length(unit.forced_entry))
	next_id += 1
	units.append(unit)


func _update_waves() -> void:
	if endless_mode:
		_update_endless(TICK_DT)
		return
	while next_wave_index < waves.size():
		var wave: Dictionary = waves[next_wave_index]
		if float(wave.get("time", 0.0)) > elapsed:
			break
		_spawn_wave(wave, next_wave_index + 1)
		wave_message = _preferred_text(wave, "message_cn", "message")
		message_timer = 4.0
		next_wave_index += 1


func _spawn_wave(wave: Dictionary, wave_number: int) -> void:
	if economy_enabled:
		gold += float(data.get_balance("wave_gold_base", 30)) + float(data.get_balance("wave_gold_per_wave", 5)) * wave_number
	var default_route: Variant = wave.get("route", wave.get("lane", 0))
	for spawn in wave.get("spawns", []):
		var route_value: Variant = spawn.get("route", spawn.get("lane", default_route))
		var unit_id := String(spawn.get("unit", "swordsman"))
		var count := int(spawn.get("count", 1))
		var elite := bool(spawn.get("elite", false))
		var target := bool(spawn.get("target", false))
		for i in range(count):
			_spawn_unit(ENEMY, route_value, unit_id, elite, target, wave_number)


func _update_endless(dt: float) -> void:
	for u in units:
		if u.alive and u.team == ENEMY:
			return
	endless_timer = maxf(0.0, endless_timer - dt)
	if endless_timer > 0.0:
		return
	endless_wave += 1
	_spawn_endless_wave(endless_wave)
	endless_timer = maxf(8.0, 18.0 - endless_wave * 0.5)
	wave_message = "无尽第 %d 波" % endless_wave
	message_timer = 3.0


func _spawn_endless_wave(wave_number: int) -> void:
	if economy_enabled:
		gold += 30.0 + 5.0 * wave_number
	var budget := float(data.get_balance("endless_budget_base", 40.0)) + float(data.get_balance("endless_budget_per_wave", 14.0)) * wave_number + float(data.get_balance("endless_budget_quadratic", 1.2)) * wave_number * wave_number
	var spent := 0.0
	var spawned := 0
	var target_spawned := false
	if enemy_spawns.is_empty():
		return
	while spent < budget and spawned < 30:
		var remaining := budget - spent
		var candidates: Array = []
		for candidate_id in unit_order:
			if unit_defs.has(candidate_id) and float(unit_defs[candidate_id].get("cost", 30)) <= remaining:
				candidates.append(candidate_id)
		if candidates.is_empty():
			break
		var def_id: String = String(candidates[rng.randi_range(0, candidates.size() - 1)])
		var base: Dictionary = unit_defs.get(def_id, {})
		if base.is_empty():
			break
		var cost := float(base.get("cost", 30))
		var spawn_data: Dictionary = enemy_spawns[rng.randi_range(0, enemy_spawns.size() - 1)]
		var elite := rng.randf() < minf(0.25, 0.04 + 0.01 * wave_number)
		var mark_target := wave_number % 3 == 0 and not target_spawned
		_spawn_unit(ENEMY, String(spawn_data.get("id", "")), def_id, elite, mark_target, wave_number)
		if mark_target:
			target_spawned = true
		spent += cost
		spawned += 1
	if spawned == 0:
		_spawn_unit(ENEMY, String(enemy_spawns[0].get("id", "")), "swordsman", false, false)


func _update_unit(u: SimUnit, dt: float) -> void:
	u.attack_cd = maxf(0.0, u.attack_cd - dt)
	u.combat_cooldown = maxf(0.0, u.combat_cooldown - dt)
	_update_heal(u, dt)

	var target := _find_target(u)
	if target != null and _distance(u, target) <= u.attack_range:
		u.state = "attack"
		u.target_id = target.id
		u.stationary_time += dt
		if u.attack_cd <= 0.0:
			_perform_attack(u, target)
			u.attack_cd = _attack_interval(u)
		_check_base_arrival(u)
		return

	if u.hold_position:
		u.state = "hold"
		u.target_id = target.id if target != null else -1
		u.stationary_time += dt
		_check_base_arrival(u)
		return

	if u.waiting:
		u.state = "queue"
		u.target_id = target.id if target != null else -1
		u.stationary_time += dt
		_check_base_arrival(u)
		return

	# Once all scheduled waves are out, idle defenders seek remaining enemies
	# instead of holding at a rally forever and stalling the finish condition.
	if target == null and u.team == PLAYER and defense_mode and next_wave_index >= wave_count and not u.manual_order and not u.hold_position:
		var seek := _nearest_enemy_elsewhere(u)
		if seek != null:
			_seek_enemy(u, seek)

	if target != null and target.edge_id == u.edge_id and u.edge_id != "":
		u.state = "engage"
		u.target_id = target.id
		u.goal_dirty = false
		var target_s := map_graph.edge_progress(u.edge_id, target.pos)
		_move_on_edge_toward(u, target_s, dt)
		_check_base_arrival(u)
		return

	if u.squad_wait:
		u.state = "wait"
		u.target_id = -1
		u.stationary_time += dt
		_check_base_arrival(u)
		return
	u.target_id = -1
	if u.edge_id != "":
		_move_on_current_edge(u, dt)
	else:
		_update_at_node(u, dt)
	_check_base_arrival(u)


func _update_at_node(u: SimUnit, dt: float) -> void:
	if u.forced_entry != "" and u.node_id != "":
		_try_enter_edge(u, u.forced_entry, u.node_id)
		return
	if u.goal_dirty:
		if u.manual_order:
			_assign_manual_goal(u)
		else:
			_assign_route_goal(u)
	if u.path_index >= u.path.size():
		if u.goal_node != "" and u.node_id == u.goal_node:
			_check_base_arrival(u)
			return
		if u.target_edge_id != "" and u.node_id != "":
			var target_edge := map_data.edge(u.target_edge_id)
			if String(target_edge.get("from", "")) == u.node_id or String(target_edge.get("to", "")) == u.node_id:
				if _try_enter_edge(u, u.target_edge_id, u.node_id):
					return
		if u.goal_node == "" and u.target_edge_id == "" and not u.manual_order and not u.hold_position:
			# Recover from a stale/empty goal (e.g. a path was cleared while
			# entering a forced route edge) instead of idling forever.
			u.goal_dirty = true
			_assign_route_goal(u)
			if u.path_index < u.path.size():
				u.state = "advance"
				return
		u.state = "hold"
		u.stationary_time += dt
		return
	var next_edge := String(u.path[u.path_index])
	if not _try_enter_edge(u, next_edge, u.node_id):
		u.state = "queue"
		u.stationary_time += dt
		return
	u.state = "advance"


func _assign_route_goal(u: SimUnit) -> void:
	if u.route_id == "":
		u.goal_node = base_nodes[ENEMY] if u.team == PLAYER else base_nodes[PLAYER]
		_set_goal_node(u, u.goal_node)
		return
	if u.team == PLAYER and rallies.has(u.route_id):
		var rally: Dictionary = rallies[u.route_id]
		var rally_s := float(rally.get("s", 0.0))
		var formation_s := clampf(rally_s - float(u.station_rank) * station_spacing, 0.0, map_graph.edge_length(String(rally.get("edge_id", ""))))
		_set_goal_edge(u, String(rally.get("edge_id", "")), formation_s)
		return
	u.goal_node = base_nodes[ENEMY] if u.team == PLAYER else base_nodes[PLAYER]
	_set_goal_node(u, u.goal_node)


func _set_goal_node(u: SimUnit, node: String) -> void:
	u.goal_node = node
	u.target_edge_id = ""
	u.target_edge_s = -1.0
	u.goal_dirty = false
	u.path = []
	u.path_index = 0
	if u.edge_id != "":
		u.goal_dirty = true
		return
	if u.node_id == node:
		return
	u.path = map_graph.shortest_path(u.node_id, node)


func _set_goal_edge(u: SimUnit, edge_id: String, s: float) -> void:
	if edge_id == "" or not map_data.edge_by_id.has(edge_id):
		u.goal_dirty = false
		return
	u.goal_node = ""
	u.target_edge_id = edge_id
	u.target_edge_s = clampf(s, 0.0, map_graph.edge_length(edge_id))
	u.goal_dirty = false
	u.path = []
	u.path_index = 0
	if u.edge_id == edge_id:
		return
	if u.edge_id != "":
		u.goal_dirty = true
		return
	var edge: Dictionary = map_data.edge(edge_id)
	var from_node := String(edge.get("from", ""))
	var to_node := String(edge.get("to", ""))
	var path_from := map_graph.shortest_path(u.node_id, from_node)
	var path_to := map_graph.shortest_path(u.node_id, to_node)
	var cost_from := map_graph.path_length(path_from) + u.target_edge_s
	var cost_to := map_graph.path_length(path_to) + (map_graph.edge_length(edge_id) - u.target_edge_s)
	if cost_to < cost_from:
		u.path = path_to
		u.path.append(edge_id)
	else:
		u.path = path_from
		u.path.append(edge_id)
	u.path_index = 0


func _try_enter_edge(u: SimUnit, edge_id: String, entry_node: String) -> bool:
	if not map_data.edge_by_id.has(edge_id):
		return false
	var edge_length := map_graph.edge_length(edge_id)
	var entry_s := 0.0 if String(map_data.edge(edge_id).get("from", "")) == entry_node else edge_length
	if edge_id == u.target_edge_id and absf(u.target_edge_s - entry_s) <= 0.5:
		# Target point is exactly at the node; do not enter-and-exit in a loop.
		u.node_id = entry_node
		u.edge_id = ""
		u.path_index = u.path.size()
		u.target_edge_id = ""
		u.target_edge_s = -1.0
		u.goal_dirty = false
		u.hold_position = true
		u.state = "hold"
		return true
	var slot_index := _free_slot_for(edge_id, u)
	if slot_index < 0:
		if _edge_blocked_by_friend(edge_id, u.team) and _replan_around_friend(u, edge_id):
			return false
		_enqueue(u, entry_node, edge_id)
		return false
	if u.waiting:
		_remove_from_queue(u)
	u.edge_id = edge_id
	u.edge_slot = slot_index
	var slots: Array = edge_slots.get(edge_id, [])
	slots[slot_index] = u.id
	edge_slots[edge_id] = slots
	u.lateral = (float(slot_index) - float(slots.size() - 1) * 0.5) * edge_slot_width
	u.edge_s = 0.0 if String(map_data.edge(edge_id).get("from", "")) == entry_node else map_graph.edge_length(edge_id)
	u.edge_dir = 1 if String(map_data.edge(edge_id).get("from", "")) == entry_node else -1
	u.node_id = ""
	u.waiting = false
	u.wait_node = ""
	u.wait_edge = ""
	_place_on_edge(u)
	if u.forced_entry == edge_id:
		u.forced_entry = ""
		if u.target_edge_id != edge_id:
			u.goal_dirty = true
	if edge_id == u.target_edge_id:
		if u.target_edge_s < u.edge_s:
			u.edge_dir = -1
		elif u.target_edge_s > u.edge_s:
			u.edge_dir = 1
		# If the target point is at the entry node, the unit is already there.
		if absf(u.target_edge_s - u.edge_s) <= 0.5:
			_exit_edge(u, true)
	return true


func _edge_blocked_by_friend(edge_id: String, team: int) -> bool:
	var slots: Array = edge_slots.get(edge_id, [])
	var has_any := false
	for value in slots:
		var id := int(value)
		if id < 0:
			return false
		var occupant := _unit_by_id(id)
		if occupant == null:
			return false
		has_any = true
		if occupant.team != team:
			return false
	return has_any


func _replan_around_friend(u: SimUnit, blocked_edge: String) -> bool:
	if u.waiting or u.node_id == "":
		return false
	if u.manual_order and u.target_edge_id != "" and u.target_edge_id != blocked_edge:
		var target := map_data.edge(u.target_edge_id)
		var from_node := String(target.get("from", ""))
		var to_node := String(target.get("to", ""))
		var path_from := map_graph.shortest_path(u.node_id, from_node, [blocked_edge])
		var path_to := map_graph.shortest_path(u.node_id, to_node, [blocked_edge])
		if path_from.is_empty() and path_to.is_empty():
			return false
		var cost_from := map_graph.path_length(path_from) + u.target_edge_s
		var cost_to := map_graph.path_length(path_to) + (map_graph.edge_length(u.target_edge_id) - u.target_edge_s)
		if path_to.is_empty() or (not path_from.is_empty() and cost_from <= cost_to):
			u.path = path_from
			u.path.append(u.target_edge_id)
		else:
			u.path = path_to
			u.path.append(u.target_edge_id)
		u.path_index = 0
		u.goal_dirty = false
		return true
	if u.goal_node != "":
		var path := map_graph.shortest_path(u.node_id, u.goal_node, [blocked_edge])
		if path.is_empty():
			return false
		u.path = path
		u.path_index = 0
		u.goal_dirty = false
		return true
	return false


func _free_slot_for(edge_id: String, u: SimUnit) -> int:
	var slots: Array = edge_slots.get(edge_id, [])
	if slots.is_empty():
		return -1
	var count := slots.size()
	var start := 0
	var end := count
	if count >= 2:
		if u.team == PLAYER:
			end = int(ceil(count * 0.5))
		else:
			start = int(floor(count * 0.5))
	for i in range(start, end):
		if int(slots[i]) < 0:
			return i
	for i in range(count):
		if int(slots[i]) < 0:
			return i
	return -1


func _place_on_edge(u: SimUnit) -> void:
	var center := map_graph.edge_point(u.edge_id, u.edge_s)
	var heading := map_graph.edge_heading(u.edge_id, u.edge_s)
	var normal := Vector2(-heading.y, heading.x)
	u.set_position(center + normal * u.lateral)


func _enqueue(u: SimUnit, node: String, edge_id: String) -> void:
	if u.waiting and u.wait_node == node and u.wait_edge == edge_id:
		return
	_remove_from_queue(u)
	u.waiting = true
	u.wait_node = node
	u.wait_edge = edge_id
	u.wait_path_index = u.path_index
	u.wait_time = 0.0
	var queue: Array = node_queues.get(node, [])
	queue.append(u.id)
	node_queues[node] = queue
	u.pos = _queue_position(node, queue.size() - 1)
	u.lateral = 0.0
	u.edge_slot = -1
	u.edge_id = ""
	u.node_id = node


func _remove_from_queue(u: SimUnit) -> void:
	if u.wait_node == "":
		u.waiting = false
		return
	var old_node := u.wait_node
	var queue: Array = node_queues.get(old_node, [])
	queue.erase(u.id)
	node_queues[old_node] = queue
	_refresh_queue_positions(old_node)
	u.waiting = false
	u.wait_node = ""
	u.wait_edge = ""


func _queue_position(node: String, index: int) -> Vector2:
	var col := index % 3
	var row := int(index / 3)
	return map_data.node_pos(node) + Vector2((col - 1) * 14.0, row * 16.0 + 8.0)


func _refresh_queue_positions(node: String) -> void:
	var queue: Array = node_queues.get(node, [])
	for i in range(queue.size()):
		var u := _unit_by_id(int(queue[i]))
		if u != null and u.waiting:
			u.pos = _queue_position(node, i)


func _process_queue(node: String) -> void:
	var queue: Array = node_queues.get(node, [])
	if queue.is_empty():
		return
	var sorted := queue.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var ua := _unit_by_id(int(a))
		var ub := _unit_by_id(int(b))
		if ua == null or ub == null:
			return int(a) < int(b)
		if ua.squad_id >= 0 and ua.squad_id == ub.squad_id:
			if ua.squad_rank != ub.squad_rank:
				return ua.squad_rank < ub.squad_rank
		if ua.station_rank == ub.station_rank:
			return ua.id < ub.id
		return ua.station_rank < ub.station_rank
	)
	var remaining: Array = []
	for id in sorted:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or not u.waiting:
			continue
		var edge_id := u.wait_edge
		if _free_slot_for(edge_id, u) >= 0:
			if _try_enter_edge(u, edge_id, node):
				continue
		remaining.append(id)
	node_queues[node] = remaining
	_refresh_queue_positions(node)


func _process_all_queues() -> void:
	for node_id in node_queues.keys():
		if not node_queues[node_id].is_empty():
			_process_queue(String(node_id))


func _move_on_current_edge(u: SimUnit, dt: float) -> void:
	if u.edge_id == "":
		return
	var length := map_graph.edge_length(u.edge_id)
	var target_s := length if u.edge_dir > 0 else 0.0
	if u.target_edge_id == u.edge_id:
		target_s = u.target_edge_s
	var move_speed := u.speed
	if u.squad_id >= 0:
		move_speed = minf(move_speed, u.move_speed_cap)
	var step := move_speed * dt
	var snap := 0.5
	if u.squad_id >= 0:
		snap = maxf(snap, squad_slot_tolerance)
	var delta := target_s - u.edge_s
	if absf(delta) <= maxf(snap, step):
		u.edge_s = target_s
		_place_on_edge(u)
		u.stationary_time += dt
		if u.target_edge_id == u.edge_id:
			u.state = "hold"
		else:
			_exit_edge(u, false)
		return
	u.edge_s += signf(delta) * step
	u.edge_dir = 1 if delta > 0.0 else -1
	_place_on_edge(u)
	u.state = "advance"
	u.stationary_time = 0.0


func _move_on_edge_toward(u: SimUnit, target_s: float, dt: float) -> void:
	var move_speed := u.speed
	if u.squad_id >= 0:
		move_speed = minf(move_speed, u.move_speed_cap)
	var step := move_speed * dt
	var delta := target_s - u.edge_s
	if absf(delta) <= maxf(1.0, step):
		u.edge_s = target_s
		_place_on_edge(u)
		return
	u.edge_s += signf(delta) * step
	_place_on_edge(u)


func _exit_edge(u: SimUnit, at_target: bool) -> void:
	if u.edge_id == "":
		return
	var edge: Dictionary = map_data.edge(u.edge_id)
	var exit_node := String(edge.get("to", "")) if u.edge_dir > 0 else String(edge.get("from", ""))
	var old_edge := u.edge_id
	_free_edge_slot(u)
	u.edge_id = ""
	u.edge_s = 0.0
	u.lateral = 0.0
	u.node_id = exit_node
	u.set_position(map_data.node_pos(exit_node))
	u.path_index += 1
	u.stationary_time = 0.0
	_process_queue(exit_node)
	if at_target:
		u.state = "hold"


func _find_target(u: SimUnit) -> SimUnit:
	var same_edge_target := false
	if u.target_id >= 0:
		var current := _unit_by_id(u.target_id)
		if current != null and current.alive and current.team != u.team:
			var dist := _distance(u, current)
			same_edge_target = current.edge_id == u.edge_id and u.edge_id != ""
			if same_edge_target or (dist <= u.aggro_range * 1.3 and dist <= u.attack_range * 1.3):
				return current

	# Retaliation: the last attacker is valid even if the normal aggro scan
	# would ignore it. This is also how front melee pulls nearby ranged fire.
	var attacker := _unit_by_id(u.last_attacker_id)
	if attacker != null and attacker.alive and attacker.team != u.team:
		var hit_dist := _distance(u, attacker)
		var same_hit_edge := attacker.edge_id == u.edge_id and u.edge_id != ""
		if same_hit_edge or hit_dist <= maxf(u.attack_range * 1.2, u.aggro_range):
			return attacker

	# Shared threat/vision: enemies being attacked or targeted by nearby allies
	# become assist targets for ranged units (and melee if in range).
	var assisted := {}
	for ally in units:
		if not ally.alive or ally.team != u.team or ally.id == u.id:
			continue
		if u.pos.distance_to(ally.pos) > assist_radius:
			continue
		if ally.target_id >= 0:
			var ally_target := _unit_by_id(ally.target_id)
			if ally_target != null and ally_target.alive and ally.pos.distance_to(ally_target.pos) <= vision_radius:
				assisted[int(ally.target_id)] = true
		if ally.last_attacker_id >= 0 and elapsed - ally.last_hit_time <= 2.5:
			var ally_attacker := _unit_by_id(ally.last_attacker_id)
			if ally_attacker != null and ally_attacker.alive and ally.pos.distance_to(ally_attacker.pos) <= vision_radius:
				assisted[int(ally.last_attacker_id)] = true
	var assisted_best: SimUnit = null
	var assisted_dist := INF
	for e in units:
		if not e.alive or e.team == u.team or not assisted.has(e.id):
			continue
		var dist := _distance(u, e)
		var same_edge: bool = e.edge_id == u.edge_id and u.edge_id != ""
		if not same_edge and dist > u.attack_range:
			continue
		if assisted_best == null or dist < assisted_dist or (is_equal_approx(dist, assisted_dist) and e.id < assisted_best.id):
			assisted_best = e
			assisted_dist = dist
	if assisted_best != null:
		return assisted_best

	var best: SimUnit = null
	var best_dist := INF
	for e in units:
		if not e.alive or e.team == u.team:
			continue
		var dist := _distance(u, e)
		var same_edge: bool = e.edge_id == u.edge_id and u.edge_id != ""
		if not same_edge and dist > u.aggro_range:
			continue
		var valid: bool = same_edge
		if dist <= u.attack_range:
			valid = true
		if not valid:
			continue
		if best == null or dist < best_dist or (is_equal_approx(dist, best_dist) and e.id < best.id):
			best = e
			best_dist = dist
	return best


func _nearest_enemy_elsewhere(u: SimUnit) -> SimUnit:
	var best: SimUnit = null
	var best_dist := INF
	for e in units:
		if not e.alive or e.team == u.team:
			continue
		var dist := u.pos.distance_to(e.pos)
		if best == null or dist < best_dist:
			best = e
			best_dist = dist
	return best


func _seek_enemy(u: SimUnit, enemy: SimUnit) -> void:
	if enemy == null:
		return
	if enemy.edge_id != "":
		if u.target_edge_id != enemy.edge_id:
			_set_goal_edge(u, enemy.edge_id, map_graph.edge_progress(enemy.edge_id, enemy.pos))
		elif u.edge_id == "" and u.goal_dirty:
			_set_goal_edge(u, enemy.edge_id, map_graph.edge_progress(enemy.edge_id, enemy.pos))
	elif enemy.node_id != "":
		if u.goal_node != enemy.node_id:
			_set_goal_node(u, enemy.node_id)


func _distance(a: SimUnit, b: SimUnit) -> float:
	return a.pos.distance_to(b.pos)


func _update_heal(u: SimUnit, dt: float) -> void:
	if u.heal_amount <= 0.0:
		return
	u.heal_cd = maxf(0.0, u.heal_cd - dt)
	if u.heal_cd > 0.0:
		return
	var best: SimUnit = null
	var best_ratio := 1.0
	for e in units:
		if not e.alive or e.team != u.team or e.hp >= e.max_hp:
			continue
		if u.pos.distance_to(e.pos) > u.heal_range:
			continue
		var ratio: float = float(e.hp) / maxf(1.0, float(e.max_hp))
		if ratio < best_ratio:
			best_ratio = ratio
			best = e
	if best != null:
		best.hp = minf(best.max_hp, best.hp + u.heal_amount)
		u.heal_cd = u.heal_interval


func _attack_interval(u: SimUnit) -> float:
	var interval := u.attack_interval
	if u.passive == "volley" and u.stationary_time >= 1.5:
		interval *= float(data.get_balance("volley_interval_mult", 0.8))
	return maxf(0.1, interval)


func _perform_attack(u: SimUnit, target: SimUnit) -> void:
	var mult := _damage_multiplier(u.attack_type, u.passive, target)
	var dmg := u.damage * mult
	if u.passive == "charge" and not u.charge_used:
		dmg *= float(data.get_balance("charge_damage_mult", 2.0))
		u.charge_used = true
	if u.projectile_speed > 0.0:
		_spawn_projectile(u, target, dmg)
	else:
		_apply_damage(target, dmg, u.team, u.id)


func _damage_multiplier(attack_type: String, source_passive: String, target: SimUnit) -> float:
	var row: Dictionary = counter_matrix.get(attack_type, {})
	var mult := float(row.get(target.armor_type, 1.0))
	if source_passive == "armor_pierce" and target.armor_type == "heavy":
		mult = maxf(mult, float(data.get_balance("armor_pierce_heavy_mult", 1.25)))
	if source_passive == "siege_master" and target.armor_type == "heavy":
		mult *= float(data.get_balance("siege_master_heavy_mult", 1.25))
	if source_passive == "backstab" and target.attack_type == "ranged":
		mult *= float(data.get_balance("backstab_ranged_mult", 1.5))
	if target.passive == "shield_wall" and attack_type == "ranged":
		mult *= float(data.get_balance("shield_wall_ranged_mult", 0.7))
	return mult


func _spawn_projectile(u: SimUnit, target: SimUnit, dmg: float) -> void:
	var p := SimProjectile.new()
	p.id = next_projectile_id
	next_projectile_id += 1
	p.team = u.team
	p.source_id = u.id
	p.pos = u.pos
	p.speed = u.projectile_speed
	p.target_id = target.id
	p.damage = dmg
	p.source_damage = u.damage
	p.attack_type = u.attack_type
	p.source_passive = u.passive
	projectiles.append(p)


func _update_projectiles(dt: float) -> void:
	for p in projectiles:
		if p.done:
			continue
		var target := _unit_by_id(int(p.target_id))
		if target == null or not target.alive:
			p.done = true
			continue
		var delta: Vector2 = target.pos - p.pos
		var distance: float = delta.length()
		if distance <= 10.0:
			_apply_damage(target, float(p.damage), int(p.team), int(p.source_id))
			if String(p.source_passive) == "splash":
				_apply_splash(p, target)
			p.done = true
		else:
			p.pos += delta.normalized() * minf(distance, float(p.speed) * dt)
	var alive: Array = []
	for p in projectiles:
		if not p.done:
			alive.append(p)
	projectiles = alive


func _apply_splash(p: SimProjectile, primary: SimUnit) -> void:
	var radius := float(data.get_balance("splash_radius", 50.0))
	var ratio := float(data.get_balance("splash_ratio", 0.5))
	for e in units:
		if not e.alive or e.team == p.team or e.id == primary.id:
			continue
		if e.pos.distance_to(primary.pos) <= radius:
			var mult := _damage_multiplier(String(p.attack_type), String(p.source_passive), e)
			_apply_damage(e, float(p.source_damage) * mult * ratio, int(p.team), int(p.source_id))


func _apply_damage(target: SimUnit, amount: float, source_team: int, source_id: int = -1) -> void:
	if not target.alive:
		return
	target.hp -= amount
	if source_id >= 0:
		target.last_attacker_id = source_id
		target.last_hit_time = elapsed
	if target.hp <= 0.0:
		target.hp = 0.0
		target.alive = false
		_release_edge(target)
		_on_unit_killed(target, source_team)


func _free_edge_slot(u: SimUnit) -> void:
	if u.edge_id == "" or u.edge_slot < 0:
		return
	var slots: Array = edge_slots.get(u.edge_id, [])
	if u.edge_slot < slots.size():
		slots[u.edge_slot] = -1
		edge_slots[u.edge_id] = slots
	u.edge_slot = -1


func _release_edge(u: SimUnit) -> void:
	if u.edge_id != "":
		var edge_id := u.edge_id
		var edge_data: Dictionary = map_data.edge(edge_id)
		var from_node := String(edge_data.get("from", ""))
		var to_node := String(edge_data.get("to", ""))
		_free_edge_slot(u)
		u.edge_id = ""
		_process_queue(from_node)
		_process_queue(to_node)
	if u.waiting:
		_remove_from_queue(u)


func _on_unit_killed(target: SimUnit, source_team: int) -> void:
	if target.team == ENEMY and source_team == PLAYER:
		kills += 1
	if not economy_enabled:
		return
	if target.team == ENEMY and source_team == PLAYER:
		var cost := float(target.def.get("cost", 0))
		var ratio := float(data.get_balance("elite_bounty_ratio", 0.3)) if target.is_elite else float(data.get_balance("bounty_ratio", 0.2))
		gold += maxf(1.0, cost * ratio)
		if target.is_target:
			fame += 1
			target_kills += 1
			gold += float(data.get_balance("target_gold", 15.0))


func _check_base_arrival(u: SimUnit) -> void:
	var enemy_base_pos := map_data.node_pos(base_nodes[ENEMY])
	var player_base_pos := map_data.node_pos(base_nodes[PLAYER])
	var enemy_center_distance := u.pos.distance_to(enemy_base_pos)
	var player_center_distance := u.pos.distance_to(player_base_pos)
	if u.edge_id != "":
		var center := map_graph.edge_point(u.edge_id, u.edge_s)
		enemy_center_distance = center.distance_to(enemy_base_pos)
		player_center_distance = center.distance_to(player_base_pos)
	elif u.node_id != "":
		var node_pos := map_data.node_pos(u.node_id)
		enemy_center_distance = node_pos.distance_to(enemy_base_pos)
		player_center_distance = node_pos.distance_to(player_base_pos)
	if u.team == PLAYER and enemy_center_distance <= 18.0:
		if defense_mode:
			u.at_base = true
			u.hold_position = true
			u.state = "hold"
			u.set_position(enemy_base_pos + Vector2(-18.0, 0.0))
		else:
			base_hp[ENEMY] = maxi(0, int(base_hp[ENEMY]) - base_damage)
			u.alive = false
	elif u.team == ENEMY and player_center_distance <= 18.0:
		var route_id := u.route_id
		leaks_by_unit[u.def_id] = int(leaks_by_unit.get(u.def_id, 0)) + 1
		leaks_by_route[route_id] = int(leaks_by_route.get(route_id, 0)) + 1
		leaks_by_edge[u.edge_id] = int(leaks_by_edge.get(u.edge_id, 0)) + 1
		if u.spawn_wave > 0:
			leaks_by_wave[u.spawn_wave] = int(leaks_by_wave.get(u.spawn_wave, 0)) + 1
		if u.is_target:
			target_leaks += 1
		var dmg := int(data.get_balance("elite_base_damage", 2)) if u.is_elite else base_damage
		base_hp[PLAYER] = maxi(0, int(base_hp[PLAYER]) - dmg)
		u.alive = false


func _cleanup_dead() -> void:
	var alive_units: Array = []
	for u in units:
		if u.alive:
			alive_units.append(u)
		else:
			_release_edge(u)
	units = alive_units
	_update_squads(false)


func _check_finished() -> void:
	if base_hp[PLAYER] <= 0 and base_hp[ENEMY] <= 0:
		finished = true
		winner = -1
		return
	if base_hp[PLAYER] <= 0:
		finished = true
		winner = ENEMY
		return
	if not defense_mode and base_hp[ENEMY] <= 0:
		finished = true
		winner = PLAYER
		return
	if defense_mode and wave_count > 0 and next_wave_index >= wave_count:
		for u in units:
			if u.alive and u.team == ENEMY:
				return
		for p in projectiles:
			if not p.done and p.team == ENEMY:
				return
		finished = true
		winner = PLAYER


func get_pop_used() -> int:
	var used := 0
	for u in units:
		if u.alive and u.team == PLAYER:
			used += int(u.def.get("pop", 1))
	return used


func _unit_by_id(p_id: int) -> SimUnit:
	for u in units:
		if u.id == p_id:
			return u
	return null


func get_unit_by_id(p_id: int) -> SimUnit:
	return _unit_by_id(p_id)


func is_finished() -> bool:
	return finished


func get_stars() -> int:
	if winner != PLAYER:
		return 0
	var thresholds: Array = level.get("star_thresholds", [])
	var two_star := int(data.get_balance("threshold_2", 12))
	var three_star := int(data.get_balance("threshold_3", 18))
	if thresholds.size() >= 2:
		two_star = int(thresholds[0])
		three_star = int(thresholds[1])
	if int(base_hp[PLAYER]) >= three_star:
		return 3
	if int(base_hp[PLAYER]) >= two_star:
		return 2
	return 1


func _error(text: String) -> void:
	last_error = text
	error_timer = 2.5


func _preferred_text(source: Dictionary, cn_key: String, fallback_key: String) -> String:
	var cn := String(source.get(cn_key, ""))
	if cn != "":
		return cn
	return String(source.get(fallback_key, ""))


func _next_wave_in() -> float:
	if next_wave_index >= waves.size():
		return 0.0
	return maxf(0.0, float(waves[next_wave_index].get("time", 0.0)) - elapsed)


func _route_name_for_value(route_value: Variant, team: int) -> String:
	var spawn_data := _resolve_spawn(team, route_value)
	if spawn_data.is_empty():
		return str(route_value)
	return String(spawn_data.get("name_cn", spawn_data.get("name", route_value)))


func _next_wave_preview() -> Dictionary:
	if endless_mode or next_wave_index >= waves.size():
		return {}
	var wave: Dictionary = waves[next_wave_index]
	var grouped := {}
	var default_route: Variant = wave.get("route", wave.get("lane", 0))
	for spawn in wave.get("spawns", []):
		var route_value: Variant = spawn.get("route", spawn.get("lane", default_route))
		var spawn_data := _resolve_spawn(ENEMY, route_value)
		var route_id := String(spawn_data.get("id", ""))
		var def_id := String(spawn.get("unit", "swordsman"))
		var def: Dictionary = unit_defs.get(def_id, {})
		if not grouped.has(route_id):
			grouped[route_id] = {}
		var key := def_id + ":" + str(bool(spawn.get("target", false)))
		var entry: Dictionary = grouped[route_id].get(key, {
			"id": def_id,
			"count": 0,
			"role": String(def.get("role", "")),
			"attack_type": String(def.get("attack_type", "")),
			"armor_type": String(def.get("armor_type", "")),
			"target": bool(spawn.get("target", false)),
		})
		entry["count"] = int(entry["count"]) + int(spawn.get("count", 1))
		grouped[route_id][key] = entry
	var routes_out: Array = []
	for route_id in grouped:
		var units_out: Array = []
		for entry in grouped[route_id].values():
			units_out.append(entry)
		routes_out.append({
			"route": String(route_id),
			"name": _route_name_for_value(route_id, ENEMY),
			"units": units_out,
		})
	return {
		"time": float(wave.get("time", 0.0)),
		"message": String(wave.get("message", "")),
		"routes": routes_out,
	}


func _result_stats() -> Dictionary:
	var final_comp := {}
	for u in units:
		if u.alive and u.team == PLAYER:
			final_comp[u.def_id] = int(final_comp.get(u.def_id, 0)) + 1
	return {
		"leaks_by_unit": leaks_by_unit.duplicate(),
		"leaks_by_route": leaks_by_route.duplicate(),
		"leaks_by_edge": leaks_by_edge.duplicate(),
		"leaks_by_wave": leaks_by_wave.duplicate(),
		"target_total": target_total,
		"target_kills": target_kills,
		"target_leaks": target_leaks,
		"gold_spent_units": gold_spent_units,
		"gold_spent_guilds": gold_spent_guilds,
		"gold_spent_promote": gold_spent_promote,
		"gold_unspent": int(floor(gold)),
		"final_comp": final_comp,
	}


func _catalog() -> Array:
	var result: Array = []
	for def_id in unit_order:
		if not unit_defs.has(def_id):
			continue
		var base: Dictionary = unit_defs[def_id]
		var effective: Dictionary = _effective_def(def_id)
		var guild_id := String(base.get("guild", ""))
		var tier_needed := int(base.get("relation_tier", 0))
		var attack_type := String(base.get("attack_type", ""))
		var row: Dictionary = counter_matrix.get(attack_type, {})
		var good_vs: Array = []
		var weak_vs: Array = []
		for armor in ["light", "heavy"]:
			var mult := float(row.get(armor, 1.0))
			if mult > 1.0:
				good_vs.append(armor)
			elif mult < 1.0:
				weak_vs.append(armor)
		var unlocked := _unit_unlocked(def_id)
		var guild_short := String(guild_defs.get(guild_id, {}).get("short_cn", guild_defs.get(guild_id, {}).get("short", guild_id)))
		var requirement := "" if unlocked else "%s关系%d" % [guild_short, tier_needed]
		if not _guild_is_unlocked(guild_id):
			requirement = "协会未开放"
		elif int(guild_tier.get(guild_id, -1)) < 0:
			requirement = "需先建交"
		result.append({
			"id": def_id,
			"name": String(base.get("display_name_cn", base.get("display_name", def_id))),
			"guild": guild_id,
			"guild_name": guild_short,
			"role": String(base.get("role", "")),
			"tier": tier_needed,
			"cost": int(effective.get("cost", 0)),
			"pop": int(effective.get("pop", 1)),
			"hp": float(effective.get("hp", 0.0)),
			"dps": float(effective.get("damage", 0.0)) / maxf(0.1, float(effective.get("attack_interval", 1.0))),
			"range": float(effective.get("range", 0.0)),
			"attack_type": attack_type,
			"armor_type": String(base.get("armor_type", "")),
			"passive": String(base.get("passive", "")),
			"good_vs": good_vs,
			"weak_vs": weak_vs,
			"unlocked": unlocked,
			"guild_unlocked": _guild_is_unlocked(guild_id),
			"requirement": requirement,
			"station_rank": int(station_rank_by_id.get(def_id, 99)),
		})
	return result


func _guild_snapshot() -> Array:
	var result: Array = []
	for guild_id in guild_order:
		if not guild_defs.has(guild_id):
			continue
		var guild: Dictionary = guild_defs[guild_id]
		var tiers: Array = guild.get("tiers", [])
		var tier := int(guild_tier.get(guild_id, -1))
		var next_tier := tier + 1
		var next_cost := 0
		var next_cap := 0
		var next_units: Array = []
		var next_unit_names: Array = []
		var next_rank_gate := 0
		if next_tier < tiers.size():
			next_cost = int(tiers[next_tier].get("cost", 0))
			next_cap = int(tiers[next_tier].get("cap", 0))
			next_units = tiers[next_tier].get("units", [])
			next_rank_gate = int(tiers[next_tier].get("rank_gate", 0))
			for unit_id in next_units:
				var unit_def: Dictionary = unit_defs.get(String(unit_id), {})
				next_unit_names.append(String(unit_def.get("display_name_cn", unit_def.get("display_name", unit_id))))
		result.append({
			"id": guild_id,
			"name": String(guild.get("name_cn", guild.get("name", guild_id))),
			"short": String(guild.get("short_cn", guild.get("short", guild_id))),
			"unlocked": _guild_is_unlocked(guild_id),
			"tier": tier,
			"max_tier": tiers.size() - 1,
			"next_cost": next_cost,
			"next_cap": next_cap,
			"next_units": next_units,
			"next_unit_names": next_unit_names,
			"rank_gate": next_rank_gate,
			"can_afford": economy_enabled and next_tier < tiers.size() and gold >= next_cost,
			"favor": int(guild_favor.get(guild_id, 0)),
			"usage": int(guild_usage.get(guild_id, 0)),
			"identity_cn": String(guild.get("identity_cn", "")),
		})
	return result


func _route_snapshot() -> Array:
	var result: Array = []
	var enemy_base: String = String(base_nodes[ENEMY])
	for spawn_data in player_spawns:
		var route_id := String(spawn_data.get("id", ""))
		var path := map_graph.path_from_spawn(route_id, enemy_base)
		var bottleneck := 999
		for edge_id in path:
			bottleneck = mini(bottleneck, map_data.edge_slot_count(String(edge_id), edge_slot_width, edge_slot_padding))
		if path.is_empty():
			bottleneck = 0
		var used := 0
		for u in units:
			if u.alive and u.team == PLAYER and u.route_id == route_id:
				used += 1
		var rally: Dictionary = rallies.get(route_id, {})
		result.append({
			"id": route_id,
			"name": String(spawn_data.get("name_cn", spawn_data.get("name", route_id))),
			"entry": String(spawn_data.get("entry", "")),
			"capacity": bottleneck,
			"used": used,
			"path": path,
			"rally": {
				"edge_id": String(rally.get("edge_id", "")),
				"s": float(rally.get("s", 0.0)),
				"pos": rally.get("pos", map_data.node_pos(base_nodes[PLAYER])),
				"custom": bool(rally.get("custom", false)),
			},
		})
	return result


func _squads_snapshot() -> Array:
	var result: Array = []
	for squad_id in squads:
		var squad: Dictionary = squads[squad_id]
		var leader := _unit_by_id(int(squad.get("leader_id", -1)))
		result.append({
			"id": int(squad_id),
			"route_id": String(squad.get("route_id", "")),
			"leader_id": int(squad.get("leader_id", -1)),
			"leader_name": String(leader.def.get("display_name_cn", leader.def_id)) if leader != null else "",
			"member_count": (squad.get("member_ids", []) as Array).size(),
			"speed_cap": float(squad.get("speed_cap", 0.0)),
			"spacing": float(squad.get("spacing", station_spacing)),
			"state": String(squad.get("state", "")),
			"target_edge_id": String(squad.get("target_edge_id", "")),
		})
	return result


func get_snapshot() -> Dictionary:
	var unit_data: Array = []
	for u in units:
		if not u.alive:
			continue
		var unit_guild := String(u.def.get("guild", ""))
		var guild_def: Dictionary = guild_defs.get(unit_guild, {})
		var guild_name := String(guild_def.get("short_cn", guild_def.get("short", unit_guild)))
		unit_data.append({
			"id": u.id,
			"team": u.team,
			"pos": [u.pos.x, u.pos.y],
			"x": u.pos.x,
			"y": u.pos.y,
			"edge_id": u.edge_id,
			"edge_s": u.edge_s,
			"lateral": u.lateral,
			"edge_slot": u.edge_slot,
			"body_width": u.body_width,
			"body_height": u.body_height,
			"route_id": u.route_id,
			"waiting": u.waiting,
			"station_rank": u.station_rank,
			"squad_id": u.squad_id,
			"squad_rank": u.squad_rank,
			"squad_state": u.squad_state,
			"squad_speed_cap": u.move_speed_cap if u.squad_id >= 0 else 0.0,
			"is_leader": u.squad_id >= 0 and int(squads.get(u.squad_id, {}).get("leader_id", -1)) == u.id,
			"hp": u.hp,
			"max_hp": u.max_hp,
			"def_id": u.def_id,
			"name": String(u.def.get("display_name_cn", u.def.get("display_name", u.def_id))),
			"guild": unit_guild,
			"guild_name": guild_name,
			"role": String(u.def.get("role", "")),
			"attack_type": u.attack_type,
			"armor_type": u.armor_type,
			"state": u.state,
			"target_id": u.target_id,
			"is_elite": u.is_elite,
			"is_target": u.is_target,
			"manual_order": u.manual_order,
			"hold_position": u.hold_position,
			"at_base": u.at_base,
			"station_slot": u.station_slot,
		})
	var projectile_data: Array = []
	for p in projectiles:
		projectile_data.append({
			"id": p.id,
			"team": p.team,
			"pos": [p.pos.x, p.pos.y],
			"target_id": p.target_id,
		})
	var cooldowns_out: Dictionary = {}
	for route_id in spawn_cd:
		cooldowns_out[route_id] = spawn_cd[route_id].duplicate()
	return {
		"tick": tick_count,
		"elapsed": elapsed,
		"base_hp": base_hp.duplicate(),
		"base_hp_max": base_hp_max,
		"base_damage": base_damage,
		"base_nodes": base_nodes.duplicate(),
		"units": unit_data,
		"projectiles": projectile_data,
		"finished": finished,
		"winner": winner,
		"stars": get_stars(),
		"world_width": world_width,
		"world_height": world_height,
		"player_base_x": map_data.base_x(PLAYER),
		"player_base_y": map_data.base_y(PLAYER),
		"enemy_base_x": map_data.base_x(ENEMY),
		"enemy_base_y": map_data.base_y(ENEMY),
		"player_base_name": map_data.base_name(PLAYER),
		"enemy_base_name": map_data.base_name(ENEMY),
		"map": map_snapshot,
		"routes": _route_snapshot(),
		"squads": _squads_snapshot(),
		"station_order": station_order.duplicate(),
		"favor_hp_per_point": float(data.get_balance("favor_hp_damage_per_point", 0.01)),
		"favor_cost_per_point": float(data.get_balance("favor_cost_per_point", 0.005)),
		"enemy_spawns": enemy_spawns.duplicate(true),
		"level_name": String(level.get("name_cn", level.get("name", "沙盒"))),
		"contract": int(level.get("contract", 0)),
		"brief": String(level.get("brief", "")),
		"gold": int(floor(gold)),
		"gold_exact": gold,
		"stipend": stipend,
		"income": stipend,
		"pop_used": get_pop_used(),
		"pop_max": pop_max,
		"fame": fame,
		"target_kills": target_kills,
		"target_total": target_total,
		"next_wave_preview": _next_wave_preview(),
		"result_stats": _result_stats(),
		"rep_rank": rep_rank,
		"max_rank": promo_kills.size(),
		"promo_kills": int(promo_kills[rep_rank]) if rep_rank < promo_kills.size() else 0,
		"promo_cost": int(promo_cost[rep_rank]) if rep_rank < promo_cost.size() else 0,
		"catalog": _catalog(),
		"guilds": _guild_snapshot(),
		"guild_usage": guild_usage.duplicate(),
		"cooldowns": cooldowns_out,
		"wave_index": endless_wave if endless_mode else next_wave_index,
		"wave_count": 0 if endless_mode else wave_count,
		"next_wave_in": endless_timer if endless_mode else _next_wave_in(),
		"kills": kills,
		"score": (endless_wave * 100 + kills * 10 + int(base_hp[PLAYER]) * 50) if endless_mode else 0,
		"message": wave_message,
		"error": last_error,
		"mode": "endless" if endless_mode else ("defense" if defense_mode else "debug"),
	}
