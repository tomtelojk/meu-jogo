class_name FactionState
extends RefCounted

var guilds:Dictionary={}
var territories:Dictionary={}
var uniform:=""
var history:Array=[]
var reparations:Dictionary={}
var support_count:=0
var contracts_completed:=0
var story:Dictionary={"step":0,"path":"","ending":""}

func reputation(rpg:RPGState,realm:String)->int:return int(rpg.relationships.reputation.get(realm,0))
func log_event(day:int,message:String)->void:
	history.append({"day":day,"message":message.left(220)})
	while history.size()>40:history.pop_front()

func change_reputation(rpg:RPGState,realm:String,amount:int,day:int,cause:String,rival:int=0)->void:
	if FactionCatalog.faction(realm).is_empty():return
	var scores:Dictionary=rpg.relationships.reputation
	scores[realm]=clampi(int(scores.get(realm,0))+amount,-100,100)
	var opposite:=FactionCatalog.other(realm)
	if rival!=0:scores[opposite]=clampi(int(scores.get(opposite,0))+rival,-100,100)
	log_event(day,cause+" · "+FactionCatalog.faction(realm).name+" %+d"%amount+(" · "+FactionCatalog.faction(opposite).name+" %+d"%rival if rival!=0 else ""))
	rpg.changed.emit()

func control(id:String)->String:
	var entry:=FactionCatalog.territory(id)
	if entry.is_empty():return ""
	if not territories.has(id):territories[id]={"owner":entry.owner,"influence":35 if entry.owner=="aurelia" else -35,"action_day":-1,"last_day":1,"changes":0}
	return territories[id].owner

func advance(day:int)->void:
	for id in territories:
		var entry:Dictionary=territories[id];var elapsed:=maxi(0,day-int(entry.last_day))
		# Unmaintained political influence fades, while the last administration
		# stays until its opponent builds a clear majority (hysteresis).
		entry.influence=move_toward(int(entry.influence),0,mini(elapsed,30)*2)
		entry.last_day=maxi(day,int(entry.last_day))

func guild_record(id:String)->Dictionary:
	if not guilds.has(id):guilds[id]={"member":false,"marks":0,"join_day":0,"job":{},"completed":{},"purchases":{}}
	return guilds[id]

func guild_available(id:String)->bool:
	var entry:=FactionCatalog.guild(id)
	if not MapDocument.base_enabled() or entry.is_empty() or KingdomData.person(entry.master).is_empty():return false
	var kind:String={"artisans":"forge","caravans":"tavern","watch":"barracks"}.get(id,"")
	for building in KingdomData.buildings():
		if building.kind==kind and building.realm==entry.realm and KingdomData.building_rect(building).grow(120).has_point(FactionCatalog.headquarters(id)):return true
	return false

func guild_access(rpg:RPGState,id:String,member:bool=true)->Dictionary:
	if not guild_available(id):return result(false,"O QG desta guilda não está disponível neste mapa.")
	if reputation(rpg,FactionCatalog.guild(id).realm)<=-30:return result(false,"Guilda suspensa: repare sua reputação com o reino do QG.")
	if member and not guild_record(id).member:return result(false,"Filie-se à guilda no QG primeiro.")
	return result(true,"")

func join(rpg:RPGState,id:String,day:int)->Dictionary:
	var access:=guild_access(rpg,id,false)
	if not access.ok:return access
	var member:=guild_record(id)
	if member.member:return result(false,"Você já faz parte desta guilda.")
	if rpg.gold<20:return result(false,"A filiação custa 20 moedas e inclui o uniforme.")
	rpg.gold-=20;member.member=true;member.join_day=day
	log_event(day,"Entrou na "+FactionCatalog.guild(id).name+".");rpg.changed.emit()
	return result(true,"Filiação concluída. Uniforme, contratos e loja foram liberados.")

func equip(rpg:RPGState,id:String)->Dictionary:
	if id!="":
		var access:=guild_access(rpg,id)
		if not access.ok:return access
	uniform=id;rpg.changed.emit()
	return result(true,"Uniforme equipado." if id!="" else "Uniforme guardado.")

func mission(id:String,key:String)->Dictionary:
	for entry in FactionCatalog.guild(id).get("missions",[]):
		if entry.id==key:return entry
	return {}

func accept(rpg:RPGState,id:String,key:String,day:int)->Dictionary:
	var access:=guild_access(rpg,id)
	if not access.ok:return access
	var entry:=mission(id,key);var member:=guild_record(id)
	if entry.is_empty():return result(false,"Contrato desconhecido.")
	if not member.job.is_empty():return result(false,"Conclua ou abandone o contrato atual.")
	if FactionCatalog.rank(member.marks)<int(entry.rank):return result(false,"Seu rank ainda não permite este contrato.")
	if int(member.completed.get(key,-1))==day:return result(false,"Este contrato já foi pago hoje. Volte amanhã.")
	member.job={"id":key,"day":day,"boars":rpg.relationships.boars_killed,"visited":false}
	rpg.changed.emit();return result(true,"Contrato aceito: "+entry.name+".")

func visit(point:Vector2)->void:
	for id in guilds:
		var job:Dictionary=guilds[id].job
		if job.is_empty():continue
		var target:String=mission(id,job.id).get("visit","");var place:=FactionCatalog.town(target)
		if not place.is_empty() and point.distance_to(place.position)<=1000:job.visited=true

func complete(rpg:RPGState,id:String,day:int)->Dictionary:
	var access:=guild_access(rpg,id)
	if not access.ok:return access
	var member:=guild_record(id)
	if member.job.is_empty():return result(false,"Você não tem contrato ativo nesta guilda.")
	var job:Dictionary=member.job;var entry:=mission(id,job.id)
	if entry.has("visit") and not job.visited:return result(false,"Visite "+FactionCatalog.town(entry.visit).name+" depois de aceitar o contrato.")
	if rpg.relationships.boars_killed-int(job.boars)<int(entry.get("boars",0)):return result(false,"Afaste os javalis pedidos depois de aceitar o contrato.")
	if not rpg.construction.afford(rpg,entry.cost):return result(false,"Entrega: "+ConstructionCatalog.cost_text(entry.cost))
	rpg.construction.transfer(rpg,entry.cost,-1);rpg.relationships.credit_npc(rpg,FactionCatalog.guild(id).master,entry.cost)
	rpg.gold+=int(entry.gold);rpg.xp+=int(entry.xp);member.marks=mini(9999,int(member.marks)+int(entry.marks))
	member.completed[job.id]=day;member.job={};contracts_completed+=1
	change_reputation(rpg,FactionCatalog.guild(id).realm,4,day,"Contrato: "+entry.name)
	return result(true,"Contrato concluído: +%d moedas · +%d méritos · %s."%[entry.gold,entry.marks,FactionCatalog.rank_name(member.marks)])

func abandon(rpg:RPGState,id:String)->Dictionary:
	if FactionCatalog.guild(id).is_empty() or guild_record(id).job.is_empty():return result(false,"Não há contrato a abandonar.")
	guild_record(id).job={};rpg.changed.emit();return result(true,"Contrato abandonado. Nenhum ingrediente foi reservado.")

func purchase(rpg:RPGState,id:String,key:String,day:int)->Dictionary:
	var access:=guild_access(rpg,id)
	if not access.ok:return access
	var item:Dictionary={};var member:=guild_record(id)
	for entry in FactionCatalog.guild(id).shop:
		if entry.id==key:item=entry;break
	if item.is_empty():return result(false,"Mercadoria desconhecida.")
	if FactionCatalog.rank(member.marks)<int(item.rank):return result(false,"Seu rank ainda não permite esta compra.")
	if int(member.purchases.get(key,-1))==day:return result(false,"Este lote já foi comprado hoje.")
	if item.has("tool") and rpg.tools.has(item.tool):return result(false,"Você já tem esta ferramenta.")
	if rpg.gold<int(item.price):return result(false,"Moedas insuficientes.")
	rpg.gold-=int(item.price)
	if item.has("tool"):rpg.tools[item.tool]=true
	else:rpg.construction.transfer(rpg,item.items,1)
	member.purchases[key]=day;rpg.changed.emit();return result(true,"Compra da guilda concluída.")

func support(rpg:RPGState,id:String,realm:String,kind:String,day:int)->Dictionary:
	FactionCatalog.load_data()
	if not MapDocument.base_enabled() or FactionCatalog.town(id).is_empty() or FactionCatalog.territory(id).is_empty():return result(false,"Posto fora do mapa atual.")
	if FactionCatalog.faction(realm).is_empty() or not FactionCatalog.data.support.has(kind):return result(false,"Apoio desconhecido.")
	if reputation(rpg,realm)<=-30:return result(false,"Repare sua reputação antes de representar esta facção.")
	control(id);advance(day)
	var entry:Dictionary=territories[id];var action:Dictionary=FactionCatalog.data.support[kind]
	if int(entry.action_day)==day:return result(false,"Este posto já recebeu sua ajuda hoje, de qualquer bandeira.")
	if not rpg.construction.afford(rpg,action.cost):return result(false,"Entrega: "+ConstructionCatalog.cost_text(action.cost))
	rpg.construction.transfer(rpg,action.cost,-1);entry.action_day=day;support_count+=1
	entry.influence=clampi(int(entry.influence)+int(action.influence)*(1 if realm=="aurelia" else -1),-100,100)
	var previous:String=entry.owner
	if entry.influence>=60:entry.owner="aurelia"
	elif entry.influence<=-60:entry.owner="valverde"
	if entry.owner!=previous:entry.changes+=1;log_event(day,FactionCatalog.territory(id).name+" passou ao controle de "+FactionCatalog.faction(entry.owner).name+".")
	change_reputation(rpg,realm,action.reputation,day,action.name+" em "+FactionCatalog.territory(id).name,action.rival)
	return result(true,"Apoio entregue. Influência %+d · Controle: %s."%[entry.influence,FactionCatalog.faction(entry.owner).name])

func trade_access(rpg:RPGState,town:String)->Dictionary:
	var realm:=FactionCatalog.town_faction(rpg,town)
	if realm.is_empty():return result(false,"Comércio fora do mapa atual.")
	if reputation(rpg,realm)<=-30:return result(false,"Entrada negada pelo comércio de "+FactionCatalog.faction(realm).name+". Procure reparação em um posto.")
	return result(true,"")

func trade_factor(rpg:RPGState,town:String)->float:return FactionCatalog.price_factor(reputation(rpg,FactionCatalog.town_faction(rpg,town)))

func repair_reputation(rpg:RPGState,realm:String,day:int)->Dictionary:
	if FactionCatalog.faction(realm).is_empty():return result(false,"Facção desconhecida.")
	if reputation(rpg,realm)>=0:return result(false,"Não há desavença a reparar com este reino.")
	if int(reparations.get(realm,-1))==day:return result(false,"Sua reparação de hoje já foi recebida.")
	if rpg.gold<15 or rpg.food<2:return result(false,"Reparação: 15 moedas e duas provisões.")
	rpg.gold-=15;rpg.food-=2;reparations[realm]=day
	change_reputation(rpg,realm,mini(15,-reputation(rpg,realm)),day,"Reparação aos moradores")
	return result(true,"Sua reparação foi aceita: até +15 reputação. As outras consequências continuam registradas.")

func controlled(realm:String)->int:
	var count:=0;FactionCatalog.load_data()
	for id in FactionCatalog.data.territories:
		if control(id)==realm:count+=1
	return count

func story_available(rpg:RPGState,path:String)->Dictionary:
	if not MapDocument.base_enabled():return result(false,"A história das Coroas se passa no continente original.")
	if not path in ["aurelia","valverde","accord"]:return result(false,"Caminho desconhecido.")
	if story.step>=3:return result(false,"Você já escreveu o desfecho desta campanha.")
	if story.step>0 and story.path!=path:return result(false,"Esta campanha já tem um compromisso firmado.")
	var banner:String="free" if path=="accord" else path
	if rpg.relationships.faction!=banner:return result(false,"Escolha a bandeira correspondente no diário de identidade.")
	var score:=mini(reputation(rpg,"aurelia"),reputation(rpg,"valverde")) if path=="accord" else reputation(rpg,path)
	var required:int=[10,30,60][int(story.step)] if path!="accord" else [10,20,30][int(story.step)]
	if score<required:return result(false,"Reputação mínima: %d%s."%[required," nos dois reinos" if path=="accord" else " com seu reino"])
	if story.step>=1 and support_count+contracts_completed<2:return result(false,"Conclua ao menos dois apoios de posto ou contratos de guilda.")
	if story.step==2 and path!="accord" and controlled(path)<2:return result(false,"Seu reino precisa controlar ao menos dois postos.")
	return result(true,"")

func advance_story(rpg:RPGState,path:String,day:int)->Dictionary:
	var available:=story_available(rpg,path)
	if not available.ok:return available
	var cost:Dictionary=[{"food":4},{"plank":4,"stone_block":4},{"iron_ingot":2,"plank":6}][int(story.step)]
	if not rpg.construction.afford(rpg,cost):return result(false,"A etapa precisa de "+ConstructionCatalog.cost_text(cost)+".")
	rpg.construction.transfer(rpg,cost,-1);story.path=path;story.step+=1;rpg.xp+=40
	if path=="accord":
		change_reputation(rpg,"aurelia",6,day,"Pacto dos Caminhos",6)
	else:change_reputation(rpg,path,12,day,"Carta de aliança",-6)
	if story.step==3:
		story.ending={"aurelia":"Carta das Oficinas","valverde":"Liga dos Conselhos","accord":"Pacto dos Caminhos"}[path]
		log_event(day,"Desfecho: "+story.ending+".")
	return result(true,"Compromisso registrado · +40 XP." if story.step<3 else "Novo capítulo do continente: "+story.ending+".")

func narrative(rpg:RPGState,realm:String)->String:
	var text:String=FactionCatalog.faction(realm).get("story","")
	if story.step==0:return text
	if story.path=="accord":return "Os conselhos discutem seu Pacto dos Caminhos: postos compartilhados, rotas abertas e reparação entre vizinhos."+(" O pacto foi assinado pelas duas Coroas." if story.step==3 else " Ainda há compromissos a cumprir.")
	if story.path==realm:return "Seu apoio fortaleceu "+FactionCatalog.faction(realm).name+". "+text+(" A nova carta foi aprovada: "+story.ending+"." if story.step==3 else " A corte acompanha seus compromissos nos postos.")
	return "A corte vê sua aliança com a outra Coroa com preocupação. Seus avanços nos postos mudaram o debate sobre as fronteiras."+(" Seu reino negocia agora sob os termos de "+story.ending+"." if story.step==3 else "")

func save_data()->Dictionary:
	return {"guilds":guilds.duplicate(true),"territories":territories.duplicate(true),"uniform":uniform,"history":history.duplicate(true),"reparations":reparations.duplicate(),"support_count":support_count,"contracts_completed":contracts_completed,"story":story.duplicate()}

func restore(source:Variant)->void:
	guilds.clear();territories.clear();uniform="";history.clear();reparations.clear();support_count=0;contracts_completed=0;story={"step":0,"path":"","ending":""}
	if not source is Dictionary:return
	FactionCatalog.load_data()
	for id in FactionCatalog.data.guilds:
		var saved:Variant=source.get("guilds",{}).get(id,{}) if source.get("guilds",{}) is Dictionary else {}
		if not saved is Dictionary:continue
		var member:=guild_record(id);member.member=saved.get("member",false)==true
		member.marks=number(saved.get("marks"),0,9999);member.join_day=number(saved.get("join_day"),0,999999)
		for field in ["completed","purchases"]:
			if saved.get(field) is Dictionary:
				for key in saved[field]:
					var known:bool=not mission(id,str(key)).is_empty() if field=="completed" else FactionCatalog.guild(id).shop.any(func(item:Dictionary):return item.id==key)
					if known and ResourceProgress.number(saved[field][key]):member[field][key]=number(saved[field][key],-1,999999)
		var job:Variant=saved.get("job",{})
		if member.member and job is Dictionary and job.get("id") is String and not mission(id,job.id).is_empty():member.job={"id":job.id,"day":number(job.get("day"),0,999999),"boars":number(job.get("boars"),0,999999),"visited":job.get("visited",false)==true}
	for id in FactionCatalog.data.territories:
		var saved:Variant=source.get("territories",{}).get(id,{}) if source.get("territories",{}) is Dictionary else {}
		if not saved is Dictionary:continue
		control(id);var entry:Dictionary=territories[id]
		if FactionCatalog.data.factions.has(saved.get("owner","")):entry.owner=saved.owner
		for key in ["influence","action_day","last_day","changes"]:
			if ResourceProgress.number(saved.get(key)):entry[key]=number(saved[key],-100 if key=="influence" else (-1 if key=="action_day" else 0),100 if key=="influence" else 999999)
	if source.get("uniform") is String and guilds.has(source.uniform) and guilds[source.uniform].member:uniform=source.uniform
	for realm in FactionCatalog.data.factions:
		if source.get("reparations") is Dictionary and ResourceProgress.number(source.reparations.get(realm)):reparations[realm]=number(source.reparations[realm],-1,999999)
	if source.get("history") is Array:
		for entry in source.history.slice(-40):
			if entry is Dictionary and entry.get("message") is String:log_event(number(entry.get("day"),0,999999),entry.message)
	support_count=number(source.get("support_count"),0,999999);contracts_completed=number(source.get("contracts_completed"),0,999999)
	var saved_story:Variant=source.get("story",{})
	if saved_story is Dictionary and saved_story.get("path","") in ["aurelia","valverde","accord"]:
		story.path=saved_story.path;story.step=number(saved_story.get("step"),0,3)
		if story.step==3:story.ending={"aurelia":"Carta das Oficinas","valverde":"Liga dos Conselhos","accord":"Pacto dos Caminhos"}[story.path]

func number(value:Variant,minimum:int,maximum:int)->int:return clampi(int(value),minimum,maximum) if ResourceProgress.number(value) else maxi(0,minimum)
func result(ok:bool,message:String)->Dictionary:return {"ok":ok,"message":message}
