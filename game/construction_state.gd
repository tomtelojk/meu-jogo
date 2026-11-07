class_name ConstructionState
extends RefCounted

signal piece_changed(id:String)
const MAX_PIECES:=1024
const MAX_QUEUE:=8
var pieces:Dictionary={}
var queues:Dictionary={}
var stock:Dictionary={}
var serial:=0
var player_bed:=""

func amount(rpg:RPGState,item:String)->int:
	return int(stock.get(item,0)) if item in ConstructionCatalog.PROCESSED else int(rpg.get(item))

func afford(rpg:RPGState,cost:Dictionary,count:int=1)->bool:
	for item in cost:
		if amount(rpg,item)<int(cost[item])*count:return false
	return true

func transfer(rpg:RPGState,cost:Dictionary,multiplier:int)->void:
	for item in cost:
		var value:=amount(rpg,item)+int(cost[item])*multiplier
		if item in ConstructionCatalog.PROCESSED:stock[item]=value
		else:rpg.set(item,value)

func validate(kind:String,at:Vector2i,turn:int)->Dictionary:
	var definition:=ConstructionCatalog.piece(kind)
	if definition.is_empty():return result(false,"Peça desconhecida.")
	if pieces.size()>=MAX_PIECES:return result(false,"Este mundo já tem %d peças."%MAX_PIECES)
	var entry:={"kind":kind,"x":at.x,"y":at.y,"turn":posmod(turn,4)}
	var rect:=ConstructionCatalog.footprint(entry)
	if rect.position.x<64 or rect.position.y<64 or rect.end.x>WorldData.SIZE.x-64 or rect.end.y>WorldData.SIZE.y-64:return result(false,"Fora dos limites do continente.")
	for built in pieces.values():
		if ConstructionCatalog.piece(built.kind).layer==definition.layer and rect.grow(-0.5).intersects(ConstructionCatalog.footprint(built)):
			return result(false,"Já existe uma peça nesta camada do grid.")
	return result(true,"Posição livre.")

func place(rpg:RPGState,kind:String,at:Vector2i,turn:int=0)->Dictionary:
	var valid:=validate(kind,at,turn)
	if not valid.ok:return valid
	if not rpg.tools.has("hammer"):return result(false,"Compre ou fabrique um martelo.")
	var definition:=ConstructionCatalog.piece(kind)
	if not afford(rpg,definition.cost):return result(false,"Materiais: "+ConstructionCatalog.cost_text(definition.cost))
	serial+=1
	var id:="piece_"+str(serial)
	transfer(rpg,definition.cost,-1)
	pieces[id]={"kind":kind,"x":at.x,"y":at.y,"turn":posmod(turn,4),"hp":int(definition.hp),"open":false,"resident":"","worker":""}
	piece_changed.emit(id);rpg.changed.emit()
	return {"ok":true,"message":"Construção concluída · "+definition.name,"id":id}

func repair_cost(id:String)->Dictionary:
	if not pieces.has(id):return {}
	var entry:Dictionary=pieces[id];var definition:=ConstructionCatalog.piece(entry.kind)
	var missing:=1.0-float(entry.hp)/float(definition.hp)
	var cost:Dictionary={}
	if missing<=0:return cost
	for item in definition.cost:cost[item]=maxi(1,ceili(float(definition.cost[item])*missing*0.5))
	return cost

func repair(rpg:RPGState,id:String)->Dictionary:
	if not pieces.has(id):return result(false,"Esta estrutura não existe mais.")
	var cost:=repair_cost(id)
	if cost.is_empty():return result(false,"Estrutura em perfeito estado.")
	if not rpg.tools.has("hammer"):return result(false,"Reparar exige um martelo.")
	if not afford(rpg,cost):return result(false,"Reparo: "+ConstructionCatalog.cost_text(cost))
	transfer(rpg,cost,-1);pieces[id].hp=int(ConstructionCatalog.piece(pieces[id].kind).hp)
	piece_changed.emit(id);rpg.changed.emit()
	return result(true,"Estrutura reparada.")

func damage(rpg:RPGState,id:String,points:int)->Dictionary:
	if not pieces.has(id) or points<=0:return result(false,"Sem dano.")
	pieces[id].hp=maxi(0,int(pieces[id].hp)-mini(points,100000))
	if pieces[id].hp==0:
		remove(rpg,id,false)
		return {"ok":true,"destroyed":true,"message":"Uma estrutura foi destruída. Os materiais da fila foram devolvidos."}
	piece_changed.emit(id);rpg.changed.emit()
	return {"ok":true,"destroyed":false,"message":"Estrutura danificada."}

func remove(rpg:RPGState,id:String,salvage:bool=true)->Dictionary:
	if not pieces.has(id):return result(false,"Esta estrutura não existe mais.")
	for job in queues.get(id,[]):transfer(rpg,ConstructionCatalog.recipe(job.recipe).cost,int(job.count))
	queues.erase(id)
	if salvage:
		var entry:Dictionary=pieces[id];var definition:=ConstructionCatalog.piece(entry.kind)
		var refund:Dictionary={}
		for item in definition.cost:refund[item]=floori(float(definition.cost[item])*0.5*float(entry.hp)/float(definition.hp))
		transfer(rpg,refund,1)
	pieces.erase(id)
	if player_bed==id:player_bed=""
	piece_changed.emit(id);rpg.changed.emit()
	return result(true,"Peça desmontada. Parte dos materiais foi recuperada; reservas da fila foram devolvidas.")

func assign(rpg:RPGState,id:String,npc:String,slot:String)->Dictionary:
	if not pieces.has(id) or not slot in ["resident","worker"]:return result(false,"Designação inválida.")
	var definition:=ConstructionCatalog.piece(pieces[id].kind)
	if slot=="resident" and not definition.get("home",false) or slot=="worker" and not definition.has("station"):return result(false,"Esta peça não oferece essa função.")
	if not npc.is_empty() and KingdomData.person(npc).is_empty():return result(false,"Morador desconhecido.")
	if not npc.is_empty():
		for other in pieces:
			if other!=id and pieces[other].get(slot,"")==npc:
				pieces[other][slot]="";piece_changed.emit(other)
	pieces[id][slot]=npc
	if slot=="resident" and not npc.is_empty() and player_bed==id:player_bed=""
	piece_changed.emit(id);rpg.changed.emit()
	return result(true,"Designação atualizada. O morador seguirá seus próprios horários.")

func assigned(npc:String,slot:String)->String:
	if npc.is_empty():return ""
	for id in pieces:
		if pieces[id].get(slot,"")==npc:return id
	return ""

func enqueue(rpg:RPGState,id:String,recipe_id:String,count:int=1)->Dictionary:
	if not pieces.has(id):return result(false,"Bancada ausente.")
	var recipe:=ConstructionCatalog.recipe(recipe_id)
	var definition:=ConstructionCatalog.piece(pieces[id].kind)
	if recipe.is_empty() or recipe.station!=definition.get("station",""):return result(false,"Esta receita exige outra estação.")
	if int(pieces[id].hp)<=int(definition.hp)*0.25:return result(false,"Repare a estação: vida precisa estar acima de 25%.")
	if count<1 or count>5:return result(false,"Escolha entre 1 e 5 unidades por pedido.")
	if queues.get(id,[]).size()>=MAX_QUEUE:return result(false,"Fila cheia: até oito pedidos por estação.")
	if not afford(rpg,recipe.cost,count):return result(false,"Faltam materiais: "+ConstructionCatalog.cost_text(recipe.cost))
	if recipe.has("tool") and rpg.tools.has(recipe.tool) and rpg.resources.tier(recipe.tool,rpg.tools)>=int(recipe.tier):return result(false,"Você já possui essa ferramenta ou uma melhor.")
	if recipe.has("tool"):
		if count!=1:return result(false,"Ferramentas são produzidas uma por vez.")
		for jobs in queues.values():
			for job in jobs:
				var pending:=ConstructionCatalog.recipe(job.recipe)
				if pending.get("tool","")==recipe.tool and int(pending.tier)>=int(recipe.tier):return result(false,"Essa ferramenta ou uma melhor já está na fila.")
	transfer(rpg,recipe.cost,-count)
	if not queues.has(id):queues[id]=[]
	queues[id].append({"recipe":recipe_id,"count":count,"remaining":float(recipe.minutes)})
	rpg.changed.emit()
	return result(true,"Pedido adicionado. Materiais reservados; a fila avança enquanto o tempo do mundo passa.")

func cancel_job(rpg:RPGState,id:String,index:int)->Dictionary:
	if not queues.has(id) or index<0 or index>=queues[id].size():return result(false,"Pedido não encontrado.")
	var job:Dictionary=queues[id][index]
	transfer(rpg,ConstructionCatalog.recipe(job.recipe).cost,int(job.count))
	queues[id].remove_at(index)
	if queues[id].is_empty():queues.erase(id)
	rpg.changed.emit()
	return result(true,"Pedido cancelado. Materiais ainda não transformados foram devolvidos.")

func advance(rpg:RPGState,minutes:float,working:Dictionary={})->Array[String]:
	var completed:Array[String]=[]
	if not ResourceProgress.number(minutes) or minutes<=0:return completed
	for id in queues.keys():
		if not pieces.has(id):continue
		var definition:=ConstructionCatalog.piece(pieces[id].kind)
		if int(pieces[id].hp)<=int(definition.hp)*0.25:continue
		var budget:=minutes*(1.25 if working.has(id) else 1.0)
		while budget>0 and not queues[id].is_empty():
			var job:Dictionary=queues[id][0]
			if budget<float(job.remaining):job.remaining-=budget;break
			budget-=float(job.remaining)
			var recipe:=ConstructionCatalog.recipe(job.recipe)
			# Consume the paid unit before crediting its output; reloading cannot replay it.
			job.count-=1
			if job.count<=0:queues[id].remove_at(0)
			else:job.remaining=float(recipe.minutes)
			if recipe.has("output"):transfer(rpg,recipe.output,1)
			if recipe.has("tool"):
				rpg.tools[recipe.tool]=true
				if recipe.tool in ["axe","pickaxe"]:rpg.resources.tiers[recipe.tool]=maxi(rpg.resources.tier(recipe.tool,rpg.tools),int(recipe.tier))
			completed.append(recipe.name)
		if queues[id].is_empty():queues.erase(id)
	if not completed.is_empty():rpg.changed.emit()
	return completed

func save_data()->Dictionary:
	return {"pieces":pieces.duplicate(true),"queues":queues.duplicate(true),"stock":stock.duplicate(true),"serial":serial,"player_bed":player_bed}

func restore(source:Variant)->void:
	pieces.clear();queues.clear();stock.clear();serial=0;player_bed=""
	if not source is Dictionary:return
	ConstructionCatalog.load_data()
	var saved:Variant=source.get("pieces",{})
	if saved is Dictionary:
		for id in saved:
			if pieces.size()>=MAX_PIECES:break
			if not id is String or not id.begins_with("piece_") or not id.trim_prefix("piece_").is_valid_int():continue
			var number:=int(id.trim_prefix("piece_"))
			if number<1 or number>100000000:continue
			var entry:Variant=saved[id]
			if not entry is Dictionary or not entry.get("kind","") is String or ConstructionCatalog.piece(entry.get("kind","")).is_empty():continue
			if not ResourceProgress.number(entry.get("x")) or not ResourceProgress.number(entry.get("y")) or not ResourceProgress.number(entry.get("turn",0)) or not ResourceProgress.number(entry.get("hp")):continue
			var at:=Vector2i(int(entry.x),int(entry.y));var turn:=posmod(int(entry.get("turn",0)),4)
			if not validate(entry.kind,at,turn).ok or float(entry.hp)<=0:continue
			var definition:=ConstructionCatalog.piece(entry.kind)
			var clean:={"kind":entry.kind,"x":at.x,"y":at.y,"turn":turn,"hp":clampi(int(entry.hp),1,int(definition.hp)),"open":entry.get("open",false)==true,"resident":"","worker":""}
			for slot in ["resident","worker"]:
				var person:Variant=entry.get(slot,"")
				if not person is String or person.is_empty() or KingdomData.person(person).is_empty() or not assigned(person,slot).is_empty():continue
				if slot=="resident" and definition.get("home",false) or slot=="worker" and definition.has("station"):clean[slot]=person
			pieces[id]=clean;serial=maxi(serial,number)
	var inventory:Variant=source.get("stock",{})
	if ResourceProgress.number(source.get("serial",0)):serial=maxi(serial,clampi(int(source.get("serial",0)),0,100000000))
	if inventory is Dictionary:
		for item in ConstructionCatalog.PROCESSED:
			if ResourceProgress.number(inventory.get(item,0)):stock[item]=clampi(int(inventory.get(item,0)),0,999999)
	var saved_queues:Variant=source.get("queues",{})
	if saved_queues is Dictionary:
		for id in saved_queues:
			if not pieces.has(id) or not saved_queues[id] is Array:continue
			var jobs:Array=[]
			for entry in saved_queues[id]:
				if jobs.size()>=MAX_QUEUE:break
				if not entry is Dictionary or not entry.get("recipe","") is String:continue
				var recipe:=ConstructionCatalog.recipe(entry.get("recipe",""))
				if recipe.is_empty() or recipe.station!=ConstructionCatalog.piece(pieces[id].kind).get("station",""):continue
				if not ResourceProgress.number(entry.get("count")) or not ResourceProgress.number(entry.get("remaining")) or entry.count<1:continue
				jobs.append({"recipe":recipe.id,"count":clampi(int(entry.count),1,5),"remaining":clampf(float(entry.remaining),0.01,float(recipe.minutes))})
			if not jobs.is_empty():queues[id]=jobs
	var bed:Variant=source.get("player_bed","")
	if bed is String and pieces.has(bed) and pieces[bed].kind=="bed" and pieces[bed].resident.is_empty():player_bed=bed

func result(ok:bool,message:String)->Dictionary:return {"ok":ok,"message":message}
