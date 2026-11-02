extends SceneTree


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)
	var errors: Array = []

	var select_scene: Node = load("res://main/level_select.tscn").instantiate()
	root.add_child(select_scene)
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_level_select.png")))
	select_scene.queue_free()
	await process_frame

	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.sim.queue_guild_action("iron")
	scene.sim.queue_set_advance_line(0, 760.0)
	scene.sim.queue_set_advance_line(1, 760.0)
	for i in range(3):
		scene.sim.queue_spawn(0, 0, "swordsman")
		scene.sim.queue_spawn(0, 1, "swordsman")
	scene.sim.queue_spawn(0, 0, "spearman")

	await create_timer(21.0).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_battle.png")))

	var hud: Control = scene.get_node("HUD/Root")
	hud.hover_card = 0
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_tooltip.png")))

	hud.hover_card = -1
	# Spawn one off-guild unit per lane solely to demonstrate the category panel.
	var economy_before: bool = scene.sim.economy_enabled
	scene.sim.economy_enabled = false
	scene.sim._spawn_unit(0, 0, "archer")
	scene.sim._spawn_unit(0, 1, "mage")
	scene.sim.economy_enabled = economy_before
	await create_timer(0.2).timeout
	var ids: Array = []
	for unit in scene.sim.get_snapshot().get("units", []):
		if int(unit.get("team", 1)) == 0:
			ids.append(int(unit.get("id", -1)))
	scene.selected_ids = ids
	scene._update_selection_view()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_selection.png")))

	scene.selected_ids.clear()
	scene._update_selection_view()
	hud.panel_open = true
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_company.png")))

	hud.panel_open = false
	hud.guide_open = true
	hud.guide_page = 0
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_guide_1.png")))

	hud.guide_page = 1
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_guide_2.png")))
	scene.queue_free()
	await process_frame

	var editor: Node = load("res://main/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	errors.append(root.get_texture().get_image().save_png(dir.path_join("m6_map_editor.png")))

	for error in errors:
		print("screenshot error: ", error)
	print("M6 CAPTURE DONE")
	quit(0)
