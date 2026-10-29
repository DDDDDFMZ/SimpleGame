class_name BattleSim
extends RefCounted

const PLAYER := 0
const ENEMY := 1
const TICK_DT := 0.05
const TICK_HZ := 20.0

const UNIT_ORDER := ["swordsman", "spearman", "archer", "mage", "knight", "catapult"]
const SLOT_TYPES := ["farm", "farm", "barracks", "barracks"]
const SLOT_LANES := [-1, -1, 0, 1]
const BASE_POP := 10

const BUILDING_DEFS := {
	"farm": {
		"build_cost": 50,
		"upgrade_cost": 60,
		"max_level": 2,
		"income": [0, 2, 3],
	},
	"barracks": {
		"build_cost": 60,
		"upgrade_cost": 70,
		"max_level": 2,
		"pop": [0, 4, 8],
		"cd_reduction": [0.0, 0.1, 0.2],
	},
}

const COUNTER := {
	"melee": {"light": 1.5, "heavy": 0.75},
	"ranged": {"light": 1.0, "heavy": 1.0},
	"siege": {"light": 0.5, "heavy": 1.5},
}

var seed: int = 1
var rng := RandomNumberGenerator.new()
var tick_count: int = 0
var elapsed: float = 0.0

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

var gold: float = 120.0
var base_income: float = 4.0
var income_per_sec: float = 4.0
var pop_max: int = BASE_POP
var buildings: Array = []
var spawn_cd: Array = [{}, {}]
var lane_cd_mult: Array = [1.0, 1.0]

var level: Dictionary = {}
var waves: Array = []
var next_wave_index: int = 0
var wave_count: int = 0
var wave_message: String = ""
var message_timer: float = 0.0
var last_error: String = ""
var error_timer: float = 0.0
var defense_mode: bool = false
var economy_enabled: bool = true

var finished: bool = false
var winner: int = -1


func _init(p_seed: int = 1, p_base_hp: int = 20, p_base_damage: int = 1, p_level: Dictionary = {}, p_economy: bool = true) -> void:
	seed = p_seed
	rng.seed = seed
	level = p_level
	economy_enabled = p_economy

	base_hp_max = int(level.get("base_hp", p_base_hp))
	base_damage = int(level.get("base_damage", p_base_damage))
	base_hp = [base_hp_max, base_hp_max]
	base_income = float(level.get("base_income", 4.0))
	gold = float(level.get("starting_gold", 120.0))

	waves = level.get("waves", [])
	wave_count = waves.size()
	defense_mode = String(level.get("mode", "")) == "defense"
	wave_message = String(level.get("intro_message", ""))
	message_timer = 4.0

	unit_defs = _load_unit_defs()
	buildings = []
	for i in range(4):
		buildings.append({"type": "", "level": 0})
	_recompute_economy()


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


func queue_build(slot: int) -> void:
	if finished:
		return
	if slot < 0 or slot >= 4:
		_error("Invalid building slot")
		return

	var building_type: String = SLOT_TYPES[slot]
	var allowed: Array = level.get("available_buildings", ["farm", "barracks"])
	if not allowed.has(building_type):
		_error("Building locked")
		return

	var b: Dictionary = buildings[slot]
	var def: Dictionary = BUILDING_DEFS[building_type]
	if int(b["level"]) >= int(def["max_level"]):
		_error("Max level")
		return

	var cost := int(def["build_cost"]) if int(b["level"]) == 0 else int(def["upgrade_cost"])
	if economy_enabled and gold < cost:
		_error("Not enough gold")
		return

	commands.append({"type": "build", "slot": slot})


func tick() -> void:
	if finished:
		return

	elapsed += TICK_DT
	_update_economy(TICK_DT)
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
	tick_count += 1


func _update_economy(dt: float) -> void:
	if economy_enabled:
		gold += income_per_sec * dt


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
			"build":
				_apply_build(int(cmd["slot"]))
	commands.clear()


func _spawn_unit(team: int, lane: int, def_id: String, elite: bool = false) -> void:
	if not unit_defs.has(def_id):
		_error("Unknown unit")
		return
	var def: Dictionary = unit_defs[def_id]

	if team == PLAYER and economy_enabled:
		var cost := int(def.get("cost", 0))
		var pop := int(def.get("pop", 1))
		if gold < cost:
			_error("Not enough gold")
			return
		if get_pop_used() + pop > pop_max:
			_error("Population full")
			return
		var cd := float(spawn_cd[lane].get(def_id, 0.0))
		if cd > 0.0:
			_error("Unit on cooldown")
			return
		gold -= cost
		spawn_cd[lane][def_id] = float(def.get("cooldown", 3.0)) * float(lane_cd_mult[lane])

	var spawn_x := player_base_x + 12.0 if team == PLAYER else enemy_base_x - 12.0
	var unit := SimUnit.new(next_id, team, lane, def_id, def, spawn_x, elite)
	unit.slot = _next_slot(team, lane)

	if team == PLAYER:
		unit.x -= unit.slot * 6.0
	else:
		unit.x += unit.slot * 6.0
	unit.x = clampf(unit.x, player_base_x, enemy_base_x)

	next_id += 1
	units.append(unit)


func _apply_build(slot: int) -> void:
	var building_type: String = SLOT_TYPES[slot]
	var b: Dictionary = buildings[slot]
	var def: Dictionary = BUILDING_DEFS[building_type]
	var level_now := int(b["level"])
	if level_now >= int(def["max_level"]):
		_error("Max level")
		return

	var cost := int(def["build_cost"]) if level_now == 0 else int(def["upgrade_cost"])
	if economy_enabled and gold < cost:
		_error("Not enough gold")
		return

	if economy_enabled:
		gold -= cost
	b["type"] = building_type
	b["level"] = level_now + 1
	_recompute_economy()


func _recompute_economy() -> void:
	income_per_sec = base_income
	pop_max = BASE_POP
	lane_cd_mult = [1.0, 1.0]

	for i in range(4):
		var b: Dictionary = buildings[i]
		var building_type := String(b["type"])
		var level_now := int(b["level"])
		if level_now <= 0 or not BUILDING_DEFS.has(building_type):
			continue
		var def: Dictionary = BUILDING_DEFS[building_type]
		if building_type == "farm":
			income_per_sec += float(def["income"][level_now])
		elif building_type == "barracks":
			pop_max += int(def["pop"][level_now])
			var lane := int(SLOT_LANES[i])
			lane_cd_mult[lane] = maxf(0.5, float(lane_cd_mult[lane]) - float(def["cd_reduction"][level_now]))


func _update_waves() -> void:
	while next_wave_index < waves.size():
		var wave: Dictionary = waves[next_wave_index]
		if float(wave.get("time", 0.0)) > elapsed:
			break
		_spawn_wave(wave)
		wave_message = String(wave.get("message", ""))
		message_timer = 4.0
		next_wave_index += 1


func _spawn_wave(wave: Dictionary) -> void:
	var default_lane := int(wave.get("lane", 0))
	for spawn in wave.get("spawns", []):
		var lane := int(spawn.get("lane", default_lane))
		var unit_id := String(spawn.get("unit", "swordsman"))
		var count := int(spawn.get("count", 1))
		var elite := bool(spawn.get("elite", false))
		for i in range(count):
			_spawn_unit(ENEMY, lane, unit_id, elite)


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
		_apply_damage(target, dmg, u.team)


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
	for e in units:
		if not e.alive or e.team == p.team or e.lane != p.lane or e.id == primary.id:
			continue
		if absf(e.x - primary.x) <= 50.0:
			var mult := _damage_multiplier(String(p.attack_type), String(p.source_passive), e)
			_apply_damage(e, float(p.source_damage) * mult * 0.5, int(p.team))


func _apply_damage(target: SimUnit, amount: float, source_team: int) -> void:
	if not target.alive:
		return
	target.hp -= amount
	if target.hp <= 0.0:
		target.hp = 0.0
		target.alive = false
		_on_unit_killed(target, source_team)


func _on_unit_killed(target: SimUnit, source_team: int) -> void:
	if not economy_enabled:
		return
	if target.team == ENEMY and source_team == PLAYER:
		var cost := float(target.def.get("cost", 0))
		var ratio := 0.3 if target.is_elite else 0.2
		gold += maxf(1.0, cost * ratio)


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
		if defense_mode:
			u.x = enemy_base_x - 8.0
			u.state = "hold"
		else:
			base_hp[ENEMY] = maxi(0, int(base_hp[ENEMY]) - base_damage)
			u.alive = false
	elif u.team == ENEMY and u.x <= player_base_x + 8.0:
		var dmg := 2 if u.is_elite else base_damage
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


func _error(text: String) -> void:
	last_error = text
	error_timer = 2.5


func _next_wave_in() -> float:
	if next_wave_index >= waves.size():
		return 0.0
	return maxf(0.0, float(waves[next_wave_index].get("time", 0.0)) - elapsed)


func _catalog() -> Array:
	var result: Array = []
	for def_id in UNIT_ORDER:
		if not unit_defs.has(def_id):
			continue
		var def: Dictionary = unit_defs[def_id]
		result.append({
			"id": def_id,
			"name": String(def.get("display_name", def_id)),
			"cost": int(def.get("cost", 0)),
			"pop": int(def.get("pop", 1)),
		})
	return result


func _building_snapshot() -> Array:
	var result: Array = []
	for i in range(4):
		var b: Dictionary = buildings[i]
		var building_type: String = String(b["type"]) if String(b["type"]) != "" else String(SLOT_TYPES[i])
		var level_now := int(b["level"])
		var def: Dictionary = BUILDING_DEFS[building_type]
		var max_level := int(def["max_level"])
		var next_cost := 0
		if level_now < max_level:
			next_cost = int(def["build_cost"]) if level_now == 0 else int(def["upgrade_cost"])
		result.append({
			"slot": i,
			"type": building_type,
			"level": level_now,
			"max_level": max_level,
			"next_cost": next_cost,
			"can_afford": economy_enabled and level_now < max_level and gold >= next_cost,
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
		"player_base_x": player_base_x,
		"enemy_base_x": enemy_base_x,
		"lane_count": lane_count,
		"gold": int(floor(gold)),
		"gold_exact": gold,
		"income": income_per_sec,
		"pop_used": get_pop_used(),
		"pop_max": pop_max,
		"catalog": _catalog(),
		"cooldowns": [spawn_cd[0].duplicate(), spawn_cd[1].duplicate()],
		"buildings": _building_snapshot(),
		"wave_index": next_wave_index,
		"wave_count": wave_count,
		"next_wave_in": _next_wave_in(),
		"message": wave_message,
		"error": last_error,
		"mode": "defense" if defense_mode else "debug",
	}
