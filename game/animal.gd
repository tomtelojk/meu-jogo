class_name WorldAnimal
extends CharacterBody2D

const SPECIES := {
	"cow":{"name":"Vaca","health":60,"speed":34.0,"hostile":false},
	"chicken":{"name":"Galinha","health":15,"speed":48.0,"hostile":false},
	"deer":{"name":"Cervo","health":40,"speed":110.0,"hostile":false},
	"rabbit":{"name":"Coelho","health":15,"speed":95.0,"hostile":false},
	"boar":{"name":"Javali","health":65,"speed":85.0,"hostile":true},
}
var definition:Dictionary
var species := "deer"
var animal_id := ""
var home := Vector2.ZERO
var target := Vector2.ZERO
var game:ForestGame
var health := 40
var alive := true
var active := false
var gait := 0.0
var facing := Vector2.DOWN
var change_target := 0.0
var attack_delay := 0.0
var produce_daytime := -9999.0
var rng := RandomNumberGenerator.new()

func setup(data:Dictionary,source:ForestGame)->void:
	game=source
	species=data.species
	definition=SPECIES[species]
	animal_id=data.id
	position=data.position
	home=position
	target=position
	health=definition.health
	rng.seed=animal_id.hash()
	motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer=64
	collision_mask=WorldData.SOLID_LAYER|WorldData.WATER_LAYER|WorldData.BRIDGE_RAIL_LAYER
	var shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=13 if species in ["cow","boar"] else 7
	shape.shape=circle
	add_child(shape)
	if species in ["cow","chicken"]:
		var area:=Area2D.new()
		area.collision_layer=2
		area.collision_mask=0
		area.monitoring=false
		var sensor:=CollisionShape2D.new()
		var reach:=CircleShape2D.new()
		reach.radius=65
		sensor.shape=reach
		area.add_child(sensor)
		area.set_meta("interaction",{"kind":"animal","id":animal_id,"name":definition.name,"range":65.0})
		add_child(area)

func _physics_process(delta:float)->void:
	if not active or not alive:
		velocity=Vector2.ZERO
		return
	attack_delay=maxf(0,attack_delay-delta)
	change_target-=delta
	var distance:=position.distance_to(game.player.position)
	if definition.hostile and distance<190 and not game.player.swimming:
		target=game.player.position
		if distance<28 and attack_delay<=0:
			game.take_damage(9)
			attack_delay=1.3
	elif species in ["deer","rabbit"] and distance<125:
		target=position+(position-game.player.position).normalized()*140
	elif change_target<=0:
		target=home+Vector2(rng.randf_range(-110,110),rng.randf_range(-110,110))
		change_target=rng.randf_range(2.0,5.0)
	var direction:=position.direction_to(target) if position.distance_to(target)>8 else Vector2.ZERO
	if not WorldData.can_stand(position+direction*30,game.world.data,8):
		change_target=0
		direction=Vector2.ZERO
	velocity=direction*definition.speed
	move_and_slide()
	if direction.length_squared()>0.01:
		facing=direction
		gait+=delta*get_real_velocity().length()/12.0

func hurt(damage:int)->bool:
	if not alive:return false
	health-=damage
	if health>0:
		target=game.player.position if definition.hostile else home+facing*150
		return false
	alive=false
	visible=false
	get_child(0).set_deferred("disabled",true)
	game.rpg.depleted[animal_id]=true
	game.rpg.meat+=2 if species in ["cow","deer","boar"] else 1
	game.rpg.xp+=20 if definition.hostile else 10
	game.rpg.changed.emit()
	return true

func produce()->Dictionary:
	var now:=game.world.clock.day*1440.0+game.world.clock.minute
	if now-float(game.rpg.produce_times.get(animal_id,-9999))<120:return {"ok":false,"message":"Este animal já forneceu alimento. Volte mais tarde."}
	produce_daytime=now
	game.rpg.produce_times[animal_id]=now
	game.rpg.food+=1
	game.rpg.xp+=5
	game.rpg.changed.emit()
	return {"ok":true,"message":"Você ajudou na fazenda: +1 provisão · +5 XP."}
