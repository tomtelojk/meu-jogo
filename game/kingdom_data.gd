class_name KingdomData
extends RefCounted

const REALMS := {
	"aurelia": {"name": "Reino de Aurélia", "color": Color("cdab67"), "capital": Vector2(576, 704)},
	"valverde": {"name": "Reino de Valverde", "color": Color("8fb7a5"), "capital": Vector2(2880, 960)},
}

# Named locations are shared by schedules, navigation and the painted settlements.
const PLACES := {
	"aurel_court": Vector2(9, 11), "aurel_garden": Vector2(10.5, 10), "aurel_home": Vector2(8, 10.5),
	"forge": Vector2(12.5, 15), "bento_home": Vector2(11, 16.5), "west_market": Vector2(14, 25),
	"west_tavern": Vector2(14.5, 21), "lia_home": Vector2(15.5, 24),
	"bridge_west": Vector2(36, 20), "bridge_east": Vector2(41, 20), "guard_post": Vector2(41.5, 20.2),
	"barracks": Vector2(42, 21.5), "east_market": Vector2(43, 18), "east_tavern": Vector2(43, 19.5),
	"iris_garden": Vector2(30.5, 32), "iris_home": Vector2(31, 30),
	"mila_farm": Vector2(33, 32), "mila_home": Vector2(33, 34),
	"caio_court": Vector2(45, 15), "caio_garden": Vector2(46, 16.5), "caio_home": Vector2(46.5, 14.5),
	"archives": Vector2(25.5, 10.5), "mother_meet": Vector2(22.8, 24.2), "eron_home": Vector2(25, 12),
}

const BUILDINGS: Array[Dictionary] = [
	{"name": "Castelo de Aurélia", "kind": "castle", "realm": "aurelia", "tile": Vector2(9, 10)},
	{"name": "Forja de Bento", "kind": "forge", "realm": "aurelia", "tile": Vector2(12.5, 14)},
	{"name": "Casa de Bento", "kind": "home", "realm": "aurelia", "tile": Vector2(11, 15.5)},
	{"name": "Taverna da Folha Dourada", "kind": "tavern", "realm": "aurelia", "tile": Vector2(14.5, 20)},
	{"name": "Mercado de Aurélia", "kind": "market", "realm": "aurelia", "tile": Vector2(14, 24)},
	{"name": "Casa de Lia", "kind": "home", "realm": "aurelia", "tile": Vector2(15.5, 23)},
	{"name": "Arquivo do Bosque", "kind": "library", "realm": "aurelia", "tile": Vector2(24.5, 10.5)},
	{"name": "Casa de Eron", "kind": "home", "realm": "aurelia", "tile": Vector2(24, 12)},
	{"name": "Castelo de Valverde", "kind": "castle", "realm": "valverde", "tile": Vector2(45, 14)},
	{"name": "Mercado de Valverde", "kind": "market", "realm": "valverde", "tile": Vector2(44.6, 18.8)},
	{"name": "Quartel da Ponte", "kind": "home", "realm": "valverde", "tile": Vector2(43, 21.5)},
	{"name": "Casa de Íris", "kind": "home", "realm": "valverde", "tile": Vector2(31, 29)},
	{"name": "Casa de Mila", "kind": "home", "realm": "valverde", "tile": Vector2(34, 34)},
]

const PEOPLE: Array[Dictionary] = [
	{"id": "bento", "name": "Bento", "role": "Ferreiro", "realm": "aurelia", "color": Color("bc9879"), "speed": 59.0,
	 "greeting": "Uma ferramenta bem cuidada dura mais que uma briga de reis. Sou Bento, ferreiro de Aurélia. Se encontrar madeira caída, deixe as árvores vivas em paz.",
	 "realm_text": "Aurélia vive do ferro e dos campos dourados. O rei Aurel quer proteger nossas oficinas, mas sem as ervas de Valverde ninguém trata as mãos de quem trabalha.",
	 "other_text": "Dizem que a gente do outro lado do rio é diferente. Pois a melhor curandeira que conheço mora lá. Um bom ferreiro aprende a unir peças, não a separá-las.",
	 "hint": "A semente da memória está no Bosque dourado, perto da minha forja. Procure o círculo de arbustos junto ao caminho.",
	 "routine": [{"hour": 0, "activity": "Descansando em casa", "points": ["bento_home"], "rest": true}, {"hour": 7, "activity": "Trabalhando na forja", "points": ["forge"]}, {"hour": 12, "activity": "Almoçando na taverna", "points": ["west_tavern"]}, {"hour": 14, "activity": "Consertando ferramentas", "points": ["forge"]}, {"hour": 19, "activity": "Conversando na taverna", "points": ["west_tavern"]}, {"hour": 22, "activity": "Descansando em casa", "points": ["bento_home"], "rest": true}]},
	{"id": "lia", "name": "Lia", "role": "Comerciante", "realm": "aurelia", "color": Color("c9aa8c"), "speed": 76.0,
	 "greeting": "Bem-vindo! Tenho histórias dos dois lados da ponte. Levo ferramentas de Aurélia e volto com ervas e sementes de Valverde.",
	 "realm_text": "Meu reino é Aurélia, mas meu trabalho me leva aos dois mercados. Quando a ponte fecha, os preços sobem dos dois lados. Ninguém ganha com isso.",
	 "other_text": "Em Valverde o mercado começa mais tarde, depois da colheita. A guarda Tomás sempre pergunta pelas notícias, nunca pelo tamanho da minha bolsa.",
	 "hint": "Há uma semente na margem leste do riacho. Atravesse a ponte de madeira e siga para o norte. Também visite Mila, no jardim ao sul.",
	 "routine": [{"hour": 0, "activity": "Descansando em casa", "points": ["lia_home"], "rest": true}, {"hour": 6, "activity": "Abrindo a banca de Aurélia", "points": ["west_market"]}, {"hour": 10, "activity": "Levando mercadorias a Valverde", "points": ["east_market"]}, {"hour": 16, "activity": "Voltando ao mercado de Aurélia", "points": ["west_market"]}, {"hour": 20, "activity": "Contando histórias na taverna", "points": ["west_tavern"]}, {"hour": 23, "activity": "Descansando em casa", "points": ["lia_home"], "rest": true}]},
	{"id": "tomas", "name": "Tomás", "role": "Guarda da ponte", "realm": "valverde", "color": Color("aab1a0"), "speed": 84.0,
	 "greeting": "Pode passar, viajante. Minha missão é manter a ponte segura para quem vive dos dois lados. Hoje há paz, e quero que continue assim.",
	 "realm_text": "Valverde me confiou a travessia. Patrulho a ponte e o posto leste; só volto ao quartel depois que o mercado fecha.",
	 "other_text": "Os guardas de Aurélia usam outras cores, mas também querem voltar para casa no fim do turno. Uma fronteira não precisa ser uma ameaça.",
	 "hint": "Não tente cruzar a água pelo bosque. A ponte está livre. Depois dela, o caminho ao norte leva ao rei Caio e à semente do riacho.",
	 "routine": [{"hour": 0, "activity": "Descansando no quartel", "points": ["barracks"], "rest": true}, {"hour": 5, "activity": "Abrindo a travessia", "points": ["guard_post"]}, {"hour": 8, "activity": "Patrulhando a ponte", "points": ["bridge_east", "bridge_west", "guard_post"], "loop": true}, {"hour": 18, "activity": "Vigiando o posto leste", "points": ["guard_post"]}, {"hour": 22, "activity": "Descansando no quartel", "points": ["barracks"], "rest": true}]},
	{"id": "iris", "name": "Íris", "role": "Herbalista", "realm": "valverde", "color": Color("a9b385"), "speed": 64.0,
	 "greeting": "Caminhe com cuidado entre os brotos. Colho apenas o que pode voltar a crescer. O bosque cuida de nós quando aprendemos a cuidar dele.",
	 "realm_text": "Valverde guarda os jardins e as nascentes. Se as raízes secarem, nossas ervas desaparecem. Nenhuma muralha protege um reino da falta de água.",
	 "other_text": "Bento, de Aurélia, faz minhas tesouras. Eu preparo os unguentos da oficina dele. Nossa amizade já é um pequeno tratado de paz.",
	 "hint": "A árvore-mãe precisa das cinco sementes, não de um remédio. A esperança cresce no jardim ao sul; a alegria, entre as flores do caminho oeste.",
	 "routine": [{"hour": 0, "activity": "Descansando em casa", "points": ["iris_home"], "rest": true}, {"hour": 6, "activity": "Colhendo ervas no jardim", "points": ["iris_garden"]}, {"hour": 11, "activity": "Entregando remédios no mercado", "points": ["east_market"]}, {"hour": 15, "activity": "Cuidando dos brotos", "points": ["iris_garden"]}, {"hour": 19, "activity": "Preparando remédios em casa", "points": ["iris_home"]}, {"hour": 22, "activity": "Descansando em casa", "points": ["iris_home"], "rest": true}]},
	{"id": "eron", "name": "Eron", "role": "Sábio do bosque", "realm": "aurelia", "color": Color("aaa28c"), "speed": 46.0,
	 "greeting": "O bosque existia antes dos nomes dos reinos. Ainda assim, foi ele que ensinou Aurélia e Valverde a viverem juntos. Sou Eron, guardião dessas histórias.",
	 "realm_text": "Os arquivos de Aurélia registram um antigo acordo: o ferro sustenta os caminhos, as raízes sustentam a terra. Nenhum dos reinos prospera sozinho.",
	 "other_text": "Caio preserva as nascentes de Valverde; Aurel mantém as estradas de Aurélia. Falta-lhes lembrar que a mesma ponte une as duas responsabilidades.",
	 "hint": "Procure a semente do tempo nas Pedras antigas, junto ao arquivo ao norte. Depois fale com os dois reis. Palavras também podem criar raízes.",
	 "routine": [{"hour": 0, "activity": "Descansando em casa", "points": ["eron_home"], "rest": true}, {"hour": 7, "activity": "Estudando os arquivos", "points": ["archives"]}, {"hour": 10, "activity": "Observando a árvore-mãe", "points": ["mother_meet"]}, {"hour": 15, "activity": "Escrevendo a história dos reinos", "points": ["archives"]}, {"hour": 20, "activity": "Recolhendo-se em casa", "points": ["eron_home"]}, {"hour": 22, "activity": "Descansando em casa", "points": ["eron_home"], "rest": true}]},
	{"id": "aurel", "name": "Rei Aurel", "role": "Rei de Aurélia", "realm": "aurelia", "color": Color("dec17e"), "speed": 56.0,
	 "greeting": "Recebo quem chega com boas intenções. Sou Aurel. Meu povo precisa de ferramentas, estradas e campos vivos — e o bosque está enfraquecendo.",
	 "realm_text": "Aurélia é o reino das folhas douradas e das oficinas. Nosso castelo fica a oeste. Ouço o povo pela manhã e visito o mercado à tarde.",
	 "other_text": "Caio teme que usemos madeira demais. Eu temo que ele feche nossas rotas. Talvez estejamos defendendo o mesmo futuro sem nos escutar.",
	 "hint": "Encontre as sementes e ouça meus moradores. Bento conhece o Bosque dourado, Lia atravessa os dois reinos e Eron conhece o passado da árvore-mãe.",
	 "routine": [{"hour": 0, "activity": "Descansando no castelo", "points": ["aurel_home"], "rest": true}, {"hour": 7, "activity": "Caminhando no jardim real", "points": ["aurel_garden"]}, {"hour": 9, "activity": "Recebendo o povo em audiência", "points": ["aurel_court"]}, {"hour": 14, "activity": "Visitando o mercado", "points": ["west_market"]}, {"hour": 17, "activity": "Voltando ao jardim real", "points": ["aurel_garden"]}, {"hour": 21, "activity": "Descansando no castelo", "points": ["aurel_home"], "rest": true}]},
	{"id": "caio", "name": "Rei Caio", "role": "Rei de Valverde", "realm": "valverde", "color": Color("b198ad"), "speed": 61.0,
	 "greeting": "As portas de Valverde estão abertas. Protejo as nascentes deste reino, mas uma floresta não entende fronteiras. Diga-me o que viu em sua jornada.",
	 "realm_text": "Valverde floresce a leste do riacho. Nossos jardins alimentam o povo, e a guarda mantém a travessia segura. À tarde, prefiro ouvir quem trabalha na terra.",
	 "other_text": "Aurel conhece cada estrada do oeste. Precisamos dessas estradas para levar nossa colheita ao mercado. Quero um acordo que proteja as árvores e o trabalho dos dois povos.",
	 "hint": "Íris e Mila cuidam do jardim ao sul. Tomás conhece a passagem do riacho. Se conseguir restaurar a árvore-mãe, terei uma boa razão para renovar nossa aliança.",
	 "routine": [{"hour": 0, "activity": "Descansando no castelo", "points": ["caio_home"], "rest": true}, {"hour": 6, "activity": "Visitando o jardim real", "points": ["caio_garden"]}, {"hour": 10, "activity": "Recebendo visitantes no castelo", "points": ["caio_court"]}, {"hour": 15, "activity": "Visitando as plantações", "points": ["mila_farm"]}, {"hour": 19, "activity": "Recebendo relatos da guarda", "points": ["caio_court"]}, {"hour": 23, "activity": "Descansando no castelo", "points": ["caio_home"], "rest": true}]},
	{"id": "mila", "name": "Mila", "role": "Camponesa", "realm": "valverde", "color": Color("bd9780"), "speed": 68.0,
	 "greeting": "Bom ver outro par de botas por aqui! Sou Mila. Estas plantas precisam de água, paciência e um pouco de conversa. Pode rir: acho que elas escutam.",
	 "realm_text": "A vida em Valverde começa cedo. Cuido da plantação pela manhã e levo a colheita à feira depois do almoço. À noite, volto para casa.",
	 "other_text": "Minha avó veio de Aurélia. Plantamos a mesma comida e contamos as mesmas estrelas. Espero que os reis se lembrem disso.",
	 "hint": "A semente da esperança está pertinho da plantação. Veja o círculo de flores no jardim. Se cansar, descanse na barraca do acampamento até a manhã seguinte.",
	 "routine": [{"hour": 0, "activity": "Descansando em casa", "points": ["mila_home"], "rest": true}, {"hour": 5, "activity": "Regando a plantação", "points": ["mila_farm"]}, {"hour": 9, "activity": "Ajudando no jardim de ervas", "points": ["iris_garden"]}, {"hour": 13, "activity": "Vendendo a colheita na feira", "points": ["east_market"]}, {"hour": 17, "activity": "Cuidando da última rega", "points": ["mila_farm"]}, {"hour": 20, "activity": "Descansando em casa", "points": ["mila_home"], "rest": true}]},
]

static func point(id: String) -> Vector2:
	return PLACES.get(id, Vector2(24, 27)) * 64.0

static func person(id: String) -> Dictionary:
	for entry in PEOPLE:
		if entry.id == id:
			return entry
	return {}

static func schedule(person_data: Dictionary, minute: float) -> Dictionary:
	var selected: Dictionary = person_data.routine.back()
	for entry in person_data.routine:
		if minute >= float(entry.hour) * 60:
			selected = entry
	return selected

static func routine_text(person_data: Dictionary) -> String:
	var lines := PackedStringArray()
	for entry in person_data.routine:
		lines.append("%02d:00 · %s" % [entry.hour, entry.activity])
	return "Meu dia costuma seguir este ritmo:\n\n" + "\n".join(lines)

static func paths() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for keys in [["aurel_garden", "aurel_court", "aurel_home"], ["bento_home", "forge"], ["west_tavern", "bento_home"], ["lia_home", "west_market"], ["bridge_east", "guard_post", "barracks"], ["east_market", "east_tavern", "bridge_east"], ["east_market", "caio_court", "caio_garden", "caio_home"], ["iris_home", "iris_garden", "mila_farm", "mila_home"], ["archives", "eron_home"], ["mother_meet", "west_market"]]:
		var path := PackedVector2Array()
		for key in keys:
			path.append(point(key))
		result.append(path)
	return result

static func building_rect(building: Dictionary) -> Rect2:
	var size := Vector2(152, 100) if building.kind == "castle" else Vector2(96, 74)
	return Rect2(building.tile * 64.0 - Vector2(size.x / 2, size.y), size)

static func reserved_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in PLACES:
		points.append(point(key))
	for building in BUILDINGS:
		points.append(building.tile * 64.0)
	return points

static func realm_at(position: Vector2) -> String:
	return "aurelia" if position.x < 37.5 * 64 and position.y < 27 * 64 else "valverde"
