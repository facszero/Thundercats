extends SceneTree
func _init(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	assert(game.desktop)
	assert(game.input_hint == "help")
	assert(game.desktop_menu.visible)
	assert(root.gui_get_focus_owner() != null)
	game.start_level(1)
	assert(not game.desktop_menu.visible)
	game.toggle_pause()
	assert(game.sim.mode == "pause")
	assert(game.desktop_menu.visible)
	assert(root.gui_get_focus_owner() != null)
	game.sim.mode = "transition"
	game.refresh_menu()
	assert(root.gui_get_focus_owner() == game.skip_button)
	game.sim.mode = "menu"
	game.refresh_menu()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://windows-menu.png")
	print("Windows: desktop hints, menus, pause and transition focus passed")
	quit()
