extends SceneTree


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)

	var select_scene: Node = load("res://main/level_select.tscn").instantiate()
	root.add_child(select_scene)
	await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var select_image := root.get_texture().get_image()
	var select_path := dir.path_join("m4_level_select.png")
	var select_err := select_image.save_png(select_path)
	print("screenshot: %s (%s)" % [select_path, error_string(select_err)])
	select_scene.queue_free()
	await process_frame

	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	# M4: contact Iron Oath, then push and recruit.
	scene.sim.queue_guild_action("iron")
	scene.sim.queue_set_advance_line(0, 900.0)
	scene.sim.queue_set_advance_line(1, 900.0)
	scene.sim.queue_spawn(0, 0, "swordsman")
	scene.sim.queue_spawn(0, 0, "swordsman")
	scene.sim.queue_spawn(0, 1, "swordsman")

	await create_timer(22.0).timeout
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var path := dir.path_join("m4_battle.png")
	var err := image.save_png(path)
	print("screenshot: %s (%s)" % [path, error_string(err)])

	var hud: Control = scene.get_node("HUD/Root")
	hud.panel_open = true
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var panel_image := root.get_texture().get_image()
	var panel_path := dir.path_join("m4_company.png")
	var panel_err := panel_image.save_png(panel_path)
	print("screenshot: %s (%s)" % [panel_path, error_string(panel_err)])
	quit(0 if err == OK and panel_err == OK and select_err == OK else 1)
