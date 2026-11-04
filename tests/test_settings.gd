extends SceneTree

var failures := 0


func _initialize() -> void:
	var path := "user://test_settings_m7.json"
	var corrupt := "user://test_settings_corrupt"
	_clear_dir(corrupt)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var service: Node = load("res://autoload/settings_service.gd").new()
	service.configure_paths(path, corrupt)
	root.add_child(service)
	service.configure_paths(path, corrupt)
	service.load_settings()
	_check(service.get_default_zoom() == 0.8, "default zoom")
	_check(service.station_order().is_empty(), "empty station order before GameData binding")
	service.set_default_zoom(1.2)
	service.set_fullscreen(true)
	service.bind_unit_order(["swordsman", "archer", "mage"])
	_check(FileAccess.file_exists(path), "settings file written")
	_check(service.get_default_zoom() == 1.2, "zoom persists in memory")
	_check(service.station_order().size() == 3, "station order bound to units")
	service.set_station_order(["archer", "swordsman", "mage"], ["swordsman", "archer", "mage"])
	_check(service.station_order()[0] == "archer", "station order reorder persists")

	var reloaded: Node = load("res://autoload/settings_service.gd").new()
	reloaded.configure_paths(path, corrupt)
	root.add_child(reloaded)
	reloaded.configure_paths(path, corrupt)
	reloaded.load_settings()
	_check(reloaded.get_default_zoom() == 1.2, "settings reload from file")
	_check(reloaded.station_order()[0] == "archer", "station order reload from file")
	_check(reloaded.is_fullscreen(), "fullscreen reload")
	reloaded.reset_defaults(["swordsman", "archer", "mage"])
	_check(reloaded.get_default_zoom() == 0.8 and not reloaded.is_fullscreen(), "reset defaults")

	# Invalid file must fall back without crashing and quarantine under corrupt/.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{bad")
	file.close()
	reloaded.load_settings()
	_check(reloaded.get_default_zoom() == 0.8, "corrupt settings fall back to defaults")
	_check(FileAccess.file_exists(path), "corrupt settings are replaced by a clean default file")
	_check(DirAccess.get_files_at(corrupt).size() > 0, "corrupt settings are quarantined")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_clear_dir(corrupt)
	reloaded.queue_free()
	service.queue_free()
	await process_frame
	if failures == 0:
		print("SETTINGS TESTS PASS")
		quit(0)
	else:
		printerr("SETTINGS TESTS FAIL: %d" % failures)
		quit(1)


func _clear_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + String(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
