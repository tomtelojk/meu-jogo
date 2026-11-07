class_name PlacementSystem
extends Node

var game:ForestGame
var previous_map:Dictionary={}
var previous_save:Dictionary={}
var last_report:Dictionary={}
var busy:=false

func setup(source:ForestGame)->void:game=source

func show_audit(page:int=0)->void:
	if game.housing!=null and game.housing.inside():game.hud.toast("Saia da casa para verificar o continente.");return
	last_report=PlacementAudit.scan(MapDocument.current,game.journey_data())
	var report:=last_report
	var body:="%d casas verificadas · %d conflitos\nEstradas: %d curvas e %d células pintadas\n\nMargens: estrada %.2f m · água %.2f m · rochas %.2f m · construções %.2f m. Beirais e degraus também são protegidos."%[report.checked,report.issues.size(),report.road_curves,report.painted_road_cells,report.margins_metres.road,report.margins_metres.water,report.margins_metres.rock,report.margins_metres.building]
	for issue in report.issues.slice(page*6,page*6+6):body+="\n\n"+issue.name+" · "+issue.id+"\n"+issue.message
	var actions:Array[Dictionary]=[]
	if page>0:actions.append({"label":"Página anterior","callback":show_audit.bind(page-1)})
	if (page+1)*6<report.issues.size():actions.append({"label":"Próxima página","callback":show_audit.bind(page+1)})
	if not report.ok:actions.append({"label":"Realocar casas em conflito","name":"placement_repair","callback":repair})
	if not previous_map.is_empty():actions.append({"label":"Desfazer última realocação","name":"placement_undo","callback":undo})
	actions.append({"label":"Exportar relatório","name":"placement_export","callback":export_report})
	actions.append({"label":"Ver no Ateliê de Mundos","callback":game.show_map_editor})
	actions.append({"label":"Voltar à aventura","callback":game.close_dialog})
	game._open_dialog("ESTRADAS E TERRENOS","Validar posicionamento",body,actions,"placement_audit")

func export_report()->void:
	var path:String="user://reports/"+MapDocument.current.id+"-placement.json"
	var status:=ConstructionAudit.write_report(path,last_report)
	game.hud.toast("Relatório salvo em "+ProjectSettings.globalize_path(path) if status==OK else "Não foi possível salvar o relatório.",8)

func repair()->void:
	if busy:return
	busy=true
	previous_map=MapDocument.current.duplicate(true);previous_save=game.journey_data().duplicate(true)
	game._open_dialog("ESTRADAS E TERRENOS","Reorganizando os lotes","Procurando terrenos livres próximos. O progresso fica pausado durante a realocação.",[],"placement_busy")
	game.hud.toast("Procurando terrenos livres próximos...",12)
	await get_tree().process_frame
	var state:=PlacementAudit.begin_repair(previous_map,previous_save)
	while not PlacementAudit.repair_step(state,2):
		game.hud.toast("Verificando casa %d de %d..."%[state.cursor,state.before.issues.size()],12)
		await get_tree().process_frame
	var result:=PlacementAudit.finish_repair(state)
	if game.persistence:
		ConstructionAudit.write_report(game.save_path+".placement.bak",previous_save)
		ConstructionAudit.write_report("user://maps/"+previous_map.id+".placement.bak.json",previous_map)
	apply_world(result.document,result.save)
	last_report=result.after
	ConstructionAudit.write_report("user://reports/"+result.document.id+"-relocation.json",{"moved":result.moved,"unresolved":result.unresolved,"after":result.after})
	busy=false
	show_audit()
	game.hud.toast("%d casas realocadas · %d conflitos restantes. A última realocação pode ser desfeita."%[result.moved.size(),result.after.issues.size()],8)

func apply_world(document:Dictionary,journey:Dictionary)->void:
	game.apply_map(document)
	game.apply_journey(journey)
	game.world.refresh_rpg()
	game.player.position=game.world.safe_position(game.player.position)
	game.player.restore_surface()
	if game.hybrid!=null:game.hybrid.snap_camera()
	game.mode="playing";game.return_mode="playing";game.player.active=true;game.world.set_population_active(true)
	if game.persistence:MapDocument.write_file(MapDocument.ACTIVE_PATH,document)
	game.save_journey()

func undo()->void:
	if previous_map.is_empty():return
	var document:=previous_map.duplicate(true);var journey:=previous_save.duplicate(true)
	previous_map.clear();previous_save.clear()
	apply_world(document,journey);show_audit();game.hud.toast("Posições anteriores restauradas.")
