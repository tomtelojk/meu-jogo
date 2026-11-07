class_name DailyRoutines
extends RefCounted

static func entry(hour:float,label:String,points:Array,work:bool=false,social:bool=false,loop:bool=false,rest:bool=false)->Dictionary:
	return {"hour":hour,"activity":label,"points":points,"work":work,"social":social,"loop":loop,"rest":rest}

static func meal(hour:float,label:String,points:Array)->Dictionary:
	var result:=entry(hour,label,points,false,true);result.meal=true;return result

static func make(profile:Dictionary)->Array:
	var old:Array=profile.routine
	var home:String=old[0].points[0]
	var work:String=old[1].points[0]
	var social:String=old[2].points[0]
	var variation:=posmod(String(profile.id).hash(),45)/60.0
	if profile.id=="tomas":
		return [entry(0,"Descansando no quartel",[home],false,false,false,true),entry(6.25,"Patrulhando as duas margens",["bridge_west","guard_post","bridge_east","barracks"],false,false,true),meal(12.5,"Almoçando no posto",["guard_post"]),entry(13.25,"Patrulhando a travessia",["bridge_east","bridge_west","guard_post"],false,false,true),entry(19.75,"Encontrando amigos na taverna",["east_tavern"],false,true),entry(22,"Fim do turno",[home],false,false,false,true)]
	if profile.id=="lia":
		return [entry(0,"Descansando em casa",[home],false,false,false,true),entry(7.25,"Montando a banca em Aurélia",["west_market"],true),entry(9.5,"Levando mercadorias a Valverde",["east_market"],true),meal(12.25,"Almoçando em Valverde",["east_tavern"]),entry(15,"Voltando com novas mercadorias",["west_market"],true),entry(19.25,"Conversando na estalagem",["west_tavern"],false,true),entry(22.5,"Descansando em casa",[home],false,false,false,true)]
	if profile.id in ["aurel","caio"]:
		var king:String=profile.id
		var tavern:String="west_tavern" if profile.realm=="aurelia" else "east_tavern"
		return [entry(0,"Descansando no castelo",[home],false,false,false,true),entry(7.5+variation,"Caminhando nos jardins",[king+"_garden"],false,true),entry(9.25,"Recebendo os moradores",[king+"_court"],true),meal(13,"Almoçando no jardim",[king+"_garden"]),entry(15,"Audiências no pátio",[king+"_court"],true),entry(20+variation,"Conversando na taverna",[tavern],false,true),entry(22+variation,"Descansando no castelo",[home],false,false,false,true)]
	var town:String=profile.get("town","aurelia" if profile.realm=="aurelia" else "valverde")
	var work_points:Array=[work]
	if profile.role in ["Lenhador","Mineiro","Agricultor","Pastor"]:
		var kind:String={"Lenhador":"wood","Mineiro":"stone","Agricultor":"farm","Pastor":"farm"}[profile.role]
		work_points=[]
		for i in 4:work_points.append(town+"_"+kind+"_"+str(i))
	var slot:=posmod(String(profile.id).hash(),6)
	var label:String={"Lenhador":"Cortando e separando madeira","Mineiro":"Extraindo e separando pedra","Pastor":"Rondando os animais","Agricultor":"Cuidando das fileiras da lavoura","Ferreiro":"Trabalhando na forja","Artesã":"Preparando ferramentas","Herbalista":"Colhendo e preparando ervas","Cartógrafo":"Consultando mapas e arquivos"}.get(profile.role,"Cuidando do trabalho")
	return [entry(0,"Dormindo em casa",[home],false,false,false,true),entry(6+variation,"Saindo de casa",[home]),entry(6.75+variation,"Buscando ferramentas no comércio",[town+"_shop_"+str(slot)]),entry(8+variation,label,work_points,true,false,work_points.size()>1),meal(11.75+variation,"Almoçando e encontrando vizinhos",[town+"_inn_"+str(slot)]),entry(13.25+variation,label,work_points,true,false,work_points.size()>1),entry(17.5+variation,"Negociando a produção",[town+"_shop_"+str(slot)]),entry(18.75+variation,"Passeando e encontrando vizinhos",[social],false,true),entry(19.5+variation,"Conversando na taverna",[town+"_inn_"+str(slot)],false,true),entry(21.25+variation,"Dormindo em casa",[home],false,false,false,true)]
