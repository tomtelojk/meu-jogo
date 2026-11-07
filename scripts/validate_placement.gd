extends SceneTree

func _initialize()->void:call_deferred("run")
func read_json(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
func write_json(path:String,data:Dictionary)->Error:
	var absolute:=ProjectSettings.globalize_path(path)
	var err:=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if err!=OK:return err
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data,"  "));f.flush();return f.get_error()
func canonical_path(path:String)->String:
	var absolute:=ProjectSettings.globalize_path(path)
	return (ProjectSettings.globalize_path("res://").path_join(absolute) if not absolute.is_absolute_path() else absolute).simplify_path()
func run()->void:
	var args:=OS.get_cmdline_user_args();var options:Dictionary={}
	for i in args.size():
		if args[i].begins_with("--") and i+1<args.size() and not args[i+1].begins_with("--"):options[args[i]]=args[i+1]
	var document:=MapDocument.original();var journey:Dictionary={}
	if options.has("--map"):
		var checked:=MapDocument.validate(read_json(options["--map"]))
		if not checked.ok:push_error("Mapa inválido ou ausente.");quit(2);return
		document=checked.document
	if options.has("--save"):
		journey=read_json(options["--save"])
		if journey.is_empty() or not journey.get("rpg") is Dictionary:push_error("Save inválido ou ausente.");quit(2);return
		if not options.has("--map"):
			if journey.get("map_id","reinos")!="reinos":push_error("Use --map para informar o mapa personalizado deste save.");quit(2);return
			document.generation=int(journey.get("world_generation",2))
		elif journey.get("map_id","reinos")!=document.id:push_error("O save pertence a outro mapa.");quit(2);return
	var report_path:String=options.get("--report","user://reports/placement-audit.json")
	var inputs:Array=[]
	for key in ["--map","--save"]:
		if options.has(key):inputs.append(canonical_path(options[key]))
	var outputs:Array=[canonical_path(report_path)]
	var report:=PlacementAudit.scan(document,journey)
	if "--fix" in args:
		if not options.has("--output-map") or not journey.is_empty() and not options.has("--output-save"):
			push_error("--fix exige --output-map e, ao usar --save, --output-save. Os originais não são sobrescritos.");quit(2);return
		for key in ["--output-map","--output-save"]:
			if options.has(key):outputs.append(canonical_path(options[key]))
		var metres:float=-1
		if options.has("--radius-metres"):
			var value:String=options["--radius-metres"]
			if not value.is_valid_float() or not is_finite(float(value)) or float(value)<1 or float(value)>64:push_error("O raio deve estar entre 1 e 64 metros.");quit(2);return
			metres=float(value)
		var unique:Dictionary={}
		for path in outputs:
			if path in inputs or unique.has(path):push_error("Relatório, mapa e save de saída devem ter caminhos distintos dos originais e entre si.");quit(2);return
			unique[path]=true
		var radius:float=metres*WorldGrid.UNITS_PER_METRE
		var repaired:=PlacementAudit.repair(document,journey,radius)
		if write_json(options["--output-map"],repaired.document)!=OK:push_error("Não foi possível escrever o mapa corrigido.");quit(2);return
		if not journey.is_empty() and write_json(options["--output-save"],repaired.save)!=OK:push_error("Não foi possível escrever o save corrigido.");quit(2);return
		report={"before":repaired.before,"after":repaired.after,"moved":repaired.moved,"unresolved":repaired.unresolved,"ok":repaired.ok}
	var path:String=report_path
	if canonical_path(path) in inputs:push_error("O relatório deve ter caminho diferente dos originais.");quit(2);return
	if write_json(path,report)!=OK:push_error("Não foi possível escrever o relatório.");quit(2);return
	var final:Dictionary=report.get("after",report)
	print("PLACEMENT AUDIT: %d casas; %d conflitos; %d curvas; %d células de estrada."%[final.checked,final.issues.size(),final.road_curves,final.painted_road_cells])
	for issue in final.issues:print(issue.id," · ",issue.code," · ",issue.position_world," · ",issue.message)
	if report.has("moved"):print("Realocadas: ",report.moved.size())
	print("Relatório: "+ProjectSettings.globalize_path(path));quit(0 if final.ok else 1)
