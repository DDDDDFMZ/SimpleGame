extends SceneTree

var failures := 0
var had_save := false
var original_save := ""


func _initialize() -> void:
	var save_path := "user://save.json"
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		original_save = FileAccess.get_file_as_string(save_path)

	var save_script: Script = load("res://autoload/save_service.gd")
	var save_service: Node = save_script.new()
	save_service.name = "SaveService"
	root.add_child(save_service)
	var gs_script: Script = load("res://autoload/game_state.gd")
	var gs: Node = gs_script.new()
	gs.name = "GameState"
	gs.save_service_override = save_service
	root.add_child(gs)

	gs.reset_progress()
	gs.record_result(1, 3, {"iron": 10, "verdant": 0, "arcane": 0})
	_check(gs.is_contract_unlocked(2), "clearing contract 1 unlocks contract 2")
	_check(gs.is_guild_unlocked("verdant"), "clearing contract 1 unlocks Verdant")
	_check(int(gs.guild_favor.get("iron", 0)) == 3, "usage and stars grant guild favor")

	gs._load()
	_check(gs.star_for(1) == 3, "stars survive save/load")
	_check(gs.is_contract_unlocked(2), "contract unlock survives save/load")

	gs.record_result(2, 2, {"iron": 0, "verdant": 5, "arcane": 0})
	_check(gs.is_contract_unlocked(3), "clearing contract 2 unlocks contract 3")
	_check(gs.is_guild_unlocked("arcane"), "clearing contract 2 unlocks Arcane")

	gs.record_result(3, 1, {"iron": 0, "verdant": 0, "arcane": 2})
	_check(gs.endless_unlocked, "clearing contract 3 unlocks endless")

	gs.record_endless(1234, 9)
	_check(int(gs.best_endless.get("score", 0)) == 1234, "endless best score is saved")

	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_string(original_save)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		print("META TESTS PASS")
		quit(0)
	else:
		printerr("META TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
