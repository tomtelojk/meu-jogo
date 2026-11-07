class_name RelationshipState
extends RefCounted

var people:Dictionary={}
var player_class:="wanderer"
var faction:="free"
var faction_day:=-1
var class_chosen:=false
var reputation:Dictionary={"aurelia":0,"valverde":0}
var partner:=""
var companion:=""
var pending:Dictionary={}
var boars_killed:=0

func record(id:String)->Dictionary:
	if not people.has(id):
		people[id]={"affinity":0,"bond":"known","events":{},"memories":{},"history":[],"days":[],"choices":{},"tastes":{},"gift_day":-1,"gift_count":0,"theft_day":-1,"apology_day":-1,"debt":0,"dating_day":0,"auto_bed":"","quest":{"status":"none","day":0,"boars":0}}
	return people[id]

func visit(id:String,day:int)->void:
	var person:=record(id)
	if not day in person.days:
		person.days.append(day)
		while person.days.size()>14:person.days.pop_front()
	if not person.memories.has("met"):remember(id,"met",day,"Vocês se conheceram.")

func remember(id:String,kind:String,day:int,detail:String="")->void:
	var person:=record(id)
	person.memories[kind]={"count":mini(999999,int(person.memories.get(kind,{}).get("count",0))+1),"day":day,"detail":detail.left(180)}
	person.history.append({"kind":kind,"day":day,"detail":detail.left(180)})
	while person.history.size()>24:person.history.pop_front()

func change(id:String,amount:int)->int:
	var person:=record(id);var before:int=person.affinity
	person.affinity=clampi(before+amount,-100,100)
	if person.affinity<30 and companion==id:companion=""
	return int(person.affinity)-before

func bond_label(id:String)->String:
	var person:=record(id)
	if person.bond=="married":return "Casamento" if person.affinity>=0 else "Casamento abalado"
	if person.bond=="dating":return "Romance" if person.affinity>=0 else "Romance abalado"
	if person.bond=="rival" or person.affinity<=-25:return "Rivalidade"
	if person.affinity>=60:return "Amizade próxima"
	if person.bond=="friend" or person.affinity>=30:return "Amizade"
	return "Conhecidos" if person.affinity>=0 else "Desconfiança"

func reaction(id:String,day:int)->String:
	var person:=record(id)
	if person.debt>0:return "Eu lembro do roubo. Ainda espero que você devolva o que levou antes de pedir minha confiança."
	if person.bond=="rival":return "Ainda temos nossas diferenças. Respeito se conquista com atitudes, não com uma conversa bonita."
	if person.affinity<0:return "Depois do que aconteceu entre nós, prefiro ir com calma nesta conversa."
	if person.memories.has("stole") and person.memories.has("repaid"):return "Lembro do roubo e também de quando você voltou para reparar isso. A confiança está sendo reconstruída."
	if person.bond=="married":return "É bom dividir a vida e os planos com você. Também quero saber como foi seu dia."
	if person.bond=="dating":return "Eu estava esperando um momento para conversar com você."
	if person.memories.has("helped"):return "Ainda lembro da ajuda que você deu quando precisei. Obrigado por cumprir sua palavra."
	if person.memories.has("gift_hate") and day-int(person.memories.gift_hate.day)<2:return "Aquele último presente não combinou comigo. Podemos nos conhecer melhor."
	if person.affinity>=30:return "É bom encontrar alguém em quem estou aprendendo a confiar."
	return "Sempre há espaço para conhecer melhor quem passa por aqui."

func conditions(rpg:RPGState,id:String,requirements:Dictionary)->Dictionary:
	var profile:=KingdomData.person(id)
	if profile.is_empty():return result(false,"Morador desconhecido.")
	var person:=record(id)
	for key in requirements:
		var value:Variant=requirements[key]
		match key:
			"affinity_min":
				if person.affinity<int(value):return result(false,"Afinidade mínima: %d."%value)
			"affinity_max":
				if person.affinity>int(value):return result(false,"Afinidade precisa estar em %d ou menos."%value)
			"class":
				if player_class!=value:return result(false,"Classe: "+RelationshipCatalog.CLASSES.get(value,str(value))+".")
			"faction":
				if faction!=value:return result(false,"Facção: "+RelationshipCatalog.FACTIONS.get(value,str(value))+".")
			"same_faction":
				if value and faction!=profile.realm:return result(false,"Compartilhe a bandeira deste reino.")
			"npc_realm":
				if profile.realm!=value:return result(false,"Esta fala pertence a outro reino.")
			"memory":
				if not person.memories.has(value):return result(false,"Vocês ainda não viveram essa experiência.")
			"not_memory":
				if person.memories.has(value):return result(false,"Essa experiência já ficou marcada.")
			"event":
				if not person.events.has(value):return result(false,"Conclua o evento: "+RelationshipCatalog.event(str(value)).get("name",str(value))+".")
			"quest_complete":
				if value and person.quest.status!="complete":return result(false,"Conclua a missão pessoal deste morador.")
			"no_debt":
				if value and person.debt>0:return result(false,"Devolva primeiro o que foi roubado.")
			"debt_min":
				if person.debt<int(value):return result(false,"Não há dívida pendente.")
			"reputation_min":
				if int(reputation.get(profile.realm,0))<int(value):return result(false,"Reputação mínima neste reino: %d."%value)
			_:return result(false,"Condição de diálogo desconhecida.")
	return result(true,"")

func choice(rpg:RPGState,id:String,node:String,key:String,day:int)->Dictionary:
	var profile:=KingdomData.person(id);var dialogue:=RelationshipCatalog.dialogue(node)
	if profile.is_empty() or dialogue.is_empty():return result(false,"Conversa indisponível.")
	var node_available:=conditions(rpg,id,dialogue.get("conditions",{}))
	if not node_available.ok:return node_available
	var selected:Dictionary={}
	for entry in dialogue.choices:
		if entry.id==key:selected=entry;break
	if selected.is_empty():return result(false,"Escolha indisponível.")
	var available:=conditions(rpg,id,selected.get("conditions",{}))
	if not available.ok:return available
	var person:=record(id);var token:=node+":"+key
	var limit:String=selected.get("limit","")
	if limit=="once" and person.choices.has(token):return result(false,"Vocês já tiveram essa conversa.")
	# Supportive daily talk shares one allowance across dialogue branches.
	var allowance:="daily_talk" if limit=="day" and int(selected.get("effects",{}).get("affinity",0))>0 else token
	if limit=="day" and int(person.choices.get(allowance,-1))==day:return result(false,"Essa conversa já marcou o dia. Volte amanhã.")
	var action:String=selected.get("action","")
	if action=="repay":return repay(rpg,id,day)
	if action=="apology":return apologize(rpg,id,day)
	visit(id,day)
	if action=="tastes":
		var preferences:=RelationshipCatalog.profile(profile)
		for item in preferences.loves:person.tastes[item]="love"
		for item in preferences.hates:person.tastes[item]="hate"
	if not limit.is_empty():person.choices[allowance]=day
	var effects:Dictionary=selected.get("effects",{})
	if effects.has("affinity"):change(id,int(effects.affinity))
	if effects.has("xp"):rpg.xp+=int(effects.xp)
	if effects.has("reputation"):reputation[profile.realm]=clampi(int(reputation[profile.realm])+int(effects.reputation),-100,100)
	if effects.has("memory"):remember(id,effects.memory,day,selected.label)
	rpg.changed.emit()
	return {"ok":true,"message":selected.get("reply",""),"next":selected.get("next",""),"action":action}

func gift(rpg:RPGState,id:String,item:String,day:int)->Dictionary:
	var profile:=KingdomData.person(id)
	if profile.is_empty() or not item in RelationshipCatalog.GIFTS:return result(false,"Presente indisponível.")
	var person:=record(id)
	if person.gift_day==day and person.gift_count>=2:return result(false,"Este morador já recebeu dois presentes hoje.")
	if rpg.construction.amount(rpg,item)<1:return result(false,"Você não tem esse item na bolsa.")
	visit(id,day)
	if person.gift_day!=day:person.gift_day=day;person.gift_count=0
	person.gift_count+=1;rpg.construction.transfer(rpg,{item:1},-1)
	credit_npc(rpg,id,{item:1})
	var taste:=RelationshipCatalog.taste(profile,item);var delta:=change(id,int(RelationshipCatalog.TASTES[taste].affinity))
	person.tastes[item]=taste
	remember(id,"gift_"+taste,day,"Recebeu "+RelationshipCatalog.label(item)+".")
	rpg.changed.emit()
	return {"ok":true,"message":profile.name+": "+{"love":"Adorei! Você pensou em algo que é muito especial para mim.","like":"Gostei do presente. Obrigado por lembrar de mim.","neutral":"Obrigado pelo presente. Ainda estamos nos conhecendo.","hate":"Prefiro que não me dê isso de novo. Não é algo que eu goste."}[taste],"taste":taste,"affinity":delta}

func steal(rpg:RPGState,id:String,day:int)->Dictionary:
	var profile:=KingdomData.person(id)
	if profile.is_empty():return result(false,"Morador desconhecido.")
	var person:=record(id);var account:=rpg.npc_account(id)
	if person.theft_day==day:return result(false,"Esse morador está atento depois do que aconteceu hoje.")
	if account.gold<6:return result(false,"A bolsa está vazia.")
	visit(id,day);person.theft_day=day;person.debt+=6;account.gold-=6;rpg.gold+=6;change(id,-25)
	reputation[profile.realm]=maxi(-100,int(reputation[profile.realm])-4)
	remember(id,"stole",day,"Você levou 6 moedas. O morador percebeu o roubo.");rpg.changed.emit()
	return result(true,"Você levou 6 moedas, mas foi reconhecido. Afinidade -25; confiança e reputação abaladas.")

func repay(rpg:RPGState,id:String,day:int)->Dictionary:
	var person:=record(id);var cost:int=person.debt
	if cost<=0:return result(false,"Não há nada a devolver.")
	if rpg.gold<cost:return result(false,"Faltam %d moedas para reparar o roubo."%cost)
	rpg.gold-=cost;rpg.npc_account(id).gold+=cost;person.debt=0;change(id,10)
	remember(id,"repaid",day,"Você devolveu %d moedas e reconheceu o roubo."%cost);rpg.changed.emit()
	return result(true,"O dinheiro foi devolvido. Afinidade +10; a lembrança permanece, mas a confiança pode ser reconstruída.")

func apologize(rpg:RPGState,id:String,day:int)->Dictionary:
	var person:=record(id)
	if person.debt>0:return result(false,"Devolva primeiro o que foi roubado.")
	if person.apology_day==day:return result(false,"Dê tempo para suas desculpas. Volte outro dia.")
	if person.affinity>=30:return result(false,"Vocês podem seguir conversando; não há uma desavença para reparar.")
	person.apology_day=day;change(id,5);remember(id,"apologized",day,"Você reconheceu a desavença.");rpg.changed.emit()
	return result(true,"Suas desculpas foram ouvidas. Afinidade +5; atitudes futuras também vão contar.")

func quest_available(id:String,day:int)->Dictionary:
	var person:=record(id)
	if person.affinity<15 and person.bond!="rival":return result(false,"Afinidade mínima: 15, ou uma rivalidade declarada.")
	if person.debt>0:return result(false,"Repare o roubo antes de assumir um compromisso.")
	if person.quest.status=="complete":return result(false,"Você já concluiu esta missão pessoal.")
	if person.quest.status=="active":return result(false,"A missão já está no seu diário.")
	if person.quest.status=="failed" and int(person.quest.day)>=day:return result(false,"O morador precisa de um dia antes de confiar outro pedido.")
	return result(true,"")

func accept_quest(rpg:RPGState,id:String,day:int)->Dictionary:
	if KingdomData.person(id).is_empty():return result(false,"Morador desconhecido.")
	var available:=quest_available(id,day)
	if not available.ok:return available
	visit(id,day);record(id).quest={"status":"active","day":day,"boars":boars_killed}
	remember(id,"made_promise",day,"Aceitou uma missão pessoal.");rpg.changed.emit()
	return result(true,"Missão pessoal adicionada ao diário.")

func complete_quest(rpg:RPGState,id:String,day:int)->Dictionary:
	var profile:=KingdomData.person(id);var person:=record(id)
	if profile.is_empty() or person.quest.status!="active":return result(false,"Não há missão pessoal ativa.")
	var quest:Dictionary=RelationshipCatalog.profile(profile).quest
	if boars_killed-int(person.quest.boars)<int(quest.get("boars",0)):return result(false,"Afaste um javali depois de aceitar esta missão.")
	if not rpg.construction.afford(rpg,quest.cost):return result(false,"Falta material: "+ConstructionCatalog.cost_text(quest.cost))
	# Commit before paying the reward: a second click or reload cannot repeat it.
	person.quest.status="complete";rpg.construction.transfer(rpg,quest.cost,-1);rpg.gold+=int(quest.gold);rpg.xp+=int(quest.xp);change(id,15)
	credit_npc(rpg,id,quest.cost)
	reputation[profile.realm]=mini(100,int(reputation[profile.realm])+3)
	remember(id,"helped",day,"Concluiu: "+quest.title);rpg.changed.emit()
	return result(true,"Você cumpriu o pedido. Afinidade +15 · %d moedas · %d XP."%[quest.gold,quest.xp])

func abandon_quest(rpg:RPGState,id:String,day:int)->Dictionary:
	var person:=record(id)
	if person.quest.status!="active":return result(false,"Não há missão ativa.")
	person.quest.status="failed";person.quest.day=day;change(id,-8);remember(id,"broke_promise",day,"Desistiu de uma missão pessoal.");rpg.changed.emit()
	return result(true,"A missão foi abandonada. O morador lembra da promessa quebrada.")

func befriend(rpg:RPGState,id:String,day:int)->Dictionary:
	var available:=conditions(rpg,id,{"affinity_min":30,"no_debt":true})
	if not available.ok:return available
	var person:=record(id)
	if person.bond in ["friend","dating","married"]:return result(false,"A amizade de vocês já está reconhecida.")
	person.bond="friend";remember(id,"friendship",day,"Reconheceram a amizade e deixaram as desavenças para trás.");rpg.changed.emit()
	return result(true,"Amizade reconhecida.")

func rival(rpg:RPGState,id:String,day:int)->Dictionary:
	var person:=record(id)
	if partner==id:return result(false,"Encerre o relacionamento antes de declarar rivalidade.")
	if person.bond=="rival":return result(false,"A rivalidade já está declarada.")
	person.bond="rival";person.affinity=mini(-25,int(person.affinity))
	if companion==id:companion=""
	remember(id,"rivalry",day,"Você declarou uma rivalidade.");rpg.changed.emit()
	return result(true,"Rivalidade declarada. O morador passa a tratar seus planos como uma disputa.")

func start_dating(rpg:RPGState,id:String,day:int)->Dictionary:
	var profile:=KingdomData.person(id)
	if profile.is_empty() or not RelationshipCatalog.profile(profile).romance:return result(false,"Este morador não está disponível para romance.")
	var available:=conditions(rpg,id,{"affinity_min":65,"event":"trust","quest_complete":true,"no_debt":true})
	if not available.ok:return available
	var person:=record(id)
	if person.days.size()<3:return result(false,"Conheçam-se em pelo menos três dias diferentes.")
	if person.bond=="rival":return result(false,"Reconheçam primeiro uma amizade.")
	if person.bond in ["dating","married"]:return result(false,"Vocês já têm um relacionamento.")
	if not partner.is_empty():return result(false,"Encerre seu relacionamento atual antes de iniciar outro.")
	visit(id,day);partner=id;person.bond="dating";person.dating_day=day;change(id,3);remember(id,"date",day,"Vocês escolheram iniciar um romance.");rpg.changed.emit()
	return result(true,profile.name+": Sim. Quero continuar conhecendo você e construir esse vínculo com calma.")

func end_relationship(rpg:RPGState,id:String,day:int)->Dictionary:
	if partner!=id:return result(false,"Não há relacionamento para encerrar.")
	var person:=record(id);partner=""
	if companion==id:companion=""
	person.bond="friend" if person.affinity>=30 else "known";change(id,-10)
	var bed:String=person.auto_bed;person.auto_bed=""
	if rpg.construction.pieces.has(bed) and rpg.construction.pieces[bed].resident==id:rpg.construction.assign(rpg,bed,"","resident")
	remember(id,"broke_up",day,"Vocês encerraram o relacionamento.");rpg.changed.emit()
	return result(true,"O relacionamento foi encerrado. As lembranças de vocês permanecem.")

func set_companion(rpg:RPGState,id:String)->Dictionary:
	if companion==id:companion="";rpg.changed.emit();return result(true,"O companheiro volta à própria rotina.")
	var available:=conditions(rpg,id,{"affinity_min":60,"event":"trust","no_debt":true})
	if not available.ok:return available
	if record(id).bond=="rival":return result(false,"Façam as pazes antes de viajar juntos.")
	if not companion.is_empty():return result(false,"Dispense o companheiro atual antes de convidar outra pessoa.")
	companion=id;rpg.changed.emit();return result(true,"Convite aceito. Seu companheiro seguirá caminhos seguros ao seu lado.")

func home_available(rpg:RPGState,id:String)->bool:
	if rpg.houses.get("home_player",{}).get("stage",0)==3:return true
	var free:Array[String]=[];var candidate:Array[String]=[]
	for key in rpg.construction.pieces:
		var entry:Dictionary=rpg.construction.pieces[key]
		if entry.kind!="bed":continue
		if entry.resident.is_empty():free.append(key)
		if entry.resident in ["",id]:candidate.append(key)
	for first in free:
		for second in candidate:
			if first!=second:return true
	return false

func event_available(rpg:RPGState,id:String,event_id:String,day:int)->Dictionary:
	var definition:=RelationshipCatalog.event(event_id);var person:=record(id)
	if definition.is_empty():return result(false,"Evento desconhecido.")
	if person.events.has(event_id) and event_id!="wedding":return result(false,"Vocês já viveram este evento.")
	var needs:Dictionary={}
	for key in ["affinity_min","affinity_max","quest_complete"]:
		if definition.has(key):needs[key]=definition[key]
	if definition.has("requires_event"):needs.event=definition.requires_event
	var available:=conditions(rpg,id,needs)
	if not available.ok:return available
	if event_id!="rival" and person.debt>0:return result(false,"Repare o roubo antes deste encontro.")
	if event_id=="wedding":
		if partner!=id or person.bond!="dating":return result(false,"Iniciem primeiro um romance.")
		if day-int(person.dating_day)<3:return result(false,"Vivam pelo menos três dias de namoro.")
		if not home_available(rpg,id):return result(false,"Prepare uma casa completa ou duas camas disponíveis para vocês.")
		if rpg.construction.amount(rpg,"wedding_ring")<1:return result(false,"Fabrique uma aliança na forja.")
	return result(true,"")

func begin_event(rpg:RPGState,id:String,event_id:String,day:int)->Dictionary:
	if not pending.is_empty():
		if pending.npc==id and pending.event==event_id:return result(true,"Continuando o encontro.")
		return result(false,"Conclua o encontro pendente antes de iniciar outro.")
	var available:=event_available(rpg,id,event_id,day)
	if not available.ok:return available
	pending={"npc":id,"event":event_id,"step":0};rpg.changed.emit();return result(true,"")

func finish_event(rpg:RPGState,day:int)->Dictionary:
	if pending.is_empty():return result(false,"Não há evento em andamento.")
	var id:String=pending.npc;var event_id:String=pending.event
	var available:=event_available(rpg,id,event_id,day)
	if not available.ok:return available
	var person:=record(id);var first:bool=not person.events.has(event_id)
	if event_id=="wedding":
		rpg.construction.transfer(rpg,{"wedding_ring":1},-1);person.bond="married"
		remember(id,"married",day,"Vocês trocaram alianças e escolheram compartilhar um lar.")
	person.events[event_id]=true;pending.clear()
	if first:change(id,int(RelationshipCatalog.event(event_id).affinity))
	remember(id,"story_"+event_id,day,RelationshipCatalog.event(event_id).name);rpg.changed.emit()
	return result(true,"Este encontro ficou guardado na história de vocês.")

func set_identity(rpg:RPGState,kind:String,value:String,day:int)->Dictionary:
	if kind=="class":
		if not RelationshipCatalog.CLASSES.has(value):return result(false,"Classe desconhecida.")
		if value==player_class and class_chosen:return result(false,"Esta já é sua classe.")
		if class_chosen and rpg.gold<25:return result(false,"Reaprender uma vocação custa 25 moedas.")
		if class_chosen:rpg.gold-=25
		player_class=value;class_chosen=true
	elif kind=="faction":
		if not RelationshipCatalog.FACTIONS.has(value):return result(false,"Facção desconhecida.")
		if value==faction:return result(false,"Esta já é sua bandeira.")
		if faction_day==day:return result(false,"Você já mudou de bandeira hoje.")
		faction=value;faction_day=day
	else:return result(false,"Escolha desconhecida.")
	rpg.changed.emit();return result(true,"Sua identidade foi atualizada. Novas falas podem estar disponíveis.")

func save_data()->Dictionary:
	return {"people":people.duplicate(true),"class":player_class,"class_chosen":class_chosen,"faction":faction,"faction_day":faction_day,"reputation":reputation.duplicate(),"partner":partner,"companion":companion,"pending":pending.duplicate(true),"boars_killed":boars_killed}

func credit_npc(rpg:RPGState,id:String,items:Dictionary)->void:
	var account:=rpg.npc_account(id)
	for item in items:
		if item in ["wood","stone","food"]:account[item]=mini(999999,int(account[item])+int(items[item]))
		else:account.goods[item]=mini(999999,int(account.goods.get(item,0))+int(items[item]))

func restore(source:Variant)->void:
	people.clear();partner="";companion="";pending.clear();player_class="wanderer";class_chosen=false;faction="free";faction_day=-1;reputation={"aurelia":0,"valverde":0};boars_killed=0
	if not source is Dictionary:return
	RelationshipCatalog.load_data()
	if RelationshipCatalog.CLASSES.has(source.get("class","")):player_class=source["class"]
	class_chosen=source.get("class_chosen",false)==true
	if RelationshipCatalog.FACTIONS.has(source.get("faction","")):faction=source.faction
	if ResourceProgress.number(source.get("faction_day")):faction_day=clampi(int(source.faction_day),-1,999999)
	if ResourceProgress.number(source.get("boars_killed")):boars_killed=clampi(int(source.boars_killed),0,999999)
	if source.get("reputation") is Dictionary:
		for realm in reputation:
			if ResourceProgress.number(source.reputation.get(realm)):reputation[realm]=clampi(int(source.reputation[realm]),-100,100)
	var saved:Variant=source.get("people",{})
	if saved is Dictionary:
		for id in saved:
			if people.size()>=256:break
			if not id is String or KingdomData.person(id).is_empty() or not saved[id] is Dictionary:continue
			var entry:Dictionary=saved[id];var person:=record(id)
			if ResourceProgress.number(entry.get("affinity")):person.affinity=clampi(int(entry.affinity),-100,100)
			if entry.get("bond","") in ["known","friend","rival","dating","married"]:person.bond=entry.bond
			for field in ["gift_day","theft_day","apology_day","dating_day"]:
				if ResourceProgress.number(entry.get(field)):person[field]=clampi(int(entry[field]),-1,999999)
			for field in ["gift_count","debt"]:
				if ResourceProgress.number(entry.get(field)):person[field]=clampi(int(entry[field]),0,2 if field=="gift_count" else 999999)
			if entry.get("auto_bed") is String:person.auto_bed=entry.auto_bed.left(40)
			if entry.get("days") is Array:
				for value in entry.days:
					if person.days.size()>=14:break
					if ResourceProgress.number(value) and value>=1 and value<=999999 and not int(value) in person.days:person.days.append(int(value))
			for field in ["events","tastes","choices","memories"]:
				if not entry.get(field) is Dictionary:continue
				for key in entry[field]:
					if person[field].size()>=64:break
					if not key is String or key.length()>80:continue
					var value:Variant=entry[field][key]
					if field=="events" and RelationshipCatalog.data.events.has(key) and value==true:person.events[key]=true
					elif field=="tastes" and key in RelationshipCatalog.GIFTS and RelationshipCatalog.TASTES.has(value):person.tastes[key]=value
					elif field=="choices" and ResourceProgress.number(value):person.choices[key]=clampi(int(value),-1,999999)
					elif field=="memories" and value is Dictionary and ResourceProgress.number(value.get("count")) and ResourceProgress.number(value.get("day")):
						person.memories[key]={"count":clampi(int(value.count),1,999999),"day":clampi(int(value.day),1,999999),"detail":str(value.get("detail","")).left(180)}
			if entry.get("history") is Array:
				for value in entry.history:
					if person.history.size()>=24:break
					if value is Dictionary and value.get("kind") is String and ResourceProgress.number(value.get("day")):person.history.append({"kind":value.kind.left(80),"day":clampi(int(value.day),1,999999),"detail":str(value.get("detail","")).left(180)})
			if entry.get("quest") is Dictionary:
				var quest:Dictionary=entry.quest
				if quest.get("status","") in ["none","active","complete","failed"]:person.quest.status=quest.status
				for field in ["day","boars"]:
					if ResourceProgress.number(quest.get(field)):person.quest[field]=clampi(int(quest[field]),0,999999)
	var saved_partner:Variant=source.get("partner","")
	if saved_partner is String and people.has(saved_partner) and people[saved_partner].bond in ["dating","married"] and RelationshipCatalog.profile(KingdomData.person(saved_partner)).romance:partner=saved_partner
	for id in people:
		if id!=partner and people[id].bond in ["dating","married"]:people[id].bond="friend"
	var saved_companion:Variant=source.get("companion","")
	if saved_companion is String and people.has(saved_companion) and people[saved_companion].affinity>=30 and people[saved_companion].events.has("trust") and people[saved_companion].bond!="rival" and people[saved_companion].debt==0:companion=saved_companion
	var saved_pending:Variant=source.get("pending",{})
	if saved_pending is Dictionary and saved_pending.get("npc") is String and people.has(saved_pending.npc) and saved_pending.get("event") is String and not RelationshipCatalog.event(saved_pending.event).is_empty() and ResourceProgress.number(saved_pending.get("step")):
		pending={"npc":saved_pending.npc,"event":saved_pending.event,"step":clampi(int(saved_pending.step),0,RelationshipCatalog.event(saved_pending.event).pages.size()-1)}

func result(ok:bool,message:String)->Dictionary:return {"ok":ok,"message":message}
