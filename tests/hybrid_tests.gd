extends SceneTree

# Actual GPU integration check, including sprite pivots and gameplay projection.
# Run with -- --test --hybrid on an X11/desktop display.
var failures := 0
var checks := 0
var game: ForestGame

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)

func settle(count: int = 2) -> void:
	for i in count:
		await physics_frame
		await process_frame

func screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_journey()
	await settle(3)
	var hybrid := game.hybrid
	verify(hybrid != null and hybrid.camera.current, "câmera 3D ativa por padrão")
	verify(is_equal_approx(root.scaling_3d_scale,0.8), "modo leve reduz apenas a resolução do cenário")
	hybrid.set_light_graphics(false)
	verify(is_equal_approx(root.scaling_3d_scale,1.0), "modo nítido permite resolução integral")
	hybrid.set_light_graphics(true)
	verify(not game.world.visible and not game.camera.enabled, "apenas o cenário híbrido é desenhado")
	verify(hybrid.get_node("Ground3D").mesh is PlaneMesh, "solo é uma malha 3D real")
	verify(hybrid.get_node("River3D").mesh is ArrayMesh, "rio acompanha o traçado em 3D")
	verify(hybrid.tree_cards.size() == game.world.trees.size(), "todas as árvores têm sprites 3D")
	verify(hybrid.tree_batches.size() < game.world.trees.size()/3, "floresta usa grupos com descarte espacial em vez de uma chamada por árvore")
	verify(hybrid.pickups.size() == 5, "cinco sementes visíveis no cenário 3D")
	var card: Sprite3D = hybrid.actors[0].card
	var source := game.player.sprite
	verify(card.texture is ImageTexture, "quadros de atlas preservam sua margem no sprite 3D")
	verify(is_equal_approx(card.offset.y, -(source.position.y / source.scale.y + source.offset.y)), "pivô vertical do protagonista converte Y para altura")
	var tree: Dictionary = hybrid.tree_cards[0]
	var tree_offset: float = -(tree.source.sprite.position.y / tree.source.sprite.scale.y + tree.source.sprite.offset.y) - tree.card.texture.get_height()
	verify(is_equal_approx(tree.card.offset.y, tree_offset), "árvores sem centralização mantêm as raízes no solo")
	var screen := hybrid.screen_position(game.player.position)
	verify(screen.distance_to(Vector2(640, 400)) < 70, "câmera mantém o jogador no centro")
	await screenshot("/tmp/entre-folhas-hibrido-bosque.png")
	var origin := game.player.position
	Input.action_press("move_down")
	await settle(8)
	Input.action_release("move_down")
	verify(game.player.position.y > origin.y, "controles movimentam o jogador na perspectiva 3D")
	await settle()
	verify(card.position.is_equal_approx(hybrid._point(game.player.position)), "sprite acompanha o corpo físico")
	game.open_npc("bento")
	await settle()
	verify(game.mode == "dialog" and not game.player.active, "diálogo pausa a movimentação")
	game.close_dialog()
	var seed: Dictionary = WorldData.SEEDS[0]
	game.player.position = seed.position + Vector2(0, 30)
	hybrid.snap_camera()
	await settle(3)
	verify(game.current_interaction().get("id") == seed.id, "interação detecta semente na posição 3D")
	game.interact()
	await settle()
	verify(game.collected.has(seed.id), "semente coletada mantém lógica da missão")
	verify(not hybrid.pickups[0].node.visible, "semente 3D desaparece após coleta")
	game.reset_journey()
	verify(game.collected.is_empty(), "reinício limpa a missão")
	verify(hybrid.camera.position.is_equal_approx(hybrid._point(WorldData.SPAWN) + Vector3(0,12,14)), "reinício reposiciona a câmera 3D")
	game.player.position = KingdomData.point("forge") + Vector2(0,90)
	hybrid.snap_camera()
	await settle(3)
	await screenshot("/tmp/entre-folhas-hibrido-vila.png")
	game.player.position = Vector2(WorldData.river_x(1280),1280)
	hybrid.snap_camera()
	await settle(3)
	await screenshot("/tmp/entre-folhas-hibrido-ponte.png")
	verify(game.player.on_bridge and card.position.y>0.7, "pés do personagem acompanham a elevação do tablado")
	var river_point := Vector2(WorldData.river_x(1430),1430)
	game.player.position=river_point
	game.player.restore_surface(true)
	hybrid.snap_camera()
	await settle(3)
	verify(game.player.swimming and card.position.y < -0.2, "nadador fica parcialmente submerso")
	verify(hybrid.swim_ripple.visible and card.material_override.get_shader_parameter("swim_amount")==1.0, "água oculta as pernas e mostra ondulação")
	await screenshot("/tmp/entre-folhas-natacao.png")
	print("HYBRID: %d verificações; %d falhas." % [checks, failures])
	quit(1 if failures else 0)
