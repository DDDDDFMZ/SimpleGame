extends Node

signal progress_changed

const FAVOR_CAP := 10

var game_data: GameData
var unlocked_contracts: Array = [1]
var stars: Dictionary = {}
var unlocked_guilds: Array = ["iron"]
var guild_favor: Dictionary = {"iron": 0, "verdant": 0, "arcane": 0}
var best_endless: Dictionary = {"score": 0, "waves": 0}
var endless_unlocked: bool = false
var selected_contract: int = 1
var endless_mode: bool = false
var settings: Dictionary = {"ui_scale": 1.0, "station_order": []}
var tutorial_seen: bool = false
var load_status: String = "missing"
var map_editor_auto_opened: bool = false
var save_service_override: Node = null


func _ready() -> void:
	_ensure_data()
	_load()


func _ensure_data() -> void:
	if game_data == null:
		game_data = GameData.new()
		game_data.load_all()


func _defaults() -> Dictionary:
	_ensure_data()
	var favor := {}
	var starting_guilds: Array = []
	if game_data != null:
		for guild_id in game_data.guild_order:
			favor[guild_id] = 0
			if int(game_data.guild_defs[guild_id].get("unlock_after", 0)) == 0:
				starting_guilds.append(guild_id)
	if starting_guilds.is_empty():
		starting_guilds = ["iron"]
	return {
		"version": 3,
		"unlocked_contracts": [1],
		"stars": {},
		"unlocked_guilds": starting_guilds,
		"guild_favor": favor if not favor.is_empty() else {"iron": 0},
		"best_endless": {"score": 0, "waves": 0},
		"endless_unlocked": false,
		"settings": {"ui_scale": 1.0, "station_order": _default_station_order()},
		"tutorial_seen": false,
	}


func _save_service() -> Node:
	if save_service_override != null:
		return save_service_override
	return get_node_or_null("/root/SaveService")


func _load() -> void:
	_ensure_data()
	var save_service := _save_service()
	var loaded: Dictionary = save_service.load_game() if save_service != null else {}
	load_status = String(save_service.last_status) if save_service != null else "missing"
	if loaded.is_empty():
		loaded = _defaults()
	elif int(loaded.get("version", 1)) < 3:
		var merged := _defaults()
		for key in merged:
			if loaded.has(key):
				merged[key] = loaded[key]
		merged["version"] = 3
		loaded = merged
	_apply_loaded(loaded)


func _apply_loaded(loaded: Dictionary) -> void:
	unlocked_contracts = []
	for contract_value in loaded.get("unlocked_contracts", [1]):
		unlocked_contracts.append(int(contract_value))
	if unlocked_contracts.is_empty():
		unlocked_contracts = [1]
	stars = loaded.get("stars", {})
	unlocked_guilds = loaded.get("unlocked_guilds", ["iron"])
	guild_favor = loaded.get("guild_favor", {"iron": 0, "verdant": 0, "arcane": 0})
	best_endless = loaded.get("best_endless", {"score": 0, "waves": 0})
	endless_unlocked = bool(loaded.get("endless_unlocked", false))
	settings = loaded.get("settings", {"ui_scale": 1.0, "station_order": _default_station_order()})
	if not settings.has("station_order") or not (settings["station_order"] is Array) or settings["station_order"].is_empty():
		settings["station_order"] = _default_station_order()
	tutorial_seen = bool(loaded.get("tutorial_seen", false))
	var order: Array = game_data.guild_order if game_data != null else ["iron"]
	for guild_id in order:
		if not guild_favor.has(guild_id):
			guild_favor[guild_id] = 0
	selected_contract = 1 if not unlocked_contracts.has(selected_contract) else selected_contract
	endless_mode = false
	progress_changed.emit()


func save(make_backup: bool = true) -> bool:
	var data := {
		"version": 3,
		"unlocked_contracts": unlocked_contracts,
		"stars": stars,
		"unlocked_guilds": unlocked_guilds,
		"guild_favor": guild_favor,
		"best_endless": best_endless,
		"endless_unlocked": endless_unlocked,
		"settings": settings,
		"tutorial_seen": tutorial_seen,
	}
	var save_service := _save_service()
	if save_service != null:
		var ok: bool = save_service.save_game(data, make_backup)
		load_status = String(save_service.last_status)
		return ok
	return false


func backup_progress(label: String = "manual") -> String:
	var save_service := _save_service()
	if save_service == null or not save_service.has_method("backup_current"):
		return ""
	return String(save_service.backup_current(label))


func list_backups() -> Array:
	var save_service := _save_service()
	if save_service == null or not save_service.has_method("list_backups"):
		return []
	return save_service.list_backups()


func restore_backup(path: String) -> bool:
	var save_service := _save_service()
	if save_service == null or not save_service.has_method("restore_backup"):
		return false
	var data: Dictionary = save_service.restore_backup(path)
	if data.is_empty():
		return false
	load_status = "restored"
	_apply_loaded(data)
	return true


func new_game(preserve_settings: bool = true) -> bool:
	var save_service := _save_service()
	if save_service == null:
		return false
	var data := _defaults()
	if preserve_settings:
		data["settings"] = settings.duplicate(true)
	data["tutorial_seen"] = false
	var written: Dictionary = save_service.new_game_data(data)
	if written.is_empty():
		return false
	load_status = "new"
	_apply_loaded(written)
	selected_contract = 1
	endless_mode = false
	return true


func is_contract_unlocked(contract_id: int) -> bool:
	return unlocked_contracts.has(contract_id)


func is_guild_unlocked(guild_id: String) -> bool:
	return unlocked_guilds.has(guild_id)


func star_for(contract_id: int) -> int:
	return int(stars.get(str(contract_id), 0))


func profile() -> Dictionary:
	return {
		"unlocked_guilds": unlocked_guilds.duplicate(),
		"guild_favor": guild_favor.duplicate(),
		"station_order": station_order(),
	}


func _default_station_order() -> Array:
	_ensure_data()
	if game_data == null:
		return []
	var order: Array = []
	for def_id in game_data.unit_order:
		order.append(String(def_id))
	order.sort_custom(func(a, b) -> bool:
		var da: Dictionary = game_data.unit_defs.get(String(a), {})
		var db: Dictionary = game_data.unit_defs.get(String(b), {})
		var ra := int(da.get("station_rank", 99))
		var rb := int(db.get("station_rank", 99))
		if ra == rb:
			return String(a) < String(b)
		return ra < rb
	)
	return order


func station_order() -> Array:
	_ensure_data()
	var result: Array = []
	var raw: Variant = settings.get("station_order", [])
	if raw is Array:
		for value in raw:
			var def_id := String(value)
			if game_data != null and game_data.unit_defs.has(def_id) and not result.has(def_id):
				result.append(def_id)
	for def_id in _default_station_order():
		if not result.has(def_id):
			result.append(String(def_id))
	return result


func set_station_order(order: Array) -> void:
	settings["station_order"] = order.duplicate()
	save(false)


func get_level_path(contract_id: int) -> String:
	_ensure_data()
	return game_data.get_level_path(contract_id) if game_data != null else ""


func get_contracts() -> Array:
	_ensure_data()
	if game_data == null:
		return [1, 2, 3]
	var contracts: Array = []
	for contract in game_data.level_paths:
		contracts.append(int(contract))
	contracts.sort()
	return contracts


func get_max_contract() -> int:
	_ensure_data()
	return game_data.get_max_contract() if game_data != null else 3


func get_endless_path() -> String:
	return game_data.endless_path if game_data != null else ""


func select_contract(contract_id: int) -> bool:
	if contract_id > get_max_contract():
		return false
	if not is_contract_unlocked(contract_id):
		return false
	selected_contract = contract_id
	endless_mode = false
	return true


func select_endless() -> bool:
	if not endless_unlocked:
		return false
	endless_mode = true
	return true


func record_result(contract_id: int, earned_stars: int, usage: Dictionary) -> void:
	_ensure_data()
	if earned_stars <= 0:
		return
	var key := str(contract_id)
	var old_stars := int(stars.get(key, 0))
	stars[key] = maxi(old_stars, earned_stars)

	var max_contract := game_data.get_max_contract() if game_data != null else 3
	var next_contract := contract_id + 1
	if next_contract <= max_contract and not unlocked_contracts.has(next_contract):
		unlocked_contracts.append(next_contract)
		unlocked_contracts.sort()

	if game_data != null:
		for unlock in game_data.unlock_guilds:
			if int(unlock.get("after_contract", 0)) <= contract_id:
				var guild_id := String(unlock.get("guild", ""))
				if guild_id != "" and not unlocked_guilds.has(guild_id):
					unlocked_guilds.append(guild_id)
	if contract_id >= max_contract and earned_stars > 0:
		endless_unlocked = true

	# Award favor only when the best star result improves, so retries cannot farm it.
	if earned_stars > old_stars:
		var guild_order: Array = game_data.guild_order if game_data != null else ["iron"]
		for guild_id in guild_order:
			var used := int(usage.get(guild_id, 0))
			if used <= 0:
				continue
			var gain := int(floor(used / 10.0))
			if earned_stars >= 2:
				gain += 1
			if earned_stars >= 3:
				gain += 1
			var cap_value := int(game_data.get_balance("favor_cap", FAVOR_CAP)) if game_data != null else FAVOR_CAP
			guild_favor[guild_id] = mini(cap_value, int(guild_favor.get(guild_id, 0)) + gain)

	save()
	progress_changed.emit()


func record_endless(score: int, waves: int) -> void:
	if score > int(best_endless.get("score", 0)):
		best_endless = {"score": score, "waves": waves}
		save()
		progress_changed.emit()


func guild_bonus_text(guild_id: String) -> String:
	var favor := int(guild_favor.get(guild_id, 0))
	if favor <= 0:
		return "暂无"
	var stat_per_point := float(game_data.get_balance("favor_hp_damage_per_point", 0.01)) * 100.0 if game_data != null else 1.0
	var cost_per_point := float(game_data.get_balance("favor_cost_per_point", 0.005)) * 100.0 if game_data != null else 0.5
	return "属性 +%.1f%% · 费用 -%.1f%%" % [favor * stat_per_point, favor * cost_per_point]


func reset_progress() -> void:
	var defaults := _defaults()
	unlocked_contracts = defaults["unlocked_contracts"]
	stars = defaults["stars"]
	unlocked_guilds = defaults["unlocked_guilds"]
	guild_favor = defaults["guild_favor"]
	best_endless = defaults["best_endless"]
	endless_unlocked = false
	save()
	progress_changed.emit()
