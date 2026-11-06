# Diagnostic only: run with a graphical display and -- --test --hybrid output.json.
# Warm up 25 frames in each fixed scene, then sample 45 with V-Sync disabled.
extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_journey()
	game.world.set_population_active(false)
	game.world.clock.active=false
	game.economy.set_process(false)
	if "--no-grade" in OS.get_cmdline_user_args():game.hybrid.grade_rect.hide()
	var rows=[]
	for spot in [{"name":"capital","point":WorldData.SPAWN},{"name":"ferraria","point":KingdomData.point("forge")+Vector2(0,90)},{"name":"ponte","point":Vector2(WorldData.river_x(4800),4800)}]:
		game.player.position=spot.point
		game.player.restore_surface()
		game.world.ensure_region(spot.point,true)
		game.hybrid.snap_camera()
		for i in 25:
			await process_frame
			await RenderingServer.frame_post_draw
		var samples=[]
		var cpu=[]
		var calls=[]
		var stamp=Time.get_ticks_usec()
		for i in 45:
			await process_frame
			await RenderingServer.frame_post_draw
			var now=Time.get_ticks_usec()
			samples.append((now-stamp)/1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			stamp=now
		samples.sort()
		cpu.sort()
		calls.sort()
		var row={"scene":spot.name,"median_ms":samples[22],"p95_ms":samples[42],"fps":1000.0/samples[22],"cpu_ms":cpu[22],"draw_calls":calls[22]}
		rows.append(row)
		print("BENCH ",JSON.stringify(row))
	var out=OS.get_cmdline_user_args()[-1]
	var f=FileAccess.open(out,FileAccess.WRITE)
	f.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"window_size":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale,"world_size":[WorldData.SIZE.x,WorldData.SIZE.y],"loaded_regions":game.world.chunks.size(),"buildings":KingdomData.BUILDINGS.size(),"npcs":game.world.npcs.size(),"results":rows},"  "))
	quit()
