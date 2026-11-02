class_name GameData
extends RefCounted

const UNITS_PATH := "res://data/balance/units.csv"
const GUILDS_PATH := "res://data/balance/guilds.csv"
const GUILD_TIERS_PATH := "res://data/balance/guild_tiers.csv"
const BALANCE_PATH := "res://data/balance/balance.csv"
const COUNTERS_PATH := "res://data/balance/counters.csv"
const CAMPAIGN_PATH := "res://data/campaign.json"

var unit_defs: Dictionary = {}
var unit_order: Array = []
var guild_defs: Dictionary = {}
var guild_order: Array = []
var balance: Dictionary = {}
var counters: Dictionary = {}
var campaign: Dictionary = {}
var level_paths: Dictionary = {}
var unlock_guilds: Array = []
var endless_path: String = ""
var errors: Array = []


func load_all() -> bool:
	errors.clear()
	unit_defs.clear()
	unit_order.clear()
	guild_defs.clear()
	guild_order.clear()
	balance.clear()
	counters.clear()
	level_paths.clear()
	unlock_guilds.clear()

	_load_units()
	_load_guilds()
	_load_balance()
	_load_counters()
	_load_campaign()
	_validate()

	if not errors.is_empty():
		for err in errors:
			push_error("GameData: " + String(err))
		return false
	return true


func _read_csv(path: String) -> Array:
	if not FileAccess.file_exists(path):
		errors.append("%s: file missing" % path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: cannot open" % path)
		return []
	var headers := file.get_csv_line()
	var rows: Array = []
	var line_no := 1
	while not file.eof_reached():
		var values := file.get_csv_line()
		line_no += 1
		if values.size() == 1 and values[0] == "":
			continue
		if values.size() != headers.size():
			errors.append("%s:%d: expected %d columns, got %d" % [path, line_no, headers.size(), values.size()])
			continue
		var row := {}
		for i in range(headers.size()):
			row[headers[i]] = values[i]
		rows.append(row)
	return rows


func _load_units() -> void:
	var rows := _read_csv(UNITS_PATH)
	for row in rows:
		var def_id := String(row.get("id", "")).strip_edges()
		if def_id == "":
			continue
		if unit_defs.has(def_id):
			errors.append("%s: duplicate unit id %s" % [UNITS_PATH, def_id])
			continue
		var sort_order := int(row.get("sort_order", "0"))
		var def := {
			"id": def_id,
			"name_key": String(row.get("name_key", "")),
			"display_name": String(row.get("display_name", def_id)),
			"guild": String(row.get("guild", "")),
			"relation_tier": int(row.get("relation_tier", "0")),
			"role": String(row.get("role", "")),
			"recruitable": _bool(row.get("recruitable", "true")),
			"cost": int(row.get("cost", "0")),
			"pop": int(row.get("pop", "1")),
			"hp": float(row.get("hp", "100")),
			"damage": float(row.get("damage", "10")),
			"attack_interval": float(row.get("attack_interval", "1")),
			"range": float(row.get("range", "24")),
			"speed": float(row.get("speed", "50")),
			"attack_type": String(row.get("attack_type", "melee")),
			"armor_type": String(row.get("armor_type", "light")),
			"passive": String(row.get("passive", "")),
			"projectile_speed": float(row.get("projectile_speed", "0")),
			"cooldown": float(row.get("cooldown", "3")),
			"heal_amount": float(row.get("heal_amount", "0")),
			"heal_interval": float(row.get("heal_interval", "0")),
			"heal_range": float(row.get("heal_range", "0")),
			"sort_order": sort_order,
			"notes": String(row.get("notes", "")),
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
	var rows := _read_csv(GUILDS_PATH)
	for row in rows:
		var guild_id := String(row.get("id", "")).strip_edges()
		if guild_id == "":
			continue
		guild_defs[guild_id] = {
			"id": guild_id,
			"name": String(row.get("name", guild_id)),
			"short": String(row.get("short", guild_id)),
			"unlock_after": int(row.get("unlock_after", "0")),
			"sort_order": int(row.get("sort_order", "0")),
			"tiers": [],
		}
	var tier_rows := _read_csv(GUILD_TIERS_PATH)
	for row in tier_rows:
		var guild_id := String(row.get("guild_id", ""))
		if not guild_defs.has(guild_id):
			errors.append("%s: unknown guild %s" % [GUILD_TIERS_PATH, guild_id])
			continue
		var tier_index := int(row.get("tier", "0"))
		var tiers: Array = guild_defs[guild_id]["tiers"]
		while tiers.size() <= tier_index:
			tiers.append({})
		tiers[tier_index] = {
			"cost": int(row.get("cost", "0")),
			"cap": int(row.get("cap", "0")),
			"rank_gate": int(row.get("rank_gate", "0")),
			"units": [],
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
	guild_order.clear()
	var sortable: Array = []
	for guild_id in guild_defs:
		sortable.append({"id": guild_id, "sort_order": int(guild_defs[guild_id]["sort_order"])})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sort_order"]) == int(b["sort_order"]):
			return String(a["id"]) < String(b["id"])
		return int(a["sort_order"]) < int(b["sort_order"])
	)
	for entry in sortable:
		guild_order.append(String(entry["id"]))


func _load_balance() -> void:
	var rows := _read_csv(BALANCE_PATH)
	for row in rows:
		var key := String(row.get("key", "")).strip_edges()
		if key == "":
			continue
		var value_text := String(row.get("value", ""))
		var type := String(row.get("type", "string"))
		var value: Variant = value_text
		match type:
			"int":
				value = int(value_text)
			"float":
				value = float(value_text)
			"bool":
				value = _bool(value_text)
			"int_list":
				var list: Array = []
				for part in value_text.split("|"):
					list.append(int(part))
				value = list
		balance[key] = value


func _load_counters() -> void:
	var rows := _read_csv(COUNTERS_PATH)
	for row in rows:
		var attack_type := String(row.get("attack_type", "")).strip_edges()
		if attack_type == "":
			continue
		counters[attack_type] = {
			"light": float(row.get("light", "1.0")),
			"heavy": float(row.get("heavy", "1.0")),
		}


func _load_campaign() -> void:
	var text := FileAccess.get_file_as_string(CAMPAIGN_PATH)
	if text.is_empty():
		errors.append("%s: file missing" % CAMPAIGN_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: invalid JSON" % CAMPAIGN_PATH)
		return
	campaign = parsed
	for level in campaign.get("levels", []):
		var contract := int(level.get("contract", 0))
		var path := String(level.get("path", ""))
		if contract <= 0 or path == "":
			errors.append("%s: invalid level entry" % CAMPAIGN_PATH)
			continue
		level_paths[contract] = path
		if not FileAccess.file_exists(path):
			errors.append("%s: level path missing %s" % [CAMPAIGN_PATH, path])
	for unlock in campaign.get("unlock_guilds", []):
		unlock_guilds.append({
			"after_contract": int(unlock.get("after_contract", 0)),
			"guild": String(unlock.get("guild", "")),
		})
	var endless: Dictionary = campaign.get("endless", {})
	endless_path = String(endless.get("path", ""))
	if endless_path == "":
		errors.append("%s: endless.path missing" % CAMPAIGN_PATH)
	elif not FileAccess.file_exists(endless_path):
		errors.append("%s: endless path missing %s" % [CAMPAIGN_PATH, endless_path])


func _validate() -> void:
	var valid_attack := ["melee", "ranged", "siege"]
	var valid_armor := ["light", "heavy"]
	var seen := {}
	for def_id in unit_order:
		var def: Dictionary = unit_defs[String(def_id)]
		if seen.has(def_id):
			errors.append("%s: duplicate unit %s" % [UNITS_PATH, def_id])
		seen[def_id] = true
		if not valid_attack.has(String(def.get("attack_type", ""))):
			errors.append("%s: bad attack_type for %s" % [UNITS_PATH, def_id])
		if not valid_armor.has(String(def.get("armor_type", ""))):
			errors.append("%s: bad armor_type for %s" % [UNITS_PATH, def_id])
		if bool(def.get("recruitable", true)) and not guild_defs.has(String(def.get("guild", ""))):
			errors.append("%s: unknown guild for %s" % [UNITS_PATH, def_id])
	for guild_id in guild_order:
		var tiers: Array = guild_defs[guild_id]["tiers"]
		if tiers.is_empty():
			errors.append("%s: guild %s has no tiers" % [GUILDS_PATH, guild_id])
		for i in range(tiers.size()):
			if tiers[i].is_empty():
				errors.append("%s: guild %s missing tier %d" % [GUILD_TIERS_PATH, guild_id, i])

	for required in [
		"base_pop", "pop_per_rank", "promo_kills", "promo_cost",
		"wave_gold_base", "wave_gold_per_wave", "target_gold",
		"bounty_ratio", "elite_bounty_ratio", "favor_hp_damage_per_point",
		"favor_cost_per_point", "favor_cap", "endless_budget_base",
		"endless_budget_per_wave", "endless_budget_quadratic",
	]:
		if not balance.has(required):
			errors.append("%s: missing key %s" % [BALANCE_PATH, required])


func _bool(text: String) -> bool:
	return text.strip_edges().to_lower() in ["true", "1", "yes"]


func get_balance(key: String, default_value: Variant = 0) -> Variant:
	return balance.get(key, default_value)


func get_level_path(contract: int) -> String:
	return String(level_paths.get(contract, ""))


func get_max_contract() -> int:
	var maximum := 0
	for contract in level_paths:
		maximum = maxi(maximum, int(contract))
	return maximum
