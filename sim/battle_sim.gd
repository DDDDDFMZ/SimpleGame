class_name BattleSim
extends RefCounted

const PLAYER := 0
const ENEMY := 1
const TICK_DT := 0.05
const TICK_HZ := 20.0
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

var base_hp: Array = [20, 20]
var base_hp_max: int = 20
var base_damage: int = 1
var player_base_x: float = 80.0
var enemy_base_x: float = 1520.0
var lane_count: int = 2
var advance_lines: Array = [92.0, 92.0]

var gold: float = 150.0
var stipend: float = 2.5
var pop_max: int = 8
var spawn_cd: Array = [{}, {}]

var fame: int = 0
var target_kills: int = 0
var target_total: int = 0
var target_leaks: int = 0
var leaks_by_unit: Dictionary = {}
var leaks_by_lane: Array = [0, 0]
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

	base_hp_max = int(level.get("base_hp", p_base_hp))
	base_damage = int(level.get("base_damage", p_base_damage))
	base_hp = [base_hp_max, base_hp_max]
	advance_lines = [player_base_x + 12.0, player_base_x + 12.0]
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
	wave_message = String(level.get("intro_message", ""))
	message_timer = 4.0

	meta_unlocked_guilds = p_profile.get("unlocked_guilds", [])
	guild_favor = p_profile.get("guild_favor", {})

	level_available_guilds = level.get("available_guilds", guild_order)
	for guild_id in guild_order:
		guild_tier[guild_id] = -1
		guild_usage[guild_id] = 0
	_recompute_cap()


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


func queue_spawn(team: int, lane: int, def_id: String, elite: bool = false) -> void:
	if finished:
		return
	if not unit_defs.has(def_id):
		_error("Unknown unit")
		return
	if lane < 0 or lane >= lane_count:
		_error("Invalid lane")
		return
	commands.append({"type": "spawn", "team": team, "lane": lane, "def_id": def_id, "elite": elite})


func queue_guild_action(guild_id: String) -> void:
	if finished or not guild_defs.has(guild_id):
		return
	commands.append({"type": "guild_action", "guild": guild_id})


func queue_promote() -> void:
	if finished or rep_rank >= promo_kills.size():
		return
	commands.append({"type": "promote"})


func queue_set_advance_line(lane: int, x: float) -> void:
	if finished or lane < 0 or lane >= lane_count:
		return
	commands.append({
		"type": "advance_line",
		"lane": lane,
		"x": clampf(x, player_base_x + 8.0, enemy_base_x - 8.0),
	})


func queue_move_squad(unit_ids: Array, x: float) -> void:
	if finished:
		return
	commands.append({
		"type": "move_squad",
		"ids": unit_ids.duplicate(),
		"x": clampf(x, player_base_x, enemy_base_x - 8.0),
	})


func queue_hold_squad(unit_ids: Array) -> void:
	if finished:
		return
	commands.append({"type": "hold_squad", "ids": unit_ids.duplicate()})


func queue_return_squad(unit_ids: Array) -> void:
	if finished:
		return
	commands.append({"type": "return_squad", "ids": unit_ids.duplicate()})


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

	for u in units:
		if u.alive:
			_update_unit(u, TICK_DT)
	_update_projectiles(TICK_DT)
	_cleanup_dead()
	_check_finished()
	if endless_mode:
		score = endless_wave * 100 + kills * 10 + int(base_hp[PLAYER]) * 50
	tick_count += 1


func _update_cooldowns(dt: float) -> void:
	for lane in range(2):
		for def_id in spawn_cd[lane].keys():
			var remaining := float(spawn_cd[lane][def_id]) - dt
			if remaining <= 0.0:
				spawn_cd[lane].erase(def_id)
			else:
				spawn_cd[lane][def_id] = remaining


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
				_spawn_unit(int(cmd["team"]), int(cmd["lane"]), String(cmd["def_id"]), bool(cmd.get("elite", false)))
			"guild_action":
				_apply_guild_action(String(cmd["guild"]))
			"promote":
				_apply_promote()
			"advance_line":
				_apply_advance_line(int(cmd["lane"]), float(cmd["x"]))
			"move_squad":
				_apply_move_squad(cmd["ids"], float(cmd["x"]))
			"hold_squad":
				_apply_hold_squad(cmd["ids"])
			"return_squad":
				_apply_return_squad(cmd["ids"])
	commands.clear()


func _apply_guild_action(guild_id: String) -> void:
	if not _guild_is_unlocked(guild_id):
		_error("Guild locked")
		return
	var guild: Dictionary = guild_defs[guild_id]
	var tiers: Array = guild.get("tiers", [])
	var next_tier := int(guild_tier.get(guild_id, -1)) + 1
	if next_tier >= tiers.size():
		_error("Guild maxed")
		return
	var tier: Dictionary = tiers[next_tier]
	var rank_gate := int(tier.get("rank_gate", 0))
	if rep_rank < rank_gate:
		_error("Needs Reputation Rank %d" % rank_gate)
		return
	var cost := int(tier.get("cost", 0))
	if economy_enabled and gold < cost:
		_error("Not enough gold")
		return
	if economy_enabled:
		gold -= cost
		gold_spent_guilds += cost
	guild_tier[guild_id] = next_tier
	_recompute_cap()


func _apply_promote() -> void:
	if rep_rank >= promo_kills.size():
		_error("Max reputation")
		return
	var needed := int(promo_kills[rep_rank])
	var cost := int(promo_cost[rep_rank])
	if fame < needed:
		_error("Need %d target kills" % needed)
		return
	if economy_enabled and gold < cost:
		_error("Not enough gold")
		return
	if economy_enabled:
		gold -= cost
		gold_spent_promote += cost
	rep_rank += 1
	_recompute_cap()
	wave_message = "Reputation Rank %d" % rep_rank
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


func _apply_advance_line(lane: int, x: float) -> void:
	if lane < 0 or lane >= lane_count:
		return
	advance_lines[lane] = x
	for u in units:
		if u.alive and u.team == PLAYER and u.lane == lane and not u.manual_order:
			u.move_target_x = x


func _apply_move_squad(unit_ids: Array, x: float) -> void:
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		u.manual_order = true
		u.hold_position = false
		u.at_base = false
		u.move_target_x = x


func _apply_hold_squad(unit_ids: Array) -> void:
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		u.manual_order = true
		u.hold_position = true
		u.at_base = false
		u.move_target_x = u.x


func _apply_return_squad(unit_ids: Array) -> void:
	for id in unit_ids:
		var u := _unit_by_id(int(id))
		if u == null or not u.alive or u.team != PLAYER:
			continue
		u.manual_order = false
		u.hold_position = false
		u.at_base = false
		u.move_target_x = float(advance_lines[u.lane])


func _spawn_unit(team: int, lane: int, def_id: String, elite: bool = false, is_target: bool = false, wave_number: int = 0) -> void:
	if not unit_defs.has(def_id):
		_error("Unknown unit")
		return

	var def: Dictionary
	if team == PLAYER:
		if economy_enabled and not _unit_unlocked(def_id):
			_error("Unit locked")
			return
		def = _effective_def(def_id)
	else:
		def = unit_defs[def_id]

	if team == PLAYER and economy_enabled:
		var cost := int(def.get("cost", 0))
		var pop := int(def.get("pop", 1))
		if gold < cost:
			_error("Not enough gold")
			return
		if get_pop_used() + pop > pop_max:
			_error("Recruitment cap reached")
			return
		var cd := float(spawn_cd[lane].get(def_id, 0.0))
		if cd > 0.0:
			_error("Unit on cooldown")
			return
		gold -= cost
		gold_spent_units += cost
		spawn_cd[lane][def_id] = float(def.get("cooldown", 3.0))
		var guild_id := String(def.get("guild", ""))
		guild_usage[guild_id] = int(guild_usage.get(guild_id, 0)) + 1

	var spawn_x := player_base_x + 12.0 if team == PLAYER else enemy_base_x - 12.0
	var unit := SimUnit.new(next_id, team, lane, def_id, def, spawn_x, elite, is_target)
	unit.spawn_wave = wave_number
	unit.slot = _next_slot(team, lane)

	if team == PLAYER:
		unit.x -= unit.slot * 6.0
	else:
		unit.x += unit.slot * 6.0
	unit.x = clampf(unit.x, player_base_x, enemy_base_x)
	unit.manual_order = false
	unit.hold_position = false
	unit.at_base = false
	unit.move_target_x = float(advance_lines[lane]) if team == PLAYER else player_base_x

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
		wave_message = String(wave.get("message", ""))
		message_timer = 4.0
		next_wave_index += 1


func _spawn_wave(wave: Dictionary, wave_number: int) -> void:
	if economy_enabled:
		gold += float(data.get_balance("wave_gold_base", 30)) + float(data.get_balance("wave_gold_per_wave", 5)) * wave_number
	var default_lane := int(wave.get("lane", 0))
	for spawn in wave.get("spawns", []):
		var lane := int(spawn.get("lane", default_lane))
		var unit_id := String(spawn.get("unit", "swordsman"))
		var count := int(spawn.get("count", 1))
		var elite := bool(spawn.get("elite", false))
		var target := bool(spawn.get("target", false))
		for i in range(count):
			_spawn_unit(ENEMY, lane, unit_id, elite, target, wave_number)


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
	wave_message = "Endless wave %d" % endless_wave
	message_timer = 3.0


func _spawn_endless_wave(wave_number: int) -> void:
	if economy_enabled:
		gold += 30.0 + 5.0 * wave_number
	var budget := float(data.get_balance("endless_budget_base", 40.0)) + float(data.get_balance("endless_budget_per_wave", 14.0)) * wave_number + float(data.get_balance("endless_budget_quadratic", 1.2)) * wave_number * wave_number
	var spent := 0.0
	var spawned := 0
	var target_spawned := false
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
		var lane := rng.randi_range(0, lane_count - 1)
		var elite := rng.randf() < minf(0.25, 0.04 + 0.01 * wave_number)
		var mark_target := wave_number % 3 == 0 and not target_spawned
		_spawn_unit(ENEMY, lane, def_id, elite, mark_target, wave_number)
		if mark_target:
			target_spawned = true
		spent += cost
		spawned += 1
	if spawned == 0:
		_spawn_unit(ENEMY, 0, "swordsman", false, false)


func _next_slot(team: int, lane: int) -> int:
	var count := 0
	for u in units:
		if u.alive and u.team == team and u.lane == lane:
			count += 1
	return count % 3


func _update_unit(u: SimUnit, dt: float) -> void:
	u.attack_cd = maxf(0.0, u.attack_cd - dt)
	u.combat_cooldown = maxf(0.0, u.combat_cooldown - dt)
	_update_heal(u, dt)

	var previous_target := u.target_id
	var target := _find_target(u)
	if target == null and previous_target >= 0:
		u.combat_cooldown = 0.35
	var moved := false

	if target != null and absf(target.x - u.x) <= u.attack_range:
		u.state = "attack"
		u.target_id = target.id
		u.stationary_time += dt
		if u.attack_cd <= 0.0:
			_perform_attack(u, target)
			u.attack_cd = _attack_interval(u)
	elif u.hold_position:
		u.state = "hold"
		u.target_id = target.id if target != null else -1
		u.stationary_time += dt
	elif target != null:
		u.state = "engage"
		u.target_id = target.id
		moved = _move_unit(u, target.x, dt)
		if moved:
			u.stationary_time = 0.0
		else:
			u.stationary_time += dt
	elif u.combat_cooldown > 0.0:
		u.state = "hold"
		u.target_id = -1
		u.stationary_time += dt
	else:
		u.state = "advance"
		u.target_id = -1
		var goal := player_base_x
		if u.team == PLAYER:
			goal = u.move_target_x if u.manual_order else float(advance_lines[u.lane])
		moved = _move_unit(u, goal, dt)
		if moved:
			u.stationary_time = 0.0
		else:
			u.stationary_time += dt
			u.state = "hold"

	_check_base_arrival(u)


func _update_heal(u: SimUnit, dt: float) -> void:
	if u.heal_amount <= 0.0:
		return
	u.heal_cd = maxf(0.0, u.heal_cd - dt)
	if u.heal_cd > 0.0:
		return
	var best: SimUnit = null
	var best_ratio := 1.0
	for e in units:
		if not e.alive or e.team != u.team or e.lane != u.lane or e.hp >= e.max_hp:
			continue
		if absf(e.x - u.x) > u.heal_range:
			continue
		var ratio: float = float(e.hp) / maxf(1.0, float(e.max_hp))
		if ratio < best_ratio:
			best_ratio = ratio
			best = e
	if best != null:
		best.hp = minf(best.max_hp, best.hp + u.heal_amount)
		u.heal_cd = u.heal_interval


func _move_unit(u: SimUnit, goal_x: float, dt: float) -> bool:
	var step := u.speed * dt
	var delta := goal_x - u.x
	if absf(delta) <= maxf(1.0, step):
		u.x = goal_x
		return false
	u.x = clampf(u.x + signf(delta) * step, player_base_x, enemy_base_x)
	return true


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
		_apply_damage(target, dmg, u.team)


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
	p.lane = u.lane
	p.x = u.x
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
		var delta_x: float = target.x - float(p.x)
		p.x += float(p.speed) * dt * signf(delta_x)
		if absf(target.x - float(p.x)) <= 8.0:
			_apply_damage(target, float(p.damage), int(p.team))
			if String(p.source_passive) == "splash":
				_apply_splash(p, target)
			p.done = true

	var alive_projectiles: Array = []
	for p in projectiles:
		if not p.done:
			alive_projectiles.append(p)
	projectiles = alive_projectiles


func _apply_splash(p: SimProjectile, primary: SimUnit) -> void:
	var radius := float(data.get_balance("splash_radius", 50.0))
	var ratio := float(data.get_balance("splash_ratio", 0.5))
	for e in units:
		if not e.alive or e.team == p.team or e.lane != p.lane or e.id == primary.id:
			continue
		if absf(e.x - primary.x) <= radius:
			var mult := _damage_multiplier(String(p.attack_type), String(p.source_passive), e)
			_apply_damage(e, float(p.source_damage) * mult * ratio, int(p.team))


func _apply_damage(target: SimUnit, amount: float, source_team: int) -> void:
	if not target.alive:
		return
	target.hp -= amount
	if target.hp <= 0.0:
		target.hp = 0.0
		target.alive = false
		_on_unit_killed(target, source_team)


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


func _find_target(u: SimUnit) -> SimUnit:
	if u.target_id >= 0:
		var current := _unit_by_id(u.target_id)
		if current != null and current.alive and current.lane == u.lane and current.team != u.team:
			if absf(current.x - u.x) <= u.aggro_range * 1.3:
				return current

	var best: SimUnit = null
	var best_dist := INF
	for e in units:
		if not e.alive or e.team == u.team or e.lane != u.lane:
			continue
		var dist := absf(e.x - u.x)
		if dist > u.aggro_range:
			continue
		if best == null or dist < best_dist or (is_equal_approx(dist, best_dist) and e.id < best.id):
			best = e
			best_dist = dist
	return best


func _check_base_arrival(u: SimUnit) -> void:
	if u.team == PLAYER and u.x >= enemy_base_x - 8.0:
		if defense_mode:
			u.x = enemy_base_x - 8.0
			u.state = "hold"
			u.hold_position = true
			u.at_base = true
		else:
			base_hp[ENEMY] = maxi(0, int(base_hp[ENEMY]) - base_damage)
			u.alive = false
	elif u.team == ENEMY and u.x <= player_base_x + 8.0:
		leaks_by_unit[u.def_id] = int(leaks_by_unit.get(u.def_id, 0)) + 1
		if u.lane >= 0 and u.lane < leaks_by_lane.size():
			leaks_by_lane[u.lane] = int(leaks_by_lane[u.lane]) + 1
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
	units = alive_units


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


func _next_wave_in() -> float:
	if next_wave_index >= waves.size():
		return 0.0
	return maxf(0.0, float(waves[next_wave_index].get("time", 0.0)) - elapsed)


func _next_wave_preview() -> Dictionary:
	if endless_mode or next_wave_index >= waves.size():
		return {}
	var wave: Dictionary = waves[next_wave_index]
	var by_lane := {}
	for spawn in wave.get("spawns", []):
		var lane := int(spawn.get("lane", wave.get("lane", 0)))
		var def_id := String(spawn.get("unit", "swordsman"))
		var def: Dictionary = unit_defs.get(def_id, {})
		if not by_lane.has(lane):
			by_lane[lane] = {}
		var key := def_id + ":" + str(bool(spawn.get("target", false)))
		var entry: Dictionary = by_lane[lane].get(key, {
			"id": def_id,
			"count": 0,
			"role": String(def.get("role", "")),
			"attack_type": String(def.get("attack_type", "")),
			"armor_type": String(def.get("armor_type", "")),
			"target": bool(spawn.get("target", false)),
		})
		entry["count"] = int(entry["count"]) + int(spawn.get("count", 1))
		by_lane[lane][key] = entry
	var lanes: Array = []
	var lane_ids: Array = by_lane.keys()
	lane_ids.sort()
	for lane in lane_ids:
		var units: Array = []
		for entry in by_lane[lane].values():
			units.append(entry)
		lanes.append({"lane": int(lane), "units": units})
	return {
		"time": float(wave.get("time", 0.0)),
		"message": String(wave.get("message", "")),
		"lanes": lanes,
	}


func _result_stats() -> Dictionary:
	var final_comp := {}
	for u in units:
		if u.alive and u.team == PLAYER:
			final_comp[u.def_id] = int(final_comp.get(u.def_id, 0)) + 1
	return {
		"leaks_by_unit": leaks_by_unit.duplicate(),
		"leaks_by_lane": leaks_by_lane.duplicate(),
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
		var requirement := "" if unlocked else "%s T%d" % [String(guild_defs.get(guild_id, {}).get("short", guild_id)), tier_needed]
		if not _guild_is_unlocked(guild_id):
			requirement = "GUILD LOCK"
		result.append({
			"id": def_id,
			"name": String(base.get("display_name", def_id)),
			"guild": guild_id,
			"guild_name": String(guild_defs.get(guild_id, {}).get("short", guild_id)),
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
		var next_rank_gate := 0
		if next_tier < tiers.size():
			next_cost = int(tiers[next_tier].get("cost", 0))
			next_cap = int(tiers[next_tier].get("cap", 0))
			next_units = tiers[next_tier].get("units", [])
			next_rank_gate = int(tiers[next_tier].get("rank_gate", 0))
		result.append({
			"id": guild_id,
			"name": String(guild.get("name", guild_id)),
			"short": String(guild.get("short", guild_id)),
			"unlocked": _guild_is_unlocked(guild_id),
			"tier": tier,
			"max_tier": tiers.size() - 1,
			"next_cost": next_cost,
			"next_cap": next_cap,
			"next_units": next_units,
			"rank_gate": next_rank_gate,
			"can_afford": economy_enabled and next_tier < tiers.size() and gold >= next_cost,
			"favor": int(guild_favor.get(guild_id, 0)),
			"usage": int(guild_usage.get(guild_id, 0)),
		})
	return result


func get_snapshot() -> Dictionary:
	var unit_data: Array = []
	for u in units:
		if not u.alive:
			continue
		unit_data.append({
			"id": u.id,
			"team": u.team,
			"lane": u.lane,
			"x": u.x,
			"hp": u.hp,
			"max_hp": u.max_hp,
			"def_id": u.def_id,
			"attack_type": u.attack_type,
			"state": u.state,
			"slot": u.slot,
			"target_id": u.target_id,
			"is_elite": u.is_elite,
			"is_target": u.is_target,
			"manual_order": u.manual_order,
			"hold_position": u.hold_position,
			"move_target_x": u.move_target_x,
		})

	var projectile_data: Array = []
	for p in projectiles:
		projectile_data.append({
			"id": p.id,
			"team": p.team,
			"lane": p.lane,
			"x": p.x,
			"target_id": p.target_id,
		})

	return {
		"tick": tick_count,
		"elapsed": elapsed,
		"base_hp": base_hp.duplicate(),
		"base_hp_max": base_hp_max,
		"base_damage": base_damage,
		"units": unit_data,
		"projectiles": projectile_data,
		"finished": finished,
		"winner": winner,
		"stars": get_stars(),
		"player_base_x": player_base_x,
		"enemy_base_x": enemy_base_x,
		"lane_count": lane_count,
		"world_width": 1600.0,
		"advance_lines": advance_lines.duplicate(),
		"level_name": String(level.get("name", "Sandbox")),
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
		"promo_kills": int(promo_kills[rep_rank]) if rep_rank < promo_kills.size() else 0,
		"promo_cost": int(promo_cost[rep_rank]) if rep_rank < promo_cost.size() else 0,
		"catalog": _catalog(),
		"guilds": _guild_snapshot(),
		"guild_usage": guild_usage.duplicate(),
		"cooldowns": [spawn_cd[0].duplicate(), spawn_cd[1].duplicate()],
		"wave_index": endless_wave if endless_mode else next_wave_index,
		"wave_count": 0 if endless_mode else wave_count,
		"next_wave_in": endless_timer if endless_mode else _next_wave_in(),
		"kills": kills,
		"score": (endless_wave * 100 + kills * 10 + int(base_hp[PLAYER]) * 50) if endless_mode else 0,
		"message": wave_message,
		"error": last_error,
		"mode": "endless" if endless_mode else ("defense" if defense_mode else "debug"),
	}
