extends SceneTree

var failures := 0


func _initialize() -> void:
	var data := GameData.new()
	var ok := data.load_all()
	_check(ok, "GameData loads")
	_check(data.errors.is_empty(), "GameData has no validation errors")
	_check(data.unit_defs.size() == 8, "eight units loaded")
	_check(data.guild_defs.size() == 3, "three guilds loaded")
	_check(data.unit_defs.has("cleric"), "cleric present")
	_check(data.unit_defs["swordsman"]["display_name_cn"] == "剑士", "Chinese unit display name loaded")
	_check(float(data.unit_defs["swordsman"]["body_width"]) > 0.0, "unit collision body loaded")
	_check(data.guild_defs["iron"]["name_cn"] == "铁誓会", "Chinese guild display name loaded")
	_check(data.guild_defs["iron"]["tiers"][2]["rank_gate"] == 1, "guild rank gate loaded")
	_check(data.counters["melee"]["heavy"] == 0.75, "counter matrix loaded")
	_check(int(data.get_balance("base_pop", 0)) == 8, "balance JSON load")
	_check(data.get_balance("promo_kills", []) == [1, 3, 5], "balance arrays load")
	_check(data.get_map_count() >= 2, "campaign maps loaded")
	_check(data.level_defs.size() == 4, "all contract and endless levels loaded")

	_test_negative_fixtures()

	if failures == 0:
		print("DATA TESTS PASS")
		quit(0)
	else:
		printerr("DATA TESTS FAIL: %d" % failures)
		quit(1)


func _test_negative_fixtures() -> void:
	var bad_units_path := "user://test_bad_units.json"
	_write_text(bad_units_path, "{bad")
	var bad_units := GameData.new()
	_check(bad_units._read_json(bad_units_path).is_empty(), "malformed units JSON returns no data")
	_check(_has_error(bad_units, "invalid JSON"), "malformed units JSON reports a parse error")

	var unknown_guild_path := "user://test_unknown_guild_units.json"
	var units_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameData.UNITS_PATH))
	var units_dict: Dictionary = {}
	if units_data is Dictionary:
		units_dict = (units_data as Dictionary).duplicate(true)
	units_dict["lost_unit"] = {
		"display_name": "Lost",
		"guild": "missing_guild",
		"relation_tier": 0,
		"role": "vanguard",
		"cost": 10,
		"hp": 100,
		"damage": 10,
		"speed": 50,
		"attack_type": "melee",
		"armor_type": "light",
		"body_width": 12,
		"body_height": 18,
	}
	_write_json(unknown_guild_path, units_dict)
	var unknown_guild := GameData.new()
	unknown_guild.configure_paths(unknown_guild_path, GameData.GUILDS_PATH, GameData.BALANCE_PATH, GameData.COUNTERS_PATH, GameData.CAMPAIGN_PATH)
	_check(not unknown_guild.load_all(), "unit with unknown guild is rejected")
	_check(_has_error(unknown_guild, "unknown guild"), "unknown guild reports a path")

	var bad_balance_path := "user://test_bad_balance.json"
	var balance_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameData.BALANCE_PATH))
	var balance_dict: Dictionary = {}
	if balance_data is Dictionary:
		balance_dict = (balance_data as Dictionary).duplicate(true)
	balance_dict["typo_key"] = 1
	balance_dict["base_pop"] = "oops"
	_write_json(bad_balance_path, balance_dict)
	var bad_balance := GameData.new()
	bad_balance.configure_paths(GameData.UNITS_PATH, GameData.GUILDS_PATH, bad_balance_path, GameData.COUNTERS_PATH, GameData.CAMPAIGN_PATH)
	_check(not bad_balance.load_all(), "balance typo/type error is rejected")
	_check(_has_error(bad_balance, "unknown key typo_key"), "unknown balance key reports a path")
	_check(_has_error(bad_balance, "base_pop must be numeric"), "balance type error reports a path")

	for path in [bad_units_path, unknown_guild_path, bad_balance_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(String(path)))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t"))


func _has_error(data: GameData, needle: String) -> bool:
	for error in data.errors:
		if String(error).contains(needle):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
