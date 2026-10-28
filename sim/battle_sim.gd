class_name BattleSim
extends RefCounted

const PLAYER := 0
const ENEMY := 1
const TICK_DT := 0.05
const TICK_HZ := 20.0

const COUNTER := {
	"melee": {"light": 1.5, "heavy": 0.75},
	"ranged": {"light": 1.0, "heavy": 1.0},
	"siege": {"light": 0.5, "heavy": 1.5},
}

var seed: int = 1
var rng := RandomNumberGenerator.new()
var tick_count: int = 0
var units: Array = []
var projectiles: Array = []
var commands: Array = []
var unit_defs: Dictionary = {}
var next_id: int = 1
var next_projectile_id: int = 1

var base_hp: Array = [20, 20]
var base_hp_max: int = 20
var base_damage: int = 1
var player_base_x: float = 50.0
var enemy_base_x: float = 590.0
var lane_count: int = 2

var finished: bool = false
var winner: int = -1


func _init(p_seed: int = 1, p_base_hp: int = 20, p_base_damage: int = 1) -> void:
	seed = p_seed
	rng.seed = seed
	base_hp_max = p_base_hp
	base_hp = [p_base_hp, p_base_hp]
	base_damage = p_base_damage
	unit_defs = _load_unit_defs()


func _load_unit_defs() -> Dictionary:
	var path := "res://data/units.json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read unit data: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid unit data (expected dictionary): " + path)
		return {}
	return parsed


func queue_spawn(team: int, lane: int, def_id: String) -> void:
	if finished:
		return
	if not unit_defs.has(def_id):
		push_error("Unknown unit def: " + def_id)
		return
	if lane < 0 or lane >= lane_count:
		push_error("Invalid lane: %d" % lane)
		return
	commands.append({"type": "spawn", "team": team, "lane": lane, "def_id": def_id})


func tick() -> void:
	if finished:
		return
	_apply_commands()
	for u in units:
		if u.alive:
			_update_unit(u, TICK_DT)
	_update_projectiles(TICK_DT)
	_cleanup_dead()
	_check_finished()
	tick_count += 1


func _apply_commands() -> void:
	for cmd in commands:
		if cmd.get("type") == "spawn":
			_spawn_unit(int(cmd["team"]), int(cmd["lane"]), String(cmd["def_id"]))
	commands.clear()


func _spawn_unit(team: int, lane: int, def_id: String) -> void:
	var def: Dictionary = unit_defs[def_id]
	var spawn_x := player_base_x + 12.0 if team == PLAYER else enemy_base_x - 12.0
	var unit := SimUnit.new(next_id, team, lane, def_id, def, spawn_x)
	unit.slot = _next_slot(team, lane)
	# Stagger spawns slightly so stacked placeholders remain readable.
	if team == PLAYER:
		unit.x -= unit.slot * 6.0
	else:
		unit.x += unit.slot * 6.0
	unit.x = clampf(unit.x, player_base_x, enemy_base_x)
	next_id += 1
	units.append(unit)


func _next_slot(team: int, lane: int) -> int:
	var count := 0
	for u in units:
		if u.alive and u.team == team and u.lane == lane:
			count += 1
	return count % 3


func _update_unit(u: SimUnit, dt: float) -> void:
	u.attack_cd = maxf(0.0, u.attack_cd - dt)
	var target := _find_target(u)
	var moved := false

	if target != null and absf(target.x - u.x) <= u.attack_range:
		u.state = "attack"
		u.target_id = target.id
		u.stationary_time += dt
		if u.attack_cd <= 0.0:
			_perform_attack(u, target)
			u.attack_cd = _attack_interval(u)
	else:
		u.state = "advance"
		if target != null:
			u.target_id = target.id
			moved = _move_unit(u, target.x, dt)
		else:
			u.target_id = -1
			var goal := enemy_base_x if u.team == PLAYER else player_base_x
			moved = _move_unit(u, goal, dt)
		if moved:
			u.stationary_time = 0.0
		else:
			u.stationary_time += dt

	_check_base_arrival(u)


func _move_unit(u: SimUnit, goal_x: float, dt: float) -> bool:
	var delta_x := goal_x - u.x
	if absf(delta_x) <= 0.5:
		return false
	var old_x := u.x
	u.x = clampf(u.x + u.speed * dt * signf(delta_x), player_base_x, enemy_base_x)
	return not is_equal_approx(old_x, u.x)


func _attack_interval(u: SimUnit) -> float:
	var interval := u.attack_interval
	if u.passive == "volley" and u.stationary_time >= 1.5:
		interval *= 0.8
	return maxf(0.1, interval)


func _perform_attack(u: SimUnit, target: SimUnit) -> void:
	var mult := _damage_multiplier(u.attack_type, u.passive, target)
	var dmg := u.damage * mult

	if u.passive == "charge" and not u.charge_used:
		dmg *= 2.0
		u.charge_used = true

	if u.projectile_speed > 0.0:
		_spawn_projectile(u, target, dmg)
	else:
		_apply_damage(target, dmg)


func _damage_multiplier(attack_type: String, source_passive: String, target: SimUnit) -> float:
	var row: Dictionary = COUNTER.get(attack_type, {})
	var mult := float(row.get(target.armor_type, 1.0))

	if source_passive == "armor_pierce" and target.armor_type == "heavy":
		mult = maxf(mult, 1.25)
	if source_passive == "siege_master" and target.armor_type == "heavy":
		mult *= 1.25
	if target.passive == "shield_wall" and attack_type == "ranged":
		mult *= 0.7

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
			_apply_damage(target, float(p.damage))
			if String(p.source_passive) == "splash":
				_apply_splash(p, target)
			p.done = true

	var alive_projectiles: Array = []
	for p in projectiles:
		if not p.done:
			alive_projectiles.append(p)
	projectiles = alive_projectiles


func _apply_splash(p: SimProjectile, primary: SimUnit) -> void:
	for e in units:
		if not e.alive or e.team == p.team or e.lane != p.lane or e.id == primary.id:
			continue
		if absf(e.x - primary.x) <= 50.0:
			var mult := _damage_multiplier(String(p.attack_type), String(p.source_passive), e)
			_apply_damage(e, float(p.source_damage) * mult * 0.5)


func _apply_damage(target: SimUnit, amount: float) -> void:
	target.hp -= amount
	if target.hp <= 0.0:
		target.hp = 0.0
		target.alive = false


func _find_target(u: SimUnit) -> SimUnit:
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
		base_hp[ENEMY] = maxi(0, int(base_hp[ENEMY]) - base_damage)
		u.alive = false
	elif u.team == ENEMY and u.x <= player_base_x + 8.0:
		base_hp[PLAYER] = maxi(0, int(base_hp[PLAYER]) - base_damage)
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
	elif base_hp[ENEMY] <= 0:
		finished = true
		winner = PLAYER
	elif base_hp[PLAYER] <= 0:
		finished = true
		winner = ENEMY


func _unit_by_id(p_id: int) -> SimUnit:
	for u in units:
		if u.id == p_id:
			return u
	return null


func get_unit_by_id(p_id: int) -> SimUnit:
	return _unit_by_id(p_id)


func is_finished() -> bool:
	return finished


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
		"base_hp": base_hp.duplicate(),
		"base_hp_max": base_hp_max,
		"base_damage": base_damage,
		"units": unit_data,
		"projectiles": projectile_data,
		"finished": finished,
		"winner": winner,
		"player_base_x": player_base_x,
		"enemy_base_x": enemy_base_x,
		"lane_count": lane_count,
	}
