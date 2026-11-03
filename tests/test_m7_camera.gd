extends SceneTree

var failures := 0


func _initialize() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var economy: bool = scene.sim.economy_enabled
	scene.sim.economy_enabled = false
	scene.sim._spawn_unit(BattleSim.PLAYER, "north", "swordsman")
	scene.sim.economy_enabled = economy
	scene.sim.tick()
	var unit: SimUnit = scene.sim.units[0]
	unit.pos = Vector2(300.0, 450.0)
	unit.hold_position = true
	scene.runner.paused = true
	scene.selected_ids.clear()
	scene.active_route = 0
	scene.camera.jump_to(Vector2(300.0, 450.0))
	await process_frame
	var start_world := Vector2(260.0, 520.0)
	var end_world := Vector2(340.0, 430.0)
	var xform: Transform2D = scene.get_viewport().get_canvas_transform()
	scene._on_drag_started(xform * start_world)
	scene._on_drag_updated(xform * end_world)
	scene._on_drag_finished(xform * end_world, false)
	_check(scene.selected_ids.has(unit.id), "drag anchor outside route selects unit inside box")

	var hud: Control = scene.get_node("HUD/Root")
	hud.snapshot = {"world_width": 1600.0, "world_height": 900.0, "map": {"edges": [], "nodes": []}}
	var center := BattleHUD.MINIMAP_INNER.position + BattleHUD.MINIMAP_INNER.size * 0.5
	var world_center: Vector2 = hud._minimap_world(center, 1600.0, 900.0)
	_check(absf(world_center.x - 800.0) < 4.0 and absf(world_center.y - 450.0) < 4.0, "minimap center maps to world center")
	var mapped: Vector2 = hud._minimap_point([800.0, 450.0], 1600.0, 900.0)
	_check(mapped.distance_to(center) < 2.0, "minimap world-to-screen roundtrip")

	scene.camera.set_zoom_level(1.4)
	var rect_zoom: Rect2 = scene.camera.camera_rect()
	scene.camera.set_zoom_level(0.6)
	var rect_wide: Rect2 = scene.camera.camera_rect()
	_check(rect_wide.size.x > rect_zoom.size.x, "camera rect expands when zooming out")

	scene.queue_free()
	await process_frame
	if failures == 0:
		print("M7 CAMERA TESTS PASS")
		quit(0)
	else:
		printerr("M7 CAMERA TESTS FAIL: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
