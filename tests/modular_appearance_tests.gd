extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame
func _initialize()->void:call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await process_frame;await physics_frame
func delta_color(a:Color,b:Color)->float:return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func capture(path:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func sample_profile(id:String)->Dictionary:
	return {"id":id,"name":"Morador","role":"Agricultor","realm":"aurelia"}

func run()->void:
	MapDocument.activate(MapDocument.original())
	var profiles:=KingdomData.people().duplicate(true)
	var saved:=AppearanceGenerator.prepare(profiles)
	var first:Dictionary={};var names:Dictionary={};var voices:Dictionary={};var text:Dictionary={};var pieces:Dictionary={}
	var generated:=true;var roles:=true;var files:=true;var scales:Dictionary={}
	var audio:=ForestAudio.new();root.add_child(audio)
	for profile in profiles:
		var data:=AppearanceGenerator.for_profile(profile);first[profile.id]=data.visual_key();names[profile.name]=true;pieces[data.piece_key()]=true
		voices[audio.voice_stream(data).data.hex_encode().sha256_text()]=true;text[AppearanceGenerator.greeting(profile)]=true
		scales[snappedf(data.stature,0.001)]=true
		generated=generated and data is AppearanceData and data.seed==AppearanceGenerator.id_seed(profile.id) and data.stature>=0.945 and data.stature<=1.055
		if FactionCatalog.guard(profile):roles=roles and data.clothing=="armor" and data.hat in ["helmet","crested_helmet"]
		if data.role=="noble":roles=roles and data.clothing in ["finery","robe"]
		if data.role=="peasant":roles=roles and data.clothing in ["tunic","workshirt","dress"]
		roles=roles and data.accent_color==AppearanceGenerator.faction_color(data.faction)
		for layer in AppearanceGenerator.LAYERS:files=files and ResourceLoader.exists(ModularSpriteSheet.BASE+layer+"/"+String(data.get(layer))+".png")
		verify(data.palette().size()==32 and data.palette()[3]==data.skin,"paleta indexada preserva pele e cores separadas: "+profile.id)
	verify(generated and files,"44 identidades têm Resource, seed por ID, escala limitada e cinco camadas existentes")
	verify(roles,"profissões e membros de facção respeitam armadura, traje, chapéu e cor")
	var member:=sample_profile("guild_member");member.faction="guild_artisans"
	var uniform:=AppearanceGenerator.generate(member)
	verify(uniform.faction=="artisans" and uniform.clothing_color==AppearanceGenerator.faction_color("artisans").darkened(0.12),"membro explícito usa as cores da guilda, mesmo fora do seu reino")
	var document:=MapDocument.blank();document.objects=[{"id":"obj_guild_member","kind":"npc","name":"Morador","x":8000,"y":6400,"appearance":"bento","faction":"guild_artisans"}]
	var restored:=MapDocument.validate(document)
	verify(restored.ok and restored.document.objects[0].faction=="artisans","importação e exportação de mapa preservam a facção visual do NPC")
	verify(first.values().size()==44 and first.values().all(func(key):return first.values().count(key)==1),"toda a população tem combinação visual única, inclusive quando vizinhos se movem")
	verify(pieces.size()>30 and scales.size()>15,"variação inclui peças e estaturas, além de cores")
	verify(names.size()==44 and text.size()==44 and voices.size()==44,"nomes, falas e assinaturas sonoras diferem entre os 44 NPCs")
	var bento:=AppearanceGenerator.for_profile(KingdomData.person("bento"))
	audio.speak(bento,"teste");verify(not audio.voice.playing,"vozes respeitam a opção Som desligado")
	audio.enabled=true;audio.speak(bento,"uma fala de teste suficientemente longa")
	verify(audio.voice.playing and is_equal_approx(audio.voice.pitch_scale,bento.voice_pitch),"fala real usa o timbre e o pitch do NPC em um canal separado")
	audio.enabled=false;audio.voice.stop()
	profiles.reverse();AppearanceGenerator.prepare(profiles)
	var stable:=true
	for profile in profiles:stable=stable and first[profile.id]==AppearanceGenerator.for_profile(profile).visual_key()
	verify(stable,"ordem de spawn não altera as escolhas geradas por ID")
	AppearanceGenerator.prepare(profiles,JSON.parse_string(JSON.stringify(saved)))
	stable=true
	for profile in profiles:stable=stable and first[profile.id]==AppearanceGenerator.for_profile(profile).visual_key()
	verify(stable,"JSON do save mantém a aparência depois de recarregar")
	var clone:=AppearanceGenerator.generate(sample_profile("same_piece_test"))
	var recolor:=clone.duplicate(true) as AppearanceData
	recolor.clothing_color=Color("b64c64");recolor.hair_color=Color("c5b381")
	verify(ModularSpriteSheet.read(clone).frames==ModularSpriteSheet.read(recolor).frames and clone.palette()!=recolor.palette(),"trocar a paleta reutiliza as mesmas peças e os mesmos quadros")
	await _collision_and_names()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();await frames(3)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ModularSpriteSheet.BASE+"manifest.json"))
	var valid_art:bool=manifest.files.size()==36
	for file in manifest.files:
		var texture:=load("res://"+file.path) as Texture2D
		valid_art=valid_art and texture.get_size()==Vector2(240,512) and FileAccess.get_sha256("res://"+file.path)==file.sha256
	verify(valid_art,"36 spritesheets separados têm dimensões, origem e hashes registrados")
	var unique:Dictionary={};var pivot:=true
	for npc in game.world.npcs.values():
		unique[npc.appearance_data.visual_key()]=true
		for direction in CharacterSheet.DIRECTIONS:
			npc.sprite.animation="walk_"+direction
			pivot=pivot and is_equal_approx(npc.sprite.position.y+(ModularSpriteSheet.SOLE_Y-32)*npc.sprite.scale.y,2)
	verify(unique.size()==game.world.npcs.size() and pivot,"NPCs reais usam as camadas e preservam o pivô em todas as direções")
	var rendered:Dictionary={};var population:Array=[]
	for npc in game.world.npcs.values():
		var data:AppearanceData=npc.appearance_data;var palette:=data.palette()
		var art:Image=npc.sprite.sprite_frames.get_frame_texture("idle_down",0).get_image()
		var pixels:=PackedByteArray();pixels.resize(48*64*4)
		for y in 64:
			for x in 48:
				var pixel:Color=art.get_pixel(x,y)
				pixels.encode_u32((y*48+x)*4,palette[roundi(pixel.r*255)].to_rgba32() if pixel.a>0.5 else 0)
		rendered[pixels.hex_encode().sha256_text()]=true
		population.append({"id":npc.definition.id,"name":data.display_name,"role":data.role,"faction":data.faction,"body":data.body,"hair":data.hair,"clothing":data.clothing,"accessory":data.accessory,"hat":data.hat,"skin":data.skin.to_html(false),"hair_color":data.hair_color.to_html(false),"clothing_color":data.clothing_color.to_html(false),"accent_color":data.accent_color.to_html(false),"stature":data.stature,"voice_pitch":data.voice_pitch,"voice_timbre":data.voice_timbre,"voice_cadence":data.voice_cadence,"variant":data.variant})
	verify(rendered.size()==game.world.npcs.size(),"desenhos frontais coloridos também são distintos, além dos dados de combinação")
	var report:=FileAccess.open("/tmp/modular-populacao.json",FileAccess.WRITE);report.store_string(JSON.stringify({"version":1,"count":population.size(),"unique_front_images":rendered.size(),"npcs":population},"  "))
	var snapshot:=game.journey_data();var actual:Dictionary={}
	for npc in game.world.npcs.values():actual[npc.definition.id]=npc.appearance_data.visual_key()
	game.apply_journey(JSON.parse_string(JSON.stringify(snapshot)))
	stable=true
	for npc in game.world.npcs.values():stable=stable and actual[npc.definition.id]==npc.appearance_data.visual_key()
	verify(stable and snapshot.npc_appearances.size()==44,"save real da aventura restaura as 44 identidades")
	game.npc_sprite_target="bento"
	verify(game.import_npc_sprite("res://assets/npcs/bento.png") and not ModularSpriteSheet.is_sheet(game.world.npcs.bento.sprite.sprite_frames),"importação individual ainda permite uma prancha completa")
	verify(game.world.npcs.bento.appearance_data.seed==AppearanceGenerator.id_seed("bento"),"importar uma prancha mantém a identidade sonora do morador")
	game.restore_modular_npc("bento")
	verify(ModularSpriteSheet.is_sheet(game.world.npcs.bento.sprite.sprite_frames) and not game.npc_sprite_overrides.has("bento"),"restaurar modular remove só a preferência de importação")
	if game.hybrid!=null:
		await _palette_render(clone,recolor)
		await _spatial_palette(clone)
		await _gallery()
		await frames(3)
		var valid_cards:=true
		for actor in game.hybrid.actors:
			if actor.has("card") and actor.body is ForestNPC:valid_cards=valid_cards and actor.card.material_override.get_shader_parameter("indexed_palette")==true
		verify(valid_cards,"billboards 3D usam a paleta de cada NPC no material real")
		await capture("/tmp/modular-mundo.png")
	print("MODULAR: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)

func _collision_and_names()->void:
	var seen:Dictionary={};var pair:Array=[]
	for i in 4000:
		var profile:=sample_profile("collision_"+str(i));var key:=AppearanceGenerator.generate(profile).visual_key()
		if seen.has(key):pair=[seen[key],profile];break
		seen[key]=profile
	verify(pair.size()==2,"amostra reproduz uma colisão real de opções e paleta")
	if pair.size()==2:
		var records:=AppearanceGenerator.prepare(pair)
		var old:Dictionary={}
		for profile in pair:old[profile.id]=AppearanceGenerator.for_profile(profile).visual_key()
		verify(old.values()[0]!=old.values()[1] and records.values().max()>0,"alocação resolve a colisão com outra variante determinística")
		pair.push_front(sample_profile("aaaaaaaa_new_resident"));AppearanceGenerator.prepare(pair,records)
		var preserved:=true
		for id in old:preserved=preserved and old[id]==AppearanceGenerator.assigned[id].visual_key()
		verify(preserved,"adicionar morador preserva as variantes já salvas")
	var crowd:Array=[]
	for i in 320:crowd.append(sample_profile("crowd_"+str(i)))
	AppearanceGenerator.prepare(crowd)
	var names:Dictionary={};var signatures:Dictionary={}
	for p in crowd:names[p.name]=true;signatures[AppearanceGenerator.for_profile(p).visual_key()]=true
	verify(names.size()==320 and signatures.size()==320,"população densa supera o banco inicial de nomes sem duplicação ou loop")
	verify(AppearanceGenerator.valid_records({"bad":INF,"negative":-1,"text":"7","valid":2})=={"valid":2},"dados malformados de aparência são recusados")

func _sprite(data:AppearanceData)->AnimatedSprite2D:
	var sprite:=AnimatedSprite2D.new();var source:=ModularSpriteSheet.read(data)
	sprite.sprite_frames=source.frames;sprite.animation="idle_down";sprite.scale=Vector2.ONE*2
	var material:=ShaderMaterial.new();material.shader=load("res://game/shaders/npc_palette.gdshader")
	material.set_shader_parameter("index_art",source.texture);material.set_shader_parameter("palette_map",data.palette_texture());sprite.material=material
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _palette_render(a:AppearanceData,b:AppearanceData)->void:
	var view:=SubViewport.new();view.size=Vector2i(320,200);view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var left:=_sprite(a);left.position=Vector2(80,90);view.add_child(left)
	var right:=_sprite(b);right.position=Vector2(240,90);view.add_child(right)
	await frames(4);await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image();image.save_png("/tmp/modular-palette-test.png")
	var art:=left.sprite_frames.get_frame_texture("idle_down",0).get_image()
	var skin:=0;var changed:=0;var correct:=0
	for y in 64:
		for x in 48:
			var pixel:=art.get_pixel(x,y)
			if pixel.a<0.5:continue
			var index:=roundi(pixel.r*255)
			var first:=image.get_pixel(32+x*2+1,26+y*2+1);var second:=image.get_pixel(192+x*2+1,26+y*2+1)
			if index in [2,3,4] and delta_color(first,second)<0.03:skin+=1
			if index in [8,9,10] and delta_color(first,second)>0.15:changed+=1
			if delta_color(first,a.palette()[index])<0.04:correct+=1
	verify(skin>30 and changed>40 and correct>250,"shader 2D troca cores da roupa e cabelo e preserva pixels da pele")
	view.queue_free();await frames(1)

func _spatial_palette(data:AppearanceData)->void:
	var view:=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.2;camera.position=Vector3(0,0,10);view.add_child(camera);camera.current=true
	var sprite:=Sprite3D.new();var texture:=ImageTexture.create_from_image(ModularSpriteSheet.read(data).frames.get_frame_texture("idle_down",0).get_image())
	sprite.texture=texture;sprite.pixel_size=0.05;view.add_child(sprite)
	var shader:=Shader.new();shader.code=HybridWorld.BILLBOARD_SHADER
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("art",texture);material.set_shader_parameter("index_art",texture);material.set_shader_parameter("palette_map",data.palette_texture());material.set_shader_parameter("indexed_palette",true);material.set_shader_parameter("tex_size",Vector2(48,64));sprite.material_override=material
	await frames(6);await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image();image.save_png("/tmp/modular-spatial-palette-test.png")
	var skin:=0;var cloth:=0
	for y in 256:
		for x in 256:
			var color:=image.get_pixel(x,y)
			if color.a<0.5:continue
			if delta_color(color,data.skin)<0.1:skin+=1
			if delta_color(color,data.clothing_color)<0.1:cloth+=1
	verify(skin>100 and cloth>100,"shader 3D reproduz as cores da pele e roupa sem escurecer o índice")
	view.queue_free();await frames(1)

func _gallery()->void:
	var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer)
	var background:=ColorRect.new();background.color=Color("1c292d");background.size=Vector2(1280,800);layer.add_child(background)
	var title:=Label.new();title.text="ENTRE REINOS · 44 IDENTIDADES MODULARES";title.position=Vector2(25,12);title.add_theme_font_override("font",load("res://assets/ui/rpg_pixel.fnt"));title.add_theme_font_size_override("font_size",20);layer.add_child(title)
	var index:=0
	for npc in game.world.npcs.values():
		var sprite:=_sprite(npc.appearance_data);sprite.position=Vector2(58+index%11*116,112+index/11*178);sprite.scale=Vector2.ONE*1.6;layer.add_child(sprite)
		var label:=Label.new();label.text=npc.definition.name+"\n"+npc.definition.role;label.position=Vector2(index%11*116,158+index/11*178);label.size=Vector2(116,40);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.clip_text=true;label.add_theme_font_override("font",load("res://assets/ui/rpg_pixel.fnt"));label.add_theme_font_size_override("font_size",8);layer.add_child(label)
		index+=1
	await frames(3);await capture("/tmp/modular-galeria.png")
	layer.queue_free();await frames(2)
