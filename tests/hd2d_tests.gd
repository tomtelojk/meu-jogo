extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame
func _initialize()->void:
	root.size=Vector2i(1280,800)
	var timer:=Timer.new();timer.wait_time=240;timer.one_shot=true;timer.autostart=true;root.add_child(timer);timer.timeout.connect(func():push_error("HD-2D timeout");quit(1))
	call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func picture()->Image:
	await frames(2);await RenderingServer.frame_post_draw;return root.get_texture().get_image()
func capture(name:String)->void:
	var image:=await picture();image.save_png("/tmp/hd2d-"+name+".png")
func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)
func settle_weather(mode:String)->void:
	game.weather_mode=mode
	for i in 3:game.hybrid.climate.update(5.0)
	await frames(3)
func cyan_bounds(image:Image)->Rect2i:
	var low:=Vector2i(image.get_width(),image.get_height());var high:=Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y)
			if c.r<0.12 and c.g>0.84 and c.b>0.84:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE) if high.x>low.x else Rect2i()
func differences(a:Image,b:Image,rect:Rect2i)->int:
	var count:=0
	for y in range(maxi(0,rect.position.y),mini(a.get_height(),rect.end.y)):
		for x in range(maxi(0,rect.position.x),mini(a.get_width(),rect.end.x)):
			var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
			if absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)>0.09:count+=1
	return count
func run()->void:
	verify(WeatherState.sample(3,600)==WeatherState.sample(3,600),"clima automático é reproduzível pelo dia e horário do save")
	var kinds:Dictionary={}
	for hour in range(0,24,3):kinds[WeatherState.sample(1,hour*60).kind]=true
	verify(kinds.has("rain") and kinds.has("mist") and kinds.has("wind") and kinds.has("clear"),"o ciclo oferece chuva, neblina, vento e céu limpo")
	var doc:=MapDocument.blank();doc.spawn=[8000,6400]
	doc.objects=[{"id":"obj_forge","kind":"forge","x":7776,"y":6272},{"id":"obj_house","kind":"timber","x":8000,"y":6600},{"id":"obj_tree","kind":"tree","x":7808,"y":6528,"size":140},{"id":"obj_tree2","kind":"autumn_tree","x":8200,"y":6200,"size":130}]
	for y in range(97,107):
		for x in range(129,137):doc.terrain["%d,%d"%[x,y]]="water"
	MapDocument.activate(doc);game=load("res://scenes/main.tscn").instantiate();game.weather_mode="clear";root.add_child(game);game.start_journey();game.world.set_population_active(false);game.economy.set_process(false)
	await frames(4);await settle_weather("clear")
	var renderer:HybridWorld=game.hybrid
	verify(renderer.grass.patches.size()==game.world.chunks.size() and renderer.grass.multimesh.instance_count>0,"grama 3D acompanha as regiões carregadas")
	var initial:=renderer.target_yaw;await key(KEY_R)
	verify(renderer.target_yaw>initial and renderer.view_yaw>initial and renderer.view_yaw<renderer.target_yaw,"tecla real gira a câmera com suavização")
	for i in 20:
		var turn:=InputEventKey.new();turn.physical_keycode=KEY_R;turn.pressed=true;renderer.camera_input(turn)
	verify(is_equal_approx(renderer.target_yaw,HybridWorld.MAX_YAW),"rotação para no limite de 35 graus")
	renderer.snap_camera();var start:=game.player.position
	Input.action_press("move_up");await frames(8);Input.action_release("move_up");await frames(1)
	var displacement:=Vector3(game.player.position.x-start.x,0,game.player.position.y-start.y)
	verify(displacement.length()>2 and absf(displacement.normalized().dot(renderer.camera.global_basis.x))<0.06 and game.player.facing=="up","W continua subindo na tela e mantém a direção correta da animação após girar")
	await key(KEY_HOME);renderer.snap_camera()
	var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_MIDDLE;button.pressed=true;button.position=Vector2(950,500);button.global_position=button.position;Input.parse_input_event(button);await frames(1)
	var drag:=InputEventMouseMotion.new();drag.position=Vector2(980,500);drag.global_position=drag.position;drag.relative=Vector2(30,0);drag.button_mask=MOUSE_BUTTON_MASK_MIDDLE;Input.parse_input_event(drag);await frames(1)
	verify(renderer.target_yaw<0,"arrastar com o botão do meio gira a câmera")
	button=button.duplicate();button.pressed=false;button.position=Vector2(100,100);button.global_position=button.position;Input.parse_input_event(button);await frames(2)
	verify(not renderer.dragging_camera,"soltar o botão sobre a interface não deixa a câmera presa no arraste")
	await key(KEY_HOME);renderer.snap_camera()
	game.hud.sound_button.grab_focus()
	var page:=InputEventKey.new();page.keycode=KEY_PAGEUP;page.pressed=true;Input.parse_input_event(page);await frames(1)
	page=page.duplicate();page.pressed=false;Input.parse_input_event(page)
	verify(renderer.target_zoom<13,"PgUp funciona mesmo quando um botão do HUD tem foco e o sistema envia apenas a tecla lógica")
	await key(KEY_HOME);renderer.snap_camera()
	var slot:=game.equipped_slot
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.ctrl_pressed=true;wheel.position=Vector2(950,500);wheel.global_position=wheel.position;Input.parse_input_event(wheel);await frames(2)
	verify(renderer.target_zoom<13 and game.equipped_slot==slot,"Ctrl+roda altera zoom sem trocar o item da hotbar")
	wheel=wheel.duplicate();wheel.ctrl_pressed=false;Input.parse_input_event(wheel);await frames(2)
	verify(game.equipped_slot!=slot,"roda sem Ctrl preserva a seleção da hotbar")
	renderer.restore_view({"zoom":-100,"yaw":100});verify(renderer.target_zoom==8 and renderer.target_yaw<=HybridWorld.MAX_YAW,"zoom e giro inválidos são limitados")
	var saved:=game.journey_data();verify(saved.visual.zoom==8 and saved.visual.yaw==renderer.target_yaw and saved.visual.weather=="clear","save preserva câmera e preferência de clima")
	renderer.restore_view({"zoom":13,"yaw":0});renderer.snap_camera()
	var ground:=game.player.position+Vector2(150,100);var pixel:=renderer.camera.unproject_position(renderer._point(ground))
	verify(renderer.world_position(pixel).distance_to(ground)<0.01,"clique de construção mantém a projeção correta no chão 3D")
	await occlusion_pixels()
	await billboard_and_shadow()
	await reactive_grass()
	await capture("claro")
	await settle_weather("rain")
	verify(renderer.climate.rain.emitting and renderer.climate.splash.emitting and renderer.climate.rain_amount>0.95,"chuva e respingos são partículas 3D ativas")
	verify(renderer.climate.rain_material.get_shader_parameter("shelters").size()==16,"chuva recebe coberturas para não atravessar as casas")
	var rain_sun:=renderer.sunlight.light_energy;await capture("chuva")
	await settle_weather("mist");verify(renderer.atmosphere.environment.fog_depth_begin<12 and not renderer.climate.rain.emitting,"neblina aproxima a distância de visibilidade e encerra a chuva")
	await capture("neblina");await settle_weather("wind")
	verify(renderer.grass.material.get_shader_parameter("wind_strength")>2 and renderer.foliage_materials[0].get_shader_parameter("wind_strength")>2,"ventania atua na grama e nas árvores")
	await settle_weather("clear");verify(renderer.sunlight.light_energy>rain_sun,"nuvens reduzem a luz do sol e o céu limpo a recupera")
	game.world.clock.set_time(21);game.lantern_enabled=true;await frames(5)
	var lamps:=0
	for lamp in renderer.street_lamps:
		if lamp.visible:lamps+=1
	verify(lamps>0 and renderer.lantern.visible and BuildingVisual.shared_material.get_shader_parameter("night")>0.9,"noite acende tochas, janelas e lanterna")
	game.light_graphics=false;renderer.set_light_graphics(false);await frames(5)
	verify(renderer.grade_rect.visible and renderer.sunlight.shadow_enabled,"modo HD-2D ativa pós-processamento e sombras projetadas")
	verify(renderer.actors[0].card.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"sprites também participam das sombras do sol em HD-2D")
	await capture("noite")
	verify(renderer.reflection.active and renderer.reflection.refreshes>0 and renderer.reflection.mirror.cull_mask==1,"água captura a cena refletida sem realimentar água, chão ou chuva")
	await RenderingServer.frame_post_draw
	var reflection:=renderer.reflection.get_texture().get_image();reflection.save_png("/tmp/hd2d-reflexo.png")
	var shades:Dictionary={}
	for y in range(0,reflection.get_height(),3):
		for x in range(0,reflection.get_width(),3):shades[reflection.get_pixel(x,y).to_html()]=true
	verify(shades.size()>8,"textura de reflexão contém geometria renderizada de verdade")
	renderer.set_shaders(false);await frames(3)
	verify(not renderer.grade_rect.visible and not renderer.climate.rain.emitting and not renderer.atmosphere.environment.fog_enabled,"opção de efeitos desliga blur, bloom e clima adicional")
	renderer.set_shaders(true);game.light_graphics=true;renderer.set_light_graphics(true);await settle_weather("clear");game.world.clock.set_time(8.5)
	game.lantern_enabled=false;game.hud.root.hide();game.light_graphics=false;renderer.set_light_graphics(false)
	var daylight:=await picture();var clipped:=0;var pixels:=0
	for y in range(0,daylight.get_height(),4):
		for x in range(0,daylight.get_width(),4):
			var color:=daylight.get_pixel(x,y);pixels+=1
			if maxf(color.r,maxf(color.g,color.b))>0.98:clipped+=1
	verify(clipped<float(pixels)*0.05,"ativar sombras HD-2D preserva a exposição diurna sem saturar o cenário")
	game.hud.root.show()
	await postprocess_pixels()
	print("HD2D: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)
func occlusion_pixels()->void:
	var renderer:HybridWorld=game.hybrid
	var house:BuildingVisual=renderer.architecture.get_node("obj_house")
	verify(house.faded,"apenas a casa que encobre o personagem usa o material de transparência")
	game.hud.root.hide();renderer.set_process(false)
	house.visual_mesh.material_override=BuildingVisual.shared_material;var opaque:=await picture()
	house.visual_mesh.material_override=BuildingVisual.shared_fade_material;var revealed:=await picture()
	var point:=renderer.camera.unproject_position(renderer._point(game.player.position)+Vector3(0,0.55,0))
	verify(differences(opaque,revealed,Rect2i(Vector2i(point)-Vector2i(50,75),Vector2i(100,150)))>80,"fade abre pixels visíveis ao redor do jogador atrás do telhado")
	renderer.set_process(true);game.hud.root.show()
func billboard_and_shadow()->void:
	var renderer:HybridWorld=game.hybrid;game.hud.root.hide();renderer.grass.hide()
	for material in renderer.foliage_materials:material.set_shader_parameter("wind_strength",0.0)
	var image:=Image.create(16,32,false,Image.FORMAT_RGBA8);image.fill(Color.CYAN)
	var source:=AnimatedSprite2D.new();source.sprite_frames=SpriteFrames.new();source.sprite_frames.add_frame("default",ImageTexture.create_from_image(image));source.scale=Vector2.ONE*4;source.position.y=-64
	var card:=renderer._card(source);card.position=renderer._point(game.player.position)+Vector3(-5,1.5,0)
	var a:=cyan_bounds(await picture());renderer.restore_view({"zoom":13,"yaw":HybridWorld.MAX_YAW});renderer.snap_camera();var b:=cyan_bounds(await picture())
	verify(a.size.x>5 and absi(a.size.x-b.size.x)<=2 and absi(a.size.y-b.size.y)<=2,"pixels do billboard preservam largura e altura ao girar a câmera")
	card.free();renderer.restore_view({"zoom":13,"yaw":0});renderer.snap_camera()
	var body:=ForestPlayer.new();body.sprite=source;body.position=game.player.position+Vector2(-256,0);body.visible=false;renderer._shadow(body)
	var entry:Dictionary=renderer.actors[-1];var off:=await picture();body.visible=true;var on:=await picture()
	var center:=renderer.camera.unproject_position(renderer._point(body.position))
	verify(differences(off,on,Rect2i(Vector2i(center)-Vector2i(160,160),Vector2i(320,320)))>35,"sombra baseada na silhueta do sprite realmente escurece o chão 3D")
	renderer.actors.erase(entry);entry.shadow.free();body.free();source.free();renderer.grass.show();game.hud.root.show()
func reactive_grass()->void:
	var renderer:HybridWorld=game.hybrid;renderer.set_process(false);renderer.grass.hide();game.hud.root.hide()
	var tuft:=MultiMeshInstance3D.new();tuft.multimesh=MultiMesh.new();tuft.multimesh.transform_format=MultiMesh.TRANSFORM_3D;tuft.multimesh.mesh=renderer.grass.multimesh.mesh;tuft.multimesh.instance_count=1
	var at:=renderer._point(game.player.position)+Vector3(-4,0.015,4);tuft.multimesh.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*2.5),at))
	var material:ShaderMaterial=renderer.grass.material.duplicate();material.set_shader_parameter("wind_strength",0.0);material.set_shader_parameter("hero",Vector3(1000,0,1000));tuft.material_override=material;renderer.add_child(tuft)
	var upright:=await picture();material.set_shader_parameter("hero",at+Vector3(0.1,0,0));var pressed:=await picture();var pixel:=renderer.camera.unproject_position(at)
	verify(differences(upright,pressed,Rect2i(Vector2i(pixel)-Vector2i(80,100),Vector2i(160,130)))>10,"grama muda os pixels e se curva com a passagem do jogador")
	tuft.free();game.hud.root.show();renderer.grass.show();renderer.set_process(true)
func postprocess_pixels()->void:
	var view:=SubViewport.new();view.size=Vector2i(512,256);view.disable_3d=true;view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var image:=Image.create(512,256,false,Image.FORMAT_RGB8);image.fill(Color(0.1,0.1,0.1))
	for y in 256:
		for x in range(0,240):image.set_pixel(x,y,Color(0.85,0.85,0.85) if x%2 else Color(0.05,0.05,0.05))
	image.fill_rect(Rect2i(350,150,8,8),Color(1,0.95,0.8))
	var background:=TextureRect.new();background.texture=ImageTexture.create_from_image(image);background.size=Vector2(512,256);view.add_child(background)
	var post:=ColorRect.new();post.size=Vector2(512,256);var material:=ShaderMaterial.new();material.shader=load("res://game/shaders/grade.gdshader");material.set_shader_parameter("strength",0.0);material.set_shader_parameter("dof_strength",1.0);material.set_shader_parameter("bloom_strength",0.0);material.set_shader_parameter("pixel_size",Vector2(1.0/512,1.0/256));post.material=material;post.hide();view.add_child(post)
	await frames();await RenderingServer.frame_post_draw;var base:=view.get_texture().get_image()
	post.show();await frames();await RenderingServer.frame_post_draw;var blurred:=view.get_texture().get_image()
	var far_before:=0.0;var far_after:=0.0;var focus_before:=0.0;var focus_after:=0.0
	for x in range(10,220):
		far_before+=absf(base.get_pixel(x,15).r-base.get_pixel(x+1,15).r);far_after+=absf(blurred.get_pixel(x,15).r-blurred.get_pixel(x+1,15).r)
		focus_before+=absf(base.get_pixel(x,128).r-base.get_pixel(x+1,128).r);focus_after+=absf(blurred.get_pixel(x,128).r-blurred.get_pixel(x+1,128).r)
	verify(far_after<far_before*0.65 and focus_after>focus_before*0.85,"blur reduz contraste distante e preserva os pixels na faixa de foco")
	material.set_shader_parameter("dof_strength",0.0);material.set_shader_parameter("bloom_strength",1.0);await frames();await RenderingServer.frame_post_draw;var glow:=view.get_texture().get_image()
	verify(glow.get_pixel(349,153).r>base.get_pixel(349,153).r+0.04,"bloom cria halo mensurável ao redor de uma luz")
	view.queue_free()
