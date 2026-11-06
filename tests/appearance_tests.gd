extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func run()->void:
	MapDocument.activate(MapDocument.original())
	var game:ForestGame=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/npc_animation_tests.gd")._test_alignment(self,game.world)
	print("APPEARANCE: %d verificações; %d falhas."%[checks,failures])
	quit(1 if failures else 0)
