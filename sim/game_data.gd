class_name GameData
extends RefCounted

const UNITS_PATH := "res://data/units.json"
const GUILDS_PATH := "res://data/guilds.json"
const BALANCE_PATH := "res://data/balance.json"
const COUNTERS_PATH := "res://data/counters.json"
const CAMPAIGN_PATH := "res://data/campaign.json"

const VALID_ATTACK_TYPES := ["melee", "ranged", "siege"]
const VALID_ARMOR_TYPES := ["light", "heavy"]
const REQUIRED_UNIT_FIELDS := [
	"display_name_cn", "guild", "relation_tier", "role", "cost", "pop",
	"hp", "damage", "attack_interval", "range", "speed", "attack_type",
	"armor_type", "body_width", "body_height", "station_rank", "sort_order",
]
const REQUIRED_GUILD_FIELDS := [
	"name_cn", "short_cn", "identity_cn", "unlock_after", "sort_order", "tiers",
]
const REQUIRED_TIER_FIELDS := ["cost", "cap", "rank_gate"]
const REQUIRED_BALANCE := [
	"base_pop", "pop_per_rank", "promo_kills", "promo_cost",
	"wave_gold_base", "wave_gold_per_wave", "target_gold",
	"bounty_ratio", "elite_bounty_ratio", "favor_hp_damage_per_point",
	"favor_cost_per_point", "favor_cap", "endless_budget_base",
	"endless_budget_per_wave", "endless_budget_quadratic",
	"road_slot_width", "road_slot_padding", "squad_spacing",
	"squad_slot_tolerance", "squad_regroup_distance",
	"assist_radius", "vision_radius",
]
const NUMERIC_BALANCE := [
	"base_pop", "pop_per_rank", "wave_gold_base", "wave_gold_per_wave",
	"target_gold", "bounty_ratio", "elite_bounty_ratio",
	"favor_hp_damage_per_point", "favor_cost_per_point", "favor_cap",
	"endless_budget_base", "endless_budget_per_wave", "endless_budget_quadratic",
	"road_slot_width", "road_slot_padding", "squad_spacing",
	"squad_slot_tolerance", "squad_regroup_distance",
	"assist_radius", "vision_radius", "elite_base_damage",
	"shield_wall_ranged_mult", "armor_pierce_heavy_mult",
	"siege_master_heavy_mult", "backstab_ranged_mult",
	"volley_interval_mult", "charge_damage_mult", "splash_ratio",
	"splash_radius", "threshold_2", "threshold_3",
	"road_capacity_px_per_unit", "road_capacity_max", "station_spacing",
]
const ARRAY_BALANCE := ["promo_kills", "promo_cost"]
const KNOWN_BALANCE := [
	"base_pop", "pop_per_rank", "promo_kills", "promo_cost",
	"wave_gold_base", "wave_gold_per_wave", "target_gold",
	"bounty_ratio", "elite_bounty_ratio", "favor_hp_damage_per_point",
	"favor_cost_per_point", "favor_cap", "endless_budget_base",
	"endless_budget_per_wave", "endless_budget_quadratic",
	"road_slot_width", "road_slot_padding", "squad_spacing",
	"squad_slot_tolerance", "squad_regroup_distance",
	"assist_radius", "vision_radius", "elite_base_damage",
	"shield_wall_ranged_mult", "armor_pierce_heavy_mult",
	"siege_master_heavy_mult", "backstab_ranged_mult",
	"volley_interval_mult", "charge_damage_mult", "splash_ratio",
	"splash_radius", "threshold_2", "threshold_3",
	"road_capacity_px_per_unit", "road_capacity_max", "station_spacing",
]

var units_path: String = UNITS_PATH
var guilds_path: String = GUILDS_PATH
var balance_path: String = BALANCE_PATH
var counters_path: String = COUNTERS_PATH
var campaign_path: String = CAMPAIGN_PATH

var unit_defs: Dictionary = {}
var unit_order: Array = []
var guild_defs: Dictionary = {}
var guild_order: Array = []
var balance: Dictionary = {}
var counters: Dictionary = {}
var campaign: Dictionary = {}
var level_paths: Dictionary = {}
var level_defs: Dictionary = {}
var map_defs: Dictionary = {}
var unlock_guilds: Array = []
var endless_path: String = ""
var errors: Array = []


func configure_paths(p_units: String = UNITS_PATH, p_guilds: String = GUILDS_PATH, p_balance: String = BALANCE_PATH, p_counters: String = COUNTERS_PATH, p_campaign: String = CAMPAIGN_PATH) -> void:
	units_path = p_units
	guilds_path = p_guilds
	balance_path = p_balance
	counters_path = p_counters
	campaign_path = p_campaign


func load_all() -> bool:
	errors.clear()
	unit_defs.clear()
	unit_order.clear()
	guild_defs.clear()
	guild_order.clear()
	balance.clear()
	counters.clear()
	level_paths.clear()
	level_defs.clear()
	map_defs.clear()
	unlock_guilds.clear()

	_load_units()
	_load_guilds()
	_load_balance()
	_load_counters()
	_load_campaign()
	_load_maps()
	_validate()

	if not errors.is_empty():
		for err in errors:
			push_error("GameData: " + String(err))
		return false
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("%s: file missing" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: file empty" % path)
		return {}
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: top level must be an object" % path)
		return {}
	return json.data


func _as_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and String(value).is_valid_int():
		return int(String(value))
	return fallback


func _as_float(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		return float(value)
	if value is String and String(value).is_valid_float():
		return float(String(value))
	return fallback


func _as_bool(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return int(value) != 0
	if value is String:
		return String(value).strip_edges().to_lower() in ["true", "1", "yes"]
	return fallback


func _load_units() -> void:
	var source := _read_json(units_path)
	for key in source:
		var def_id := String(key).strip_edges()
		if def_id == "":
			errors.append("%s: empty unit id" % units_path)
			continue
		var row: Variant = source[key]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("%s.%s: unit must be an object" % [units_path, def_id])
			continue
		var d: Dictionary = row
		for field in REQUIRED_UNIT_FIELDS:
			if not d.has(field):
				errors.append("%s.%s: missing field %s" % [units_path, def_id, field])
		var sort_order := _as_int(d.get("sort_order"), unit_order.size())
		var def := {
			"id": def_id,
			"name_key": String(d.get("name_key", "")),
			"display_name": String(d.get("display_name", def_id)),
			"display_name_cn": String(d.get("display_name_cn", d.get("display_name", def_id))),
			"guild": String(d.get("guild", "")),
			"relation_tier": _as_int(d.get("relation_tier"), 0),
			"role": String(d.get("role", "")),
			"recruitable": _as_bool(d.get("recruitable"), true),
			"cost": _as_int(d.get("cost"), 0),
			"pop": _as_int(d.get("pop"), 1),
			"hp": _as_float(d.get("hp"), 100.0),
			"damage": _as_float(d.get("damage"), 10.0),
			"attack_interval": _as_float(d.get("attack_interval"), 1.0),
			"range": _as_float(d.get("range"), 24.0),
			"speed": _as_float(d.get("speed"), 50.0),
			"attack_type": String(d.get("attack_type", "melee")),
			"armor_type": String(d.get("armor_type", "light")),
			"passive": String(d.get("passive", "")),
			"projectile_speed": _as_float(d.get("projectile_speed"), 0.0),
			"cooldown": _as_float(d.get("cooldown"), 3.0),
			"heal_amount": _as_float(d.get("heal_amount"), 0.0),
			"heal_interval": _as_float(d.get("heal_interval"), 0.0),
			"heal_range": _as_float(d.get("heal_range"), 0.0),
			"body_width": _as_float(d.get("body_width"), 14.0),
			"body_height": _as_float(d.get("body_height"), 20.0),
			"station_rank": _as_int(d.get("station_rank"), sort_order),
			"sort_order": sort_order,
			"notes": String(d.get("notes", "")),
		}
		unit_defs[def_id] = def
		unit_order.append({"id": def_id, "sort_order": sort_order})
	unit_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sort_order"]) == int(b["sort_order"]):
			return String(a["id"]) < String(b["id"])
		return int(a["sort_order"]) < int(b["sort_order"])
	)
	var ordered_ids: Array = []
	for entry in unit_order:
		ordered_ids.append(String(entry["id"]))
	unit_order = ordered_ids


func _load_guilds() -> void:
	var source := _read_json(guilds_path)
	for key in source:
		var guild_id := String(key).strip_edges()
		if guild_id == "":
			continue
		var row: Variant = source[key]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("%s.%s: guild must be an object" % [guilds_path, guild_id])
			continue
		var d: Dictionary = row
		for field in REQUIRED_GUILD_FIELDS:
			if not d.has(field):
				errors.append("%s.%s: missing field %s" % [guilds_path, guild_id, field])
		var tiers: Array = []
		var raw_tiers: Variant = d.get("tiers", [])
		if raw_tiers is Array:
			for raw_tier in raw_tiers:
				if typeof(raw_tier) != TYPE_DICTIONARY:
					errors.append("%s.%s: tier must be an object" % [guilds_path, guild_id])
					continue
				var tier: Dictionary = raw_tier
				for field in REQUIRED_TIER_FIELDS:
					if not tier.has(field):
						errors.append("%s.%s: tier missing field %s" % [guilds_path, guild_id, field])
				tiers.append({
					"cost": _as_int(tier.get("cost"), 0),
					"cap": _as_int(tier.get("cap"), 0),
					"rank_gate": _as_int(tier.get("rank_gate"), 0),
					"units": [],
				})
		guild_defs[guild_id] = {
			"id": guild_id,
			"name": String(d.get("name", guild_id)),
			"name_cn": String(d.get("name_cn", d.get("name", guild_id))),
			"short": String(d.get("short", guild_id)),
			"short_cn": String(d.get("short_cn", d.get("short", guild_id))),
			"identity_cn": String(d.get("identity_cn", "")),
			"unlock_after": _as_int(d.get("unlock_after"), 0),
			"sort_order": _as_int(d.get("sort_order"), 0),
			"tiers": tiers,
		}
	for def_id in unit_order:
		var def: Dictionary = unit_defs[String(def_id)]
		var guild_id := String(def.get("guild", ""))
		if not bool(def.get("recruitable", true)) or not guild_defs.has(guild_id):
			continue
		var tier_index := int(def.get("relation_tier", 0))
		var tiers: Array = guild_defs[guild_id]["tiers"]
		if tier_index >= 0 and tier_index < tiers.size():
			tiers[tier_index]["units"].append(String(def_id))
	var sortable: Array = []
	for guild_id in guild_defs:
		sortable.append({"id": guild_id, "sort_order": int(guild_defs[guild_id]["sort_order"])})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sort_order"]) == int(b["sort_order"]):
			return String(a["id"]) < String(b["id"])
		return int(a["sort_order"]) < int(b["sort_order"])
	)
	guild_order.clear()
	for entry in sortable:
		guild_order.append(String(entry["id"]))


func _load_balance() -> void:
	var source := _read_json(balance_path)
	for key in source:
		var value: Variant = source[key]
		if String(key) in ["promo_kills", "promo_cost"] and value is Array:
			var ints: Array = []
			for item in value:
				ints.append(_as_int(item))
			value = ints
		balance[String(key)] = value


func _load_counters() -> void:
	var source := _read_json(counters_path)
	for key in source:
		var row: Variant = source[key]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("%s.%s: counter row must be an object" % [counters_path, String(key)])
			continue
		var d: Dictionary = row
		counters[String(key)] = {
			"light": _as_float(d.get("light"), 1.0),
			"heavy": _as_float(d.get("heavy"), 1.0),
		}


func _load_campaign() -> void:
	var parsed := _read_json(campaign_path)
	if parsed.is_empty():
		return
	campaign = parsed
	for level in campaign.get("levels", []):
		var contract := int(level.get("contract", 0))
		var path := String(level.get("path", ""))
		if contract <= 0 or path == "":
			errors.append("%s: invalid level entry" % campaign_path)
			continue
		level_paths[contract] = path
		if not FileAccess.file_exists(path):
			errors.append("%s: level path missing %s" % [campaign_path, path])
	for unlock in campaign.get("unlock_guilds", []):
		unlock_guilds.append({
			"after_contract": int(unlock.get("after_contract", 0)),
			"guild": String(unlock.get("guild", "")),
		})
	var endless: Dictionary = campaign.get("endless", {})
	endless_path = String(endless.get("path", ""))
	if endless_path == "":
		errors.append("%s: endless.path missing" % campaign_path)
	elif not FileAccess.file_exists(endless_path):
		errors.append("%s: endless path missing %s" % [campaign_path, endless_path])


func _load_maps() -> void:
	var level_files: Array = []
	for level_path in level_paths.values():
		level_files.append(String(level_path))
	if endless_path != "":
		level_files.append(endless_path)
	for level_path in level_files:
		if level_defs.has(level_path):
			continue
		var level := _read_json(level_path)
		level_defs[level_path] = level
		if level.is_empty():
			continue
		var map_path := String(level.get("map", ""))
		if map_path == "":
			errors.append("%s: level has no map path" % level_path)
			continue
		if map_defs.has(map_path):
			continue
		var map := MapData.load_file(map_path)
		map_defs[map_path] = map
		for map_error in map.errors:
			errors.append("%s: %s" % [map_path, String(map_error)])


func map_for_level(level: Dictionary) -> MapData:
	var map_path := String(level.get("map", ""))
	if map_path == "":
		return MapData.new()
	if map_defs.has(map_path):
		return map_defs[map_path]
	var map := MapData.load_file(map_path)
	map_defs[map_path] = map
	return map


func _validate() -> void:
	var seen_units := {}
	for def_id in unit_order:
		var def: Dictionary = unit_defs[String(def_id)]
		if seen_units.has(def_id):
			errors.append("%s.%s: duplicate unit" % [units_path, def_id])
		seen_units[def_id] = true
		if not VALID_ATTACK_TYPES.has(String(def.get("attack_type", ""))):
			errors.append("%s.%s: bad attack_type" % [units_path, def_id])
		if not VALID_ARMOR_TYPES.has(String(def.get("armor_type", ""))):
			errors.append("%s.%s: bad armor_type" % [units_path, def_id])
		if float(def.get("body_width", 0.0)) <= 0.0 or float(def.get("body_height", 0.0)) <= 0.0:
			errors.append("%s.%s: body size must be positive" % [units_path, def_id])
		if bool(def.get("recruitable", true)) and not guild_defs.has(String(def.get("guild", ""))):
			errors.append("%s.%s: unknown guild" % [units_path, def_id])
		if bool(def.get("recruitable", true)):
			var guild_id := String(def.get("guild", ""))
			if guild_defs.has(guild_id):
				var tier_count := (guild_defs[guild_id]["tiers"] as Array).size()
				var relation_tier := int(def.get("relation_tier", 0))
				if relation_tier < 0 or relation_tier >= tier_count:
					errors.append("%s.%s: relation_tier outside guild tiers" % [units_path, def_id])
	for guild_id in guild_order:
		var tiers: Array = guild_defs[guild_id]["tiers"]
		if tiers.is_empty():
			errors.append("%s.%s: no tiers" % [guilds_path, guild_id])
		var previous_gate := 0
		for i in range(tiers.size()):
			var tier: Dictionary = tiers[i]
			if tier.is_empty():
				errors.append("%s.%s: missing tier %d" % [guilds_path, guild_id, i])
				continue
			if int(tier.get("cost", 0)) < 0 or int(tier.get("cap", 0)) < 0:
				errors.append("%s.%s tier %d: negative cost/cap" % [guilds_path, guild_id, i])
			var gate := int(tier.get("rank_gate", 0))
			if gate < previous_gate or gate < 0:
				errors.append("%s.%s tier %d: rank_gate must be non-decreasing" % [guilds_path, guild_id, i])
			previous_gate = gate
	for unlock in unlock_guilds:
		if not guild_defs.has(String(unlock.get("guild", ""))):
			errors.append("%s: unlock references unknown guild %s" % [campaign_path, String(unlock.get("guild", ""))])
	for key in REQUIRED_BALANCE:
		if not balance.has(key):
			errors.append("%s: missing key %s" % [balance_path, key])
	for key in balance:
		if not KNOWN_BALANCE.has(String(key)):
			errors.append("%s: unknown key %s" % [balance_path, String(key)])
	for key in NUMERIC_BALANCE:
		if balance.has(key):
			var numeric_value: Variant = balance[key]
			if not (numeric_value is int or numeric_value is float):
				errors.append("%s: %s must be numeric" % [balance_path, key])
	for key in ARRAY_BALANCE:
		if balance.has(key):
			var array_value: Variant = balance[key]
			if not (array_value is Array):
				errors.append("%s: %s must be an array" % [balance_path, key])
			elif (array_value as Array).is_empty():
				errors.append("%s: %s must not be empty" % [balance_path, key])
			else:
				for item in array_value:
					if not (item is int or item is float) or int(item) <= 0:
						errors.append("%s: %s must contain positive numbers" % [balance_path, key])
						break
	for attack_type in VALID_ATTACK_TYPES:
		if not counters.has(attack_type):
			errors.append("%s: missing attack_type %s" % [counters_path, attack_type])
	for attack_type in counters:
		if not VALID_ATTACK_TYPES.has(String(attack_type)):
			errors.append("%s: bad attack_type %s" % [counters_path, attack_type])
		for armor in ["light", "heavy"]:
			if float(counters[attack_type].get(armor, 0.0)) <= 0.0:
				errors.append("%s: non-positive multiplier %s/%s" % [counters_path, attack_type, armor])
	if map_defs.is_empty():
		errors.append("没有加载任何地图")
	for level_path in level_defs:
		var level: Dictionary = level_defs[level_path]
		var map_path := String(level.get("map", ""))
		var map: MapData = map_defs.get(map_path, null)
		if map == null:
			continue
		var enemy_routes := map.spawns_for_team(1)
		for wave in level.get("waves", []):
			var default_route: Variant = wave.get("route", wave.get("lane", 0))
			for spawn in wave.get("spawns", []):
				var route_value: Variant = spawn.get("route", spawn.get("lane", default_route))
				if not _route_value_exists(enemy_routes, route_value):
					errors.append("%s: wave route %s is invalid" % [level_path, str(route_value)])
				var unit_id := String(spawn.get("unit", ""))
				if unit_id != "" and not unit_defs.has(unit_id):
					errors.append("%s: unknown wave unit %s" % [level_path, unit_id])


func _route_value_exists(routes: Array, value: Variant) -> bool:
	if value is String:
		for route in routes:
			if String(route.get("id", "")) == String(value):
				return true
		return false
	if value is int or value is float:
		return int(value) >= 0 and int(value) < routes.size()
	return false


func get_balance(key: String, default_value: Variant = 0) -> Variant:
	return balance.get(key, default_value)


func get_level_path(contract: int) -> String:
	return String(level_paths.get(contract, ""))


func get_max_contract() -> int:
	var maximum := 0
	for contract in level_paths:
		maximum = maxi(maximum, int(contract))
	return maximum


func get_map_count() -> int:
	return map_defs.size()


func get_map_for_path(path: String) -> MapData:
	if map_defs.has(path):
		return map_defs[path]
	var map := MapData.load_file(path)
	map_defs[path] = map
	return map
