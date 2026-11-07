extends SceneTree

func _initialize()->void:call_deferred("run")
func run()->void:
	var args:=OS.get_cmdline_user_args();var input:="";var output:="user://reports/grid-audit.json"
	for i in args.size():
		if args[i]=="--input" and i+1<args.size():input=args[i+1]
		if args[i]=="--report" and i+1<args.size():output=args[i+1]
	var existing:Dictionary=ConstructionAudit.scan({})
	if not input.is_empty():
		if not FileAccess.file_exists(input):push_error("Arquivo de entrada ausente: "+input);quit(2);return
		var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(input))
		existing=ConstructionAudit.saved(document)
	var models:=ConstructionAudit.assets()
	var report:={"grid":{"cell_metres":WorldGrid.CELL_SIZE,"world_units":WorldGrid.CELL,"pivot":"ground_corner","version":WorldGrid.VERSION},"existing":existing,"assets":models}
	if ConstructionAudit.write_report(output,report)!=OK:push_error("Não foi possível escrever o relatório: "+output);quit(2);return
	print("GRID AUDIT: %d peças existentes; %d problemas; %d módulos; %d modelos modulares fora do padrão."%[existing.checked,existing.issues.size(),models.modules.size(),models.outside_standard.size()])
	for issue in existing.issues:print("PEÇA ",issue.id," · ",issue.message)
	for model in models.modules:
		if not model.ok:print("ASSET ",model.id," · ",model.errors)
	for prefab in models.environment_prefabs:
		if prefab.fractional_size or prefab.oversized_mesh:print("PREFAB NÃO MODULAR ",prefab.id," · terreno ",prefab.size_metres," m · mesh ",prefab.mesh_size_metres," m")
	print("Relatório: "+ProjectSettings.globalize_path(output))
	quit(0 if existing.ok and models.ok else 1)
