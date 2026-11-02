extends Node

signal progress_changed

const GUILD_ORDER := ["iron", "verdant", "arcane"]
const MAX_CONTRACT := 3
const FAVOR_CAP := 10

var unlocked_contracts: Array = [1]
var stars: Dictionary = {}
var unlocked_guilds: Array = ["iron"]
var guild_favor: Dictionary = {"iron": 0, "verdant": 0, "arcane": 0}
var best_endless: Dictionary = {"score": 0, "waves": 0}
var endless_unlocked: bool = false
var selected_contract: int = 1
var endless_mode: bool = false
var settings: Dictionary = {"ui_scale": 1.0}
var tutorial_seen: bool = false
var save_service_override: Node = null


func _ready() -> void:
	_load()


func _defaults() -> Dictionary:
	return {
		"version": 2,
		"unlocked_contracts": [1],
		"stars": {},
		"unlocked_guilds": ["iron"],
		"guild_favor": {"iron": 0, "verdant": 0, "arcane": 0},
		"best_endless": {"score": 0, "waves": 0},
		"endless_unlocked": false,
		"settings": {"ui_scale": 1.0},
		"tutorial_seen": false,
	}


func _save_service() -> Node:
	if save_service_override != null:
		return save_service_override
	return get_node_or_null("/root/SaveService")


func _load() -> void:
	var save_service := _save_service()
	var loaded: Dictionary = save_service.load_game() if save_service != null else {}
	if loaded.is_empty():
		loaded = _defaults()
	elif int(loaded.get("version", 1)) < 2:
		var merged := _defaults()
		for key in merged:
			if loaded.has(key):
				merged[key] = loaded[key]
		merged["version"] = 2
		loaded = merged

	unlocked_contracts = []
	for contract_value in loaded.get("unlocked_contracts", [1]):
		unlocked_contracts.append(int(contract_value))
	stars = loaded.get("stars", {})
	unlocked_guilds = loaded.get("unlocked_guilds", ["iron"])
	guild_favor = loaded.get("guild_favor", {"iron": 0, "verdant": 0, "arcane": 0})
	best_endless = loaded.get("best_endless", {"score": 0, "waves": 0})
	endless_unlocked = bool(loaded.get("endless_unlocked", false))
	settings = loaded.get("settings", {"ui_scale": 1.0})
	tutorial_seen = bool(loaded.get("tutorial_seen", false))

	for guild_id in GUILD_ORDER:
		if not guild_favor.has(guild_id):
			guild_favor[guild_id] = 0
	progress_changed.emit()


func save() -> void:
	var data := {
		"version": 2,
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
		save_service.save_game(data)


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
	}


func select_contract(contract_id: int) -> bool:
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
	if earned_stars <= 0:
		return
	var key := str(contract_id)
	var old_stars := int(stars.get(key, 0))
	stars[key] = maxi(old_stars, earned_stars)

	var next_contract := contract_id + 1
	if next_contract <= MAX_CONTRACT and not unlocked_contracts.has(next_contract):
		unlocked_contracts.append(next_contract)
		unlocked_contracts.sort()

	if contract_id == 1 and not unlocked_guilds.has("verdant"):
		unlocked_guilds.append("verdant")
	if contract_id == 2 and not unlocked_guilds.has("arcane"):
		unlocked_guilds.append("arcane")
	if contract_id >= MAX_CONTRACT and earned_stars > 0:
		endless_unlocked = true

	# Award favor only when the best star result improves, so retries cannot farm it.
	if earned_stars > old_stars:
		for guild_id in GUILD_ORDER:
			var used := int(usage.get(guild_id, 0))
			if used <= 0:
				continue
			var gain := int(floor(used / 10.0))
			if earned_stars >= 2:
				gain += 1
			if earned_stars >= 3:
				gain += 1
			guild_favor[guild_id] = mini(FAVOR_CAP, int(guild_favor.get(guild_id, 0)) + gain)

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
		return "no favor yet"
	return "+%d%% stats  -%.1f%% cost" % [favor, favor * 0.5]


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
