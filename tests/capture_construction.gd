# Optional graphical capture of a furnished modular home. Uses a separate test
# map and --test, so the player's adventure and inventory are never modified.
extends SceneTree
var game:ForestGame
func _initialize()->void:call_deferred("run")
func frames(count:int=4)->void:
	for i in count:await process_frame;await RenderingServer.frame_post_draw
func run()->void:
	var document:=MapDocument.blank();document.id="construction_showcase";document.name="Um lar entre os reinos";document.spawn=[8000,6528]
	document.objects=[{"id":"obj_carpenter","kind":"npc","x":8000,"y":6400,"name":"Bento","appearance":"bento"},{"id":"obj_artisan","kind":"npc","x":8128,"y":6464,"name":"Lia","appearance":"lia"},{"id":"obj_tree","kind":"tree","x":7712,"y":6432},{"id":"obj_autumn","kind":"autumn_tree","x":8384,"y":6272}]
	MapDocument.activate(MapDocument.validate(document).document)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();game.world.set_population_active(false);game.economy.set_process(false);game.player.set_physics_process(false)
	game.rpg.tools.hammer=true;game.rpg.wood=1200;game.rpg.stone=600;game.rpg.copper=30;game.rpg.construction.stock.plank=80
	for y in range(98,104):
		for x in range(122,129):piece("wood_floor",x,y)
	for x in range(122,129):
		piece("wood_wall",x,98)
		piece("door" if x==125 else "wood_wall",x,103)
	for y in range(99,103):piece("wood_wall",122,y,1);piece("wood_wall",128,y,1)
	var bed:=piece("bed",123,99);var bed2:=piece("bed",123,101)
	var station:=piece("workbench",125,99);var forge:=piece("forge",126,99)
	piece("table",125,101);piece("bench",126,102);piece("torch",127,102);piece("torch",124,102)
	for id in game.rpg.construction.pieces:
		if game.rpg.construction.pieces[id].kind=="door":game.rpg.construction.pieces[id].open=true;game.rpg.construction.piece_changed.emit(id)
	game.rpg.construction.assign(game.rpg,bed,"obj_carpenter","resident");game.rpg.construction.assign(game.rpg,bed2,"obj_artisan","resident")
	game.rpg.construction.assign(game.rpg,station,"obj_carpenter","worker");game.rpg.construction.assign(game.rpg,forge,"obj_artisan","worker")
	game.world.clock.set_time(10);game.weather_mode="clear"
	for npc in game.world.npcs.values():npc.set_physics_process(false);npc.position=npc.work_override;npc.state="work";npc.refresh_presence()
	game.hybrid.restore_view({"zoom":12.0,"yaw":-0.12});game.hybrid.snap_camera()
	for i in 3:game.hybrid.climate.update(8)
	await frames(15);game.hud.interaction_panel.hide();game.hud.toast_panel.hide();game.elapsed_hud=0
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/construction-assentamento.png")
	print("CONSTRUCTION CAPTURE: %d peças, dois moradores e duas estações."%game.rpg.construction.pieces.size());quit()
func piece(kind:String,x:int,y:int,turn:int=0)->String:
	var result:=game.rpg.construction.place(game.rpg,kind,Vector2i(x,y),turn)
	if not result.ok:push_error(result.message);quit(1);return ""
	return result.id
