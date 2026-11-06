class_name KingdomData
extends RefCounted

const REALMS := {
	"aurelia": {"name":"Reino de Aurélia","color":Color("cdab67"),"capital":Vector2(4608,4096)},
	"valverde": {"name":"Reino de Valverde","color":Color("8fb7a5"),"capital":Vector2(11264,5376)},
}
const SETTLEMENTS: Array[Dictionary] = [
	{"id":"aurelia","name":"Aurélia","realm":"aurelia","position":Vector2(4608,4096),"capital":true},
	{"id":"valverde","name":"Valverde","realm":"valverde","position":Vector2(11264,5376),"capital":true},
	{"id":"pedra_alta","name":"Pedra Alta","realm":"aurelia","position":Vector2(5760,1664),"capital":false},
	{"id":"ponte_velha","name":"Ponte Velha","realm":"aurelia","position":Vector2(3200,8192),"capital":false},
	{"id":"porto_claro","name":"Porto Claro","realm":"valverde","position":Vector2(10880,10240),"capital":false},
	{"id":"cedro","name":"Cedro","realm":"valverde","position":Vector2(13568,8192),"capital":false},
]
static var PLACES: Dictionary = _make_places()
static var BUILDINGS: Array[Dictionary] = _make_buildings()
static var PEOPLE: Array[Dictionary] = _make_people()
static var _roads: Array[PackedVector2Array] = []

static func _make_places() -> Dictionary:
	var p := {
		"aurel_court":Vector2(4608,3712),"aurel_garden":Vector2(4864,3584),"aurel_home":Vector2(4480,3648),
		"forge":Vector2(4224,4288),"bento_home":Vector2(3840,4672),"west_market":Vector2(4608,4608),
		"west_tavern":Vector2(4992,4416),"lia_home":Vector2(5376,4672),
		"east_market":Vector2(11264,5888),"east_tavern":Vector2(11648,5696),
		"iris_garden":Vector2(11904,6144),"iris_home":Vector2(12032,6016),
		"mila_farm":Vector2(12288,6528),"mila_home":Vector2(12416,6400),
		"caio_court":Vector2(11264,4992),"caio_garden":Vector2(11520,4864),"caio_home":Vector2(11136,4928),
		"archives":Vector2(4992,3904),"mother_meet":Vector2(1536,1600),"eron_home":Vector2(5376,3904),
		"bridge_west":Vector2(7552,4800),"bridge_east":Vector2(8320,4800),"guard_post":Vector2(8448,4800),"barracks":Vector2(8704,4800),
	}
	for town in SETTLEMENTS:
		var c:Vector2=town.position
		p[town.id+"_shop"]=c+Vector2(-192,192)
		p[town.id+"_inn"]=c+Vector2(192,192)
		p[town.id+"_wood"]=c+Vector2(-832,1472)
		p[town.id+"_stone"]=c+Vector2(-1152,1344)
		p[town.id+"_plot"]=c+Vector2(768,1152)
		p[town.id+"_farm"]=c+Vector2(1600,832)
		p[town.id+"_market"]=c+Vector2(0,448)
		for i in 6:
			p[town.id+"_home_"+str(i)]=c+Vector2([-768,-384,384,768,-384,384][i],192 if i<4 else -192)
			p[town.id+"_shop_"+str(i)]=c+Vector2(-192+(i%3-1)*48,208+(i/3)*48)
			p[town.id+"_inn_"+str(i)]=c+Vector2(192+(i%3-1)*48,208+(i/3)*48)
	return p

static func _make_buildings() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for town in SETTLEMENTS:
		var c:Vector2=town.position
		if town.capital:
			result.append({"name":"Castelo de "+town.name,"kind":"castle","realm":town.realm,"tile":(c+Vector2(0,-512))/64.0,"size":Vector2(512,320)})
		for side in [-1,1]:
			for col in (3 if town.capital else 2):
				for row in (6 if town.capital else 3):
					var pos:=c+Vector2(side*(384+col*384),-640+row*384)
					if pos in [Vector2(4224,4224),Vector2(4992,3840)]:continue
					result.append({"name":"Casa de "+town.name+" %d"%result.size(),"kind":"home","realm":town.realm,"tile":pos/64.0,"size":Vector2(176,128)})
		for entry in [{"name":"Ferraria e comércio","kind":"forge","offset":Vector2(-192,128)}, {"name":"Estalagem","kind":"tavern","offset":Vector2(192,128)}]:
			result.append({"name":entry.name+" de "+town.name,"kind":entry.kind,"realm":town.realm,"tile":(c+entry.offset)/64.0,"size":Vector2(208,160)})
	# The named craftsmen occupy real buildings along the capital avenues.
	for entry in [{"name":"Forja de Bento","kind":"forge","realm":"aurelia","at":Vector2(4224,4224)}, {"name":"Arquivo dos Reinos","kind":"library","realm":"aurelia","at":Vector2(4992,3840)}, {"name":"Quartel da Travessia","kind":"barracks","realm":"valverde","at":Vector2(8704,4736)}]:
		result.append({"name":entry.name,"kind":entry.kind,"realm":entry.realm,"tile":entry.at/64.0,"size":Vector2(176,128)})
	return result

static func _make_people() -> Array[Dictionary]:
	var people:Array[Dictionary]=[]
	var named := [
		["bento","Bento","Ferreiro","aurelia","forge","bento_home","west_tavern","Ferramentas abrem caminhos. Posso negociar machados, picaretas e martelos; uma boa casa começa com material e trabalho.","Compre ferramentas na ferraria. Madeira e pedra também podem ser vendidas por moedas."],
		["lia","Lia","Comerciante","aurelia","west_market","lia_home","east_market","Levo mercadorias entre Aurélia e Valverde. Os vilarejos têm histórias e oportunidades bem diferentes.","Use a estalagem para viajar de caravana. Encomendas de materiais rendem moedas."],
		["tomas","Tomás","Guarda da travessia","valverde","guard_post","barracks","bridge_west","Mantenho as estradas e a ponte seguras. Nos campos, alguns javalis não recebem viajantes com tanta educação.","Espaço ataca. Uma espada ajuda contra animais hostis; você também pode fugir ou nadar."],
		["iris","Íris","Herbalista","valverde","iris_garden","iris_home","east_market","Vendo provisões e estudo as plantas destes campos. Animais e pessoas precisam de espaço para viver.","Coma uma provisão no inventário para recuperar vida. A estalagem oferece descanso."],
		["eron","Eron","Cartógrafo","aurelia","archives","eron_home","west_market","Este continente é maior que os mapas antigos. Há montanhas, planícies, fazendas e caminhos que atravessam os dois reinos.","M abre o mapa do continente. Descobrir vilarejos dá experiência."],
		["aurel","Rei Aurel","Rei de Aurélia","aurelia","aurel_court","aurel_home","west_market","Aurélia vive de suas oficinas, minas e lavouras. Nosso reino tem lugar para quem quer negociar, explorar ou construir uma vida.","Nossos moradores recebem salários, compram ferramentas e constroem casas. Converse para conhecer seus objetivos."],
		["caio","Rei Caio","Rei de Valverde","valverde","caio_court","caio_home","east_market","Valverde reúne pastores, viajantes e artesãos. As portas da capital estão abertas, e os vilarejos precisam de bons vizinhos.","Um terreno livre pode ser seu. Use B para escolher o lugar e um martelo para erguer a casa."],
		["mila","Mila","Agricultora","valverde","mila_farm","mila_home","east_market","Começo o dia na plantação e termino na feira. Quero que meu próximo teto seja feito com as minhas próprias mãos.","Madeira, pedra e martelo: a casa cresce em três etapas, da fundação ao telhado."],
	]
	for i in named.size():
		var n:Array=named[i]
		people.append({"id":n[0],"name":n[1],"role":n[2],"realm":n[3],"color":Color("bc9879").lerp(Color("88afa0"),i/10.0),"speed":70.0+i*2,"greeting":n[7],"realm_text":REALMS[n[3]].name+" reúne cidades, rotas comerciais e pequenos povoados.","other_text":"As caravanas mantêm os dois reinos em contato. Cada morador tem seus planos.","hint":n[8],"routine":[{"hour":0,"activity":"Descansando em casa","points":[n[5]],"rest":true},{"hour":6+i%3,"activity":"Trabalhando como "+String(n[2]).to_lower(),"points":[n[4]]},{"hour":12,"activity":"Visitando o mercado","points":[n[6]]},{"hour":14,"activity":"Cuidando do trabalho","points":[n[4]]},{"hour":19,"activity":"Encontrando os vizinhos","points":[n[6]]},{"hour":22,"activity":"Descansando em casa","points":[n[5]],"rest":true}]})
	var names:PackedStringArray=["Rui","Nara","Caetano","Dora","Ivo","Luna","Bruno","Cora","Davi","Eva","Flora","Gil","Hugo","Inês","Jana","Lino","Maia","Nilo","Olívia","Pedro","Raul","Sara","Téo","Vera","Yara","Zeca","Ada","Bia","Ciro","Dina","Elisa","Fábio","Gabi","Heitor","Isa","João"]
	for t in SETTLEMENTS.size():
		var town:Dictionary=SETTLEMENTS[t]
		for i in 6:
			var home:String=town.id+"_home_"+str(i)
			var builder:bool=i==0 and not town.capital
			var work:String=town.id+["_wood","_stone","_farm","_farm","_shop","_market"][i]
			people.append({"id":town.id+"_resident_"+str(i),"name":names[t*6+i],"role":"Construtor" if builder else ["Lenhador","Mineiro","Pastor","Agricultor","Artesã","Mercador"][i],"realm":town.realm,"town":town.id,"builder":builder,"color":Color(0.7+(i%3)*0.08,0.7+(t%3)*0.08,0.65+(i%2)*0.15),"speed":68.0+i*4,"greeting":"Moro em "+town.name+". Trabalho, negócio e guardo recursos para melhorar minha casa. Os preços das ferramentas são os mesmos para todos.","realm_text":REALMS[town.realm].name+" é minha terra. Este vilarejo tem comércio, animais e terrenos para novos moradores.","other_text":"No fim do dia, prefiro encontrar meus vizinhos a ficar na estrada.","hint":"Converse comigo sobre minhas compras e construção para acompanhar meu progresso.","routine":[{"hour":0,"activity":"Descansando em casa","points":[home],"rest":true},{"hour":6+i%3,"activity":["Cortando madeira","Extraindo pedra","Cuidando dos animais","Trabalhando na plantação","Fabricando ferramentas","Negociando na feira"][i],"points":[work]},{"hour":12,"activity":"Comprando no comércio","points":[town.id+"_shop_"+str(i)]},{"hour":14,"activity":"Preparando materiais","points":[work]},{"hour":19,"activity":"Encontrando os vizinhos","points":[town.id+"_inn_"+str(i)]},{"hour":22,"activity":"Descansando em casa","points":[home],"rest":true}]})
	return people

static func point(id:String)->Vector2:
	return PLACES.get(id,REALMS.aurelia.capital)

static func person(id:String)->Dictionary:
	for entry in PEOPLE:
		if entry.id==id:return entry
	return {}

static func schedule(profile:Dictionary,minute:float)->Dictionary:
	var selected:Dictionary=profile.routine.back()
	for entry in profile.routine:
		if minute>=float(entry.hour)*60:selected=entry
	return selected

static func routine_text(profile:Dictionary)->String:
	var lines:=PackedStringArray()
	for entry in profile.routine:lines.append("%02d:00 · %s"%[entry.hour,entry.activity])
	return "Minha rotina:\n\n"+"\n".join(lines)

static func paths()->Array[PackedVector2Array]:
	if not _roads.is_empty():return _roads
	for town in SETTLEMENTS:
		var c:Vector2=town.position
		_roads.append(PackedVector2Array([c+Vector2(0,-1152),c+Vector2(0,1600)]))
		for y in [-576,-192,192,576,960,1344]:
			_roads.append(PackedVector2Array([c+Vector2(-1408,y),c+Vector2(1408,y)]))
		for x in [-960,-576,576,960]:
			_roads.append(PackedVector2Array([c+Vector2(x,-960),c+Vector2(x,1408)]))
	for points in [[Vector2(4608,1664),Vector2(5760,1664)],[Vector2(4608,4096),Vector2(4608,1664)],[Vector2(4608,4096),Vector2(4608,4800),Vector2(11264,4800),Vector2(11264,5376)],[Vector2(4608,4800),Vector2(3200,4800),Vector2(3200,8192)],[Vector2(3200,8192),Vector2(7800,8192),Vector2(10880,8192),Vector2(10880,10240)],[Vector2(11264,5376),Vector2(13568,5376),Vector2(13568,8192)],[Vector2(1536,1664),Vector2(4608,1664)]]:
		_roads.append(PackedVector2Array(points))
	return _roads

static func building_rect(building:Dictionary)->Rect2:
	var size:Vector2=building.get("size",Vector2(176,128))
	return Rect2(building.tile*64.0-Vector2(size.x/2,size.y),size)

static func reserved_points()->Array[Vector2]:
	var result:Array[Vector2]=[]
	for p in PLACES.values():result.append(p)
	return result

static func realm_at(position:Vector2)->String:
	return "aurelia" if position.x<8000 else "valverde"

static func nearest_town(point_value:Vector2)->Dictionary:
	var best:Dictionary=SETTLEMENTS[0]
	var distance:=INF
	for town in SETTLEMENTS:
		var d:=point_value.distance_squared_to(town.position)
		if d<distance:best=town;distance=d
	return best
