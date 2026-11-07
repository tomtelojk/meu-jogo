class_name AppearanceGenerator
extends RefCounted

const VERSION:=1
const LAYERS:=["body","hair","clothing","accessory","hat"]
const SKIN:=["e9bb8b","d8a177","c58b61","ae7653","8f5d45","704a38"]
const HAIR:=["3a2b2a","68432c","956637","bca160","9d492c","c1b6a1","e5d4b8","47414c"]
const CLOTH:=["69734c","8d5b43","5e7787","825967","b69a67","586b65","876d91","bf9b82","556487","a36a53","697b4f","8d7b59"]
const FIRST:=["Amaro","Alina","Breno","Cecília","Dário","Estela","Gaspar","Helena","Júlio","Leona","Martim","Noemi","Otávio","Pilar","Ramiro","Serena","Tadeu","Úrsula","Vicente","Zélia","Leonor","Artur","Rosa","Baltasar"]
const LAST:=["do Vale","dos Cedros","Ribeiro","da Ponte","do Prado","Monteiro","da Serra","das Fontes","dos Reis","da Costa","do Campo","Carvalho"]
static var templates:Dictionary={}
static var assigned:Dictionary={}
static var records:Dictionary={}

static func id_seed(id:String)->int:return String("npc-appearance-v1:"+id).sha256_text().left(12).hex_to_int()

static func role_for(profile:Dictionary)->String:
	if FactionCatalog.guard(profile):return "guard"
	var role:=String(profile.get("role","")).to_lower()
	if profile.get("appearance",profile.id) in ["aurel","caio"] or "rei " in role or "nobre" in role:return "noble"
	if "ferreir" in role or "artes" in role or "construtor" in role:return "artisan"
	if "merc" in role or "comerci" in role:return "merchant"
	if "cartógraf" in role or "sábio" in role:return "scholar"
	if "herbal" in role:return "ranger"
	return "peasant"

static func template(role:String)->AppearanceData:
	if not templates.has(role):templates[role]=load("res://game/data/appearances/"+role+".tres") as AppearanceData
	return templates[role]

static func faction_for(profile:Dictionary)->String:
	FactionCatalog.load_data()
	var specified:String=String(profile.get("faction","")).trim_prefix("guild_")
	if FactionCatalog.data.factions.has(specified) or FactionCatalog.data.guilds.has(specified):return specified
	for id in FactionCatalog.data.guilds:
		if FactionCatalog.guild(id).master==profile.id:return id
	return profile.get("realm","aurelia")

static func faction_color(id:String)->Color:
	var guild:=FactionCatalog.guild(id)
	if not guild.is_empty():return Color(guild.color)
	return KingdomData.REALMS.get(id,KingdomData.REALMS.aurelia).color

static func generate(profile:Dictionary,variant:int=0)->AppearanceData:
	var role:=role_for(profile);var data:=template(role).duplicate(true) as AppearanceData
	var rng:=RandomNumberGenerator.new();data.seed=id_seed(profile.id);data.variant=variant
	rng.seed=data.seed+variant*104729
	for layer in LAYERS:
		var options:PackedStringArray=data.get(layer+"_options")
		data.set(layer,options[rng.randi_range(0,options.size()-1)])
	data.skin=Color(SKIN[rng.randi_range(0,SKIN.size()-1)])
	data.hair_color=Color(HAIR[rng.randi_range(0,HAIR.size()-1)])
	data.clothing_color=Color(CLOTH[rng.randi_range(0,CLOTH.size()-1)])
	data.faction=faction_for(profile);data.accent_color=faction_color(data.faction)
	if role in ["guard","noble"] or FactionCatalog.data.guilds.has(data.faction):data.clothing_color=data.accent_color.darkened(0.24 if role=="guard" else 0.12)
	if profile.id in ["aurel","caio"]:data.hat="crown"
	if profile.id in ["bento","eron"]:data.hair="beard";data.hair_color=Color("bcb7a8")
	if profile.id=="aurel":data.hair_color=Color("bfa06a")
	data.leather_color=Color("806047").lightened(rng.randf_range(-0.12,0.16))
	data.metal_color=Color("9da4aa").lerp(Color("c2ad82"),rng.randf_range(0,0.22))
	data.eye_color=Color(["354839","514346","3c5460","6a512f"][rng.randi_range(0,3)])
	data.stature=1.0+rng.randf_range(-0.055,0.055)
	data.voice_pitch=rng.randf_range(0.84,1.22)
	data.voice_timbre=rng.randi_range(0,4);data.voice_cadence=rng.randf_range(0.075,0.13)
	data.speech_style=rng.randi_range(0,3);data.role=role;data.display_name=profile.get("name",generated_name(profile.id))
	return data

static func generated_name(id:String,attempt:int=0)->String:
	var seed:=id_seed(id)+attempt*37
	var suffix:=" "+str(attempt/(FIRST.size()*LAST.size())+1) if attempt>=FIRST.size()*LAST.size() else ""
	return FIRST[posmod(seed,FIRST.size())]+" "+LAST[posmod(seed/31,LAST.size())]+suffix

## Allocate the whole roster before spawning. Saved variants get priority, so
## adding a new resident cannot change an existing resident after reloading.
## Distinct pieces + palettes across the roster also cover moving neighbors.
static func prepare(profiles:Array,stored:Dictionary={})->Dictionary:
	assigned.clear();records.clear()
	var ordered:=profiles.duplicate()
	ordered.sort_custom(func(a:Dictionary,b:Dictionary):
		var priority_a:=0 if a.id in MapDocument.FACES else (1 if stored.has(a.id) else 2)
		var priority_b:=0 if b.id in MapDocument.FACES else (1 if stored.has(b.id) else 2)
		return priority_a<priority_b if priority_a!=priority_b else String(a.id)<String(b.id))
	var occupied:Dictionary={};var names:Dictionary={}
	for profile in ordered:
		var value:Variant=stored.get(profile.id,0)
		var attempt:=clampi(int(value),0,65535) if ResourceProgress.number(value) else 0
		var data:=generate(profile,attempt)
		while occupied.has(data.visual_key()):
			attempt+=1;data=generate(profile,attempt)
			if attempt>100000:break # Larger than the bounded map's NPC population.
		var name:String=profile.get("name","")
		if name in ["","Morador","Ferreiro","Comerciante","Guarda","Herbalista","Sábio","Camponesa","Agricultor"]:name=generated_name(profile.id)
		var serial:=0
		while names.has(name):serial+=1;name=generated_name(profile.id,serial)
		names[name]=true;profile.name=name;data.display_name=name
		occupied[data.visual_key()]=true;assigned[profile.id]=data;records[profile.id]=attempt
	return records.duplicate()

static func for_profile(profile:Dictionary)->AppearanceData:
	if not assigned.has(profile.id):assigned[profile.id]=generate(profile)
	return assigned[profile.id]

static func valid_records(raw:Variant)->Dictionary:
	var clean:Dictionary={}
	if not raw is Dictionary or raw.size()>10000:return clean
	for id in raw:
		if id is String and ResourceProgress.number(raw[id]) and int(raw[id])>=0 and int(raw[id])<=65535:clean[id]=int(raw[id])
	return clean

static func greeting(profile:Dictionary)->String:
	var data:=for_profile(profile)
	var openings:=["Olá, viajante.","Que os caminhos te sejam leves.","Ah, uma visita!","Bom encontrar você por aqui."]
	var work:Dictionary={"guard":["Fico de olho em quem cruza estas estradas.","Uma ponte segura vale uma noite tranquila.","Confira seu equipamento antes de seguir viagem."],"noble":["As decisões daqui chegam até o último povoado.","Meu povo precisa de caminhos e de bons vizinhos.","Quero ouvir notícias além dos muros."],"peasant":["Gosto de ver o resultado do trabalho no fim do dia.","Hoje ainda quero passar na feira antes de voltar para casa.","A chuva ajuda a terra; botas secas também fazem falta."],"artisan":["Tenho mais ideias do que horas para pôr tudo de pé.","Ferramenta bem cuidada poupa muito trabalho.","Cada peça da minha oficina tem uma história."],"merchant":["Sempre há uma boa troca para quem sabe escutar.","Voltei com notícias e algumas mercadorias novas.","Preço justo faz o cliente voltar."],"scholar":["Um mapa bom começa por uma pergunta.","Registro o que aprendo nos caminhos.","As histórias mudam quando ouvimos os dois lados."],"ranger":["Conheço as plantas que crescem longe das trilhas.","É melhor colher com cuidado e deixar a terra descansar.","Trouxe ervas frescas para a feira."]}
	var lines:Array=work[data.role]
	return openings[data.speech_style]+" Sou "+data.display_name+". "+lines[posmod(data.seed/17,lines.size())]+"\n\n"+String(profile.get("greeting",""))
