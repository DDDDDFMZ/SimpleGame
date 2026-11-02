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
	_check(data.guild_defs["iron"]["name_cn"] == "铁誓会", "Chinese guild display name loaded")
	_check(data.counters.has("melee"), "counter matrix loaded")
	_check(int(data.get_balance("base_pop", 0)) == 8, "balance csv load")
	_check(data.get_map_count() >= 2, "campaign maps loaded")
	_check(data.level_defs.size() == 4, "all contract and endless levels loaded")

	if failures == 0:
		print("DATA TESTS PASS")
		quit(0)
	else:
		printerr("DATA TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
