extends SceneTree

# Optional graphical smoke check. Requires a real or virtual display, not --headless.
func _initialize() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 60.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_capture")

func _capture() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: ForestGame = scene.instantiate()
	root.add_child(game)
	game.persistence = false
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-intro.png")
	game.start_journey()
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-game.png")
	game.show_map()
	await _frames(5)
	await _save("/tmp/entre-folhas-godot-map.png")
	game.close_dialog()
	for item in WorldData.SEEDS:
		game.collected[item.id] = true
	game.complete = true
	game.world.apply_progress(game.collected, true)
	game.hud.update_quest(game.collected, true)
	game.player.position = WorldData.MOTHER + Vector2(0, 75)
	game.camera.reset_smoothing()
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-restored.png")
	game.reset_journey()
	game.player.position = KingdomData.point("forge") + Vector2(0, 65)
	game.camera.reset_smoothing()
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-aurelia.png")
	game.open_npc("bento")
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-npc-dialogue.png")
	game.open_npc("bento", "routine")
	await _frames(5)
	await _save("/tmp/entre-folhas-godot-npc-routine.png")
	game.close_dialog()
	game.world.clock.set_time(10.0)
	for npc in game.world.npcs.values():
		npc.apply_schedule(game.world.clock.minute, true)
	game.player.position = KingdomData.point("caio_court") + Vector2(0, 80)
	game.camera.reset_smoothing()
	await _frames(8)
	await _save("/tmp/entre-folhas-godot-valverde.png")
	game.world.clock.set_time(23.0)
	for npc in game.world.npcs.values():
		npc.apply_schedule(game.world.clock.minute, true)
	await _frames(5)
	await _save("/tmp/entre-folhas-godot-night.png")
	game.reset_journey()
	root.size = Vector2i(390, 844)
	await _frames(10)
	game.hud._layout()
	await _save("/tmp/entre-folhas-godot-mobile.png")
	game.queue_free()
	await process_frame
	quit()

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("Falha ao capturar " + path)
		quit(1)
		return
	print("CAPTURE: " + path)
