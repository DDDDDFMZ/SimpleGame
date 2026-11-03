extends SceneTree

var failures := 0


func _initialize() -> void:
	var service: Node = load("res://autoload/save_service.gd").new()
	root.add_child(service)
	var save_path := "user://m7_test_save.json"
	var backup_dir := "user://m7_test_backups"
	service.configure_paths(save_path, backup_dir)
	_cleanup(save_path, backup_dir)

	var first := {"version": 3, "unlocked_contracts": [1], "stars": {}, "settings": {"station_order": ["swordsman"]}}
	var second := {"version": 3, "unlocked_contracts": [1, 2], "stars": {"1": 2}, "settings": {"station_order": ["archer"]}}
	_check(service.save_game(first), "save writes primary")
	_check(service.save_game(second), "second save writes primary")
	var backups: Array = service.list_backups()
	_check(backups.size() == 1, "second save rotates a backup")
	_check(not service.load_game().is_empty(), "primary loads")

	var manual: String = String(service.backup_current("manual"))
	_check(manual != "" and FileAccess.file_exists(manual), "manual backup created")
	backups = service.list_backups()
	_check(backups.size() >= 2, "manual backup is listed")

	var restored: Dictionary = service.restore_backup(String(backups[0].get("path", "")))
	_check(not restored.is_empty(), "backup restore returns data")
	_check(service.load_game().get("unlocked_contracts", []).size() >= 1, "restored primary loads")

	# Corrupt the primary; load should quarantine and recover the latest backup.
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered: Dictionary = service.load_game()
	_check(not recovered.is_empty() and service.last_status == "recovered", "corrupt primary recovers from backup")

	var new_data: Dictionary = service.new_game_data({"version": 3, "unlocked_contracts": [1], "stars": {}})
	_check(not new_data.is_empty(), "new game data writes a backup and primary")
	_check(FileAccess.file_exists(save_path), "new game primary exists")

	_cleanup(save_path, backup_dir)
	if failures == 0:
		print("M7 SAVE TESTS PASS")
		quit(0)
	else:
		printerr("M7 SAVE TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _cleanup(save_path: String, backup_dir: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var dir := DirAccess.open(backup_dir)
	if dir != null:
		for file_name in dir.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_dir + "/" + String(file_name)))
