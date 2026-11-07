extends SceneTree

var game:ForestGame
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func run()->void:
	var document:=MapDocument.blank();document.id="portal_tests"
	for row in 2:
		for turn in 4:
			document.objects.append({"id":"obj_service_"+str(row)+"_"+str(turn),"kind":"forge" if row==0 else "tavern","name":"Serviço girado","x":6500+turn*1100,"y":5000+row*1200,"style":0,"house_style":"shop" if row==0 else "tavern","house_seed":42,"house_turn":turn})
	var checked:=MapDocument.validate(document);verify(checked.ok,"mapa com oito serviços girados é válido")
	MapDocument.activate(checked.document)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(4);game.start_journey()
	for data in KingdomData.buildings():
		game.player.position=HouseKit.approach(data);game.player.restore_surface();await frames()
		var interaction:=game.current_interaction()
		verify(interaction.get("id")==data.id and interaction.get("kind") in ["shop","inn"],"E encontra serviço na fachada girada: "+data.id)
		game.interact();await frames()
		verify(game.hud.modal_kind in ["shop","inn"],"serviço girado mantém o comércio: "+data.id)
		verify(game.housing.enter(data.id),"porta girada aceita transição: "+data.id)
		await frames()
		game.player.position=game.housing.room.spawn_point;game.interact();await frames()
		verify(not game.housing.inside() and game.player.position.distance_to(HouseKit.approach(data))<1,"saída retorna à fachada girada: "+data.id)
	game.free();await frames();MapDocument.activate(MapDocument.original())
	print("PORTAS: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)
