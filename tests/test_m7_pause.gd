extends SceneTree

var failures := 0


func _initialize() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var hud: Control = scene.get_node("HUD/Root")
	_check(not scene.runner.paused, "battle starts unpaused")
	_press_key(scene, KEY_SPACE)
	_check(scene.pause_mode == 1, "space opens pause menu")
	_check(scene.runner.paused, "pause menu stops sim runner")
	_check(hud.pause_menu, "HUD pause menu is visible")
	scene._on_hud_spawn("swordsman")
	_check(scene.sim.commands.is_empty(), "spawn input is ignored while paused")
	_press_key(scene, KEY_F1)
	_check(scene.pause_mode == 2 and hud.guide_open, "F1 opens guide from pause")
	_press_key(scene, KEY_ESCAPE)
	_check(scene.pause_mode == 1 and not hud.guide_open, "Esc closes guide back to pause")
	_press_key(scene, KEY_SPACE)
	_check(scene.pause_mode == 0 and not scene.runner.paused, "Space resumes from pause")
	_press_key(scene, KEY_ESCAPE)
	_check(scene.pause_mode == 1, "Esc opens pause instead of leaving")
	scene._on_pause_action("resume")
	_check(scene.pause_mode == 0 and not scene.runner.paused, "resume action unpauses")

	_press_key(scene, KEY_SPACE)
	scene._on_pause_action("settings")
	_check(scene.settings_panel.visible, "pause settings opens shared overlay")
	_check(scene.runner.paused and not hud.paused, "settings overlay keeps sim paused and hides pause overlay")
	scene.settings_panel.close()
	_check(scene.pause_mode == 1 and hud.paused and hud.pause_menu, "closing settings returns to pause menu")
	scene._on_pause_action("resume")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("M7 PAUSE TESTS PASS")
		quit(0)
	else:
		printerr("M7 PAUSE TESTS FAIL: %d" % failures)
		quit(1)


func _press_key(scene: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	scene._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
