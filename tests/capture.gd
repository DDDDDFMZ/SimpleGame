extends SceneTree


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)

	var select_scene: Node = load("res://main/level_select.tscn").instantiate()
	root.add_child(select_scene)
	await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var select_err := root.get_texture().get_image().save_png(dir.path_join("m5_level_select.png"))
	print("screenshot: %s (%s)" % [dir.path_join("m5_level_select.png"), error_string(select_err)])
	select_scene.queue_free()
	await process_frame

	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.sim.queue_guild_action("iron")
	scene.sim.queue_set_advance_line(0, 900.0)
	scene.sim.queue_set_advance_line(1, 900.0)
	scene.sim.queue_spawn(0, 0, "swordsman")
	scene.sim.queue_spawn(0, 0, "swordsman")
	scene.sim.queue_spawn(0, 1, "swordsman")

	await create_timer(22.0).timeout
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(dir.path_join("m5_battle.png"))
	print("screenshot: %s (%s)" % [dir.path_join("m5_battle.png"), error_string(err)])

	var hud: Control = scene.get_node("HUD/Root")
	hud.hover_card = 0
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var tooltip_err := root.get_texture().get_image().save_png(dir.path_join("m5_tooltip.png"))
	print("screenshot: %s (%s)" % [dir.path_join("m5_tooltip.png"), error_string(tooltip_err)])

	hud.hover_card = -1
	hud.panel_open = true
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var panel_err := root.get_texture().get_image().save_png(dir.path_join("m5_company.png"))
	print("screenshot: %s (%s)" % [dir.path_join("m5_company.png"), error_string(panel_err)])

	hud.panel_open = false
	hud.guide_open = true
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var guide_err := root.get_texture().get_image().save_png(dir.path_join("m5_guide.png"))
	print("screenshot: %s (%s)" % [dir.path_join("m5_guide.png"), error_string(guide_err)])
	quit(0 if err == OK and panel_err == OK and select_err == OK and tooltip_err == OK and guide_err == OK else 1)
