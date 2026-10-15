extends Node3D

# VOLT: lightweight Godot 4 mobile third-person prototype.
const BLOCK := 26.0
const CITY := 5
var hero: CharacterBody3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.25
var move_vector := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var look_last := Vector2.ZERO
var hp := 100.0
var energy := 100.0
var defeated := 0
var enemies: Array = []
var boss: CharacterBody3D
var boss_hp := 0.0
var turbo := false
var climbing := false
var attack_cooldown := 0.0
var vehicle: Node3D
var vehicle_mode := false
var info: Label
var objective: Label
var joystick_base: Control
var stick: ColorRect
var buttons := {}
var boss_names := ["Circuito Negro", "Víbora", "Magnetron", "Tempestade", "Sombra Neon", "Dínamo", "Ferro-Velho", "Espectro", "Pulso", "Vórtice", "Cobalto", "Raijin", "Ciclone", "Zero", "Titã", "Ion", "Nêmesis", "Arconte", "Overload", "Imperador Volt"]
var power_names := ["Raio", "Dash", "Espada elétrica", "Super salto", "Escalada", "Pulso elétrico", "Regeneração", "Tempestade", "Raio em cadeia", "Supercarga", "Escudo", "Campo magnético", "Turbina", "Explosão", "Absorção", "Voo curto", "Choque sísmico", "Fúria", "Teleporte curto", "Forma suprema"]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("8ba8c0"))
	create_environment()
	create_city()
	create_hero()
	create_camera()
	create_ui()
	spawn_boss()
	for i in range(18):
		spawn_gang(Vector3(randf_range(-100,100), 2, randf_range(-100,100)))
	update_hud()

func material(c: Color, metallic := 0.0, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = 0.42
	if emission:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.2
	return m

func cube(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	var node: Node3D
	if solid:
		node = StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	else:
		node = Node3D.new()
	parent.add_child(node)
	node.position = pos
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	node.add_child(mesh)
	return node

func create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("90b5d2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e9ff")
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.3
	add_child(sun)
	cube(self, Vector3(0,-1.5,0), Vector3(310,3,310), material(Color("293947")), true)
	cube(self, Vector3(0,-1.55,-160), Vector3(450,2,80), material(Color("17668c")))
	cube(self, Vector3(0,-1.55,160), Vector3(450,2,80), material(Color("17668c")))

func create_city() -> void:
	var asphalt := material(Color("26303c"))
	var sidewalk := material(Color("71818c"))
	var glass := material(Color("58c6ef"), 0.45, true)
	var colors := [Color("4c6071"), Color("596b7b"), Color("394d60"), Color("687987")]
	for x in range(-CITY, CITY + 1):
		for z in range(-CITY, CITY + 1):
			var px := x * BLOCK
			var pz := z * BLOCK
			cube(self, Vector3(px,0.05,pz), Vector3(18,0.3,18), sidewalk)
			if abs(x) <= 1 and abs(z) <= 1:
				continue
			if abs(x) == CITY and abs(z) < 2:
				continue
			var height := randf_range(18,60)
			var width := randf_range(11,15)
			cube(self, Vector3(px,height/2.0,pz), Vector3(width,height,width), material(colors[randi()%colors.size()],0.2), true)
			# Windows on four sides, batched as sparse decorative strips.
			for floor_index in range(2, int(height/4.0)):
				for side in [-1,1]:
					cube(self, Vector3(px+side*(width/2+0.03),floor_index*4,pz), Vector3(0.12,1.35,width*0.62), glass)
					cube(self, Vector3(px,floor_index*4,pz+side*(width/2+0.03)), Vector3(width*0.62,1.35,0.12), glass)
		# Street lane markings.
		for z in range(-CITY,CITY+1):
			cube(self, Vector3(x*BLOCK+13,0.1,z*BLOCK), Vector3(0.22,0.04,4), material(Color("c5b06d")))
	for i in range(8):
		var car := Node3D.new()
		add_child(car)
		car.position = Vector3(randf_range(-115,115),0.75,round(randf_range(-4,4))*BLOCK+13)
		cube(car, Vector3.ZERO, Vector3(4,1.3,2.3), material(Color.from_hsv(randf(),0.7,0.8),0.35))
		cube(car, Vector3(0,0.85,0), Vector3(2,0.7,1.9), material(Color("1b334c")))
		car.set_meta("vehicle", true)
	for i in range(3):
		var bike := Node3D.new()
		add_child(bike)
		bike.position = Vector3(randf_range(-70,70),0.5,13+BLOCK*i)
		cube(bike, Vector3.ZERO, Vector3(2,0.65,0.7), material(Color("0dcded"),0.4))
		bike.set_meta("vehicle", true)

func create_hero() -> void:
	hero = CharacterBody3D.new()
	hero.position = Vector3(0,3,0)
	add_child(hero)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.0
	collider.shape = capsule
	collider.position.y = 1
	hero.add_child(collider)
	var armor := material(Color("0d1728"),0.8)
	var neon := material(Color("00dfff"),0.3,true)
	cube(hero, Vector3(0,1.15,0), Vector3(0.9,1.1,0.5), armor)
	cube(hero, Vector3(0,1.28,-0.27), Vector3(0.55,0.15,0.07), neon)
	cube(hero, Vector3(0,1.93,0), Vector3(0.58,0.65,0.55), armor)
	cube(hero, Vector3(0,1.96,-0.3), Vector3(0.52,0.14,0.08), neon)
	for side in [-1,1]:
		cube(hero, Vector3(side*0.65,1.18,0), Vector3(0.27,0.85,0.32), armor)
		cube(hero, Vector3(side*0.65,0.95,-0.18), Vector3(0.16,0.3,0.08), neon)
		cube(hero, Vector3(side*0.26,0.36,0), Vector3(0.32,0.75,0.38), armor)
		cube(hero, Vector3(side*0.26,0.17,-0.21), Vector3(0.23,0.13,0.07), neon)
	cube(hero, Vector3(0.75,0.8,-0.1), Vector3(0.08,1.55,0.08), neon)

func create_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72
	add_child(camera)

func spawn_gang(p: Vector3) -> void:
	var e := CharacterBody3D.new()
	e.position = p
	add_child(e)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95
	e.add_child(collision)
	cube(e, Vector3(0,1,0), Vector3(0.85,1.6,0.55), material(Color("8f253d")))
	cube(e, Vector3(0,2,0), Vector3(0.58,0.58,0.55), material(Color("c58e75")))
	e.set_meta("hp", 40.0)
	e.set_meta("hit_timer", 0.0)
	enemies.append(e)

func spawn_boss() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = CharacterBody3D.new()
	boss.position = Vector3(0,2,-55)
	add_child(boss)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.85
	capsule.height = 3.2
	collision.shape = capsule
	collision.position.y = 1.6
	boss.add_child(collision)
	cube(boss,Vector3(0,1.6,0),Vector3(1.6,2.4,1.1),material(Color("5b185f"),0.6))
	cube(boss,Vector3(0,3.0,0),Vector3(1.1,1.0,1),material(Color("19122c")))
	cube(boss,Vector3(0,2,-0.6),Vector3(1.0,0.2,0.12),material(Color("ff49d6"),0.2,true))
	boss_hp = 160 + defeated * 45

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0,attack_cooldown-delta)
	energy = minf(100,energy+delta*7)
	var axis := move_vector
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): axis.y = -1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): axis.y = 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis.x = -1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis.x = 1
	axis = axis.limit_length()
	var forward := Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
	var right := Vector3(cos(camera_yaw),0,-sin(camera_yaw))
	var direction := (right*axis.x-forward*axis.y).normalized()
	if vehicle_mode and is_instance_valid(vehicle):
		vehicle.position += direction * delta * 24
		hero.position = vehicle.position + Vector3(0,1.6,0)
	else:
		var speed := 25.0 if turbo else 9.0
		hero.velocity.x = direction.x*speed
		hero.velocity.z = direction.z*speed
		if direction.length() > 0.1:
			hero.rotation.y = atan2(-direction.x,-direction.z)
		if not hero.is_on_floor():
			hero.velocity.y -= 24*delta
		if climbing and hero.is_on_wall() and energy > 0:
			hero.velocity.y = 11.0 if turbo else 6.0
			energy -= delta*10
		hero.move_and_slide()
	var focus := hero.position+Vector3(0,1.6,0)
	var offset := Vector3(sin(camera_yaw)*cos(camera_pitch),-sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*7.0
	var desired := focus+offset+Vector3(0,1.6,0)
	var query := PhysicsRayQueryParameters3D.create(focus,desired)
	query.exclude = [hero.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (focus-desired).normalized()*0.35
	camera.global_position = camera.global_position.lerp(desired,minf(1,delta*12))
	camera.look_at(focus,Vector3.UP)
	update_enemies(delta)
	update_hud()

func update_enemies(delta: float) -> void:
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			enemies.erase(e)
			continue
		var distance := e.position.distance_to(hero.position)
		if distance < 22:
			var dir := hero.position-e.position
			dir.y=0
			e.velocity = dir.normalized()*3
			e.move_and_slide()
			if distance < 2 and randf() < delta*0.55:
				hp -= 5
	if is_instance_valid(boss):
		var distance := boss.position.distance_to(hero.position)
		if distance < 42:
			var dir := hero.position-boss.position
			dir.y=0
			boss.velocity = dir.normalized()*(3.5+defeated*0.15)
			boss.move_and_slide()
			if distance < 3 and randf() < delta*0.75:
				hp -= 9
	if hp <= 0:
		hp=100
		hero.position=Vector3(0,3,0)

func attack(is_sword: bool) -> void:
	if attack_cooldown > 0 or energy < (8 if is_sword else 12): return
	attack_cooldown = 0.32 if is_sword else 0.55
	energy -= 8 if is_sword else 12
	var reach := 4.0 if is_sword else 30.0
	var dmg := (38 if is_sword else 27) + defeated*6
	var forward := Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
	for e in enemies.duplicate():
		if not is_instance_valid(e): continue
		var diff := e.position-hero.position
		if diff.length() < reach and (diff.normalized().dot(forward)>0.35 or diff.length()<2.5):
			e.set_meta("hp",float(e.get_meta("hp"))-dmg)
			if float(e.get_meta("hp"))<=0:
				enemies.erase(e)
				e.queue_free()
	if is_instance_valid(boss):
		var diff := boss.position-hero.position
		if diff.length()<reach and (diff.normalized().dot(forward)>0.35 or diff.length()<3):
			boss_hp -= dmg
			if boss_hp<=0:
				defeated += 1
				hp=100
				if defeated < boss_names.size():
					spawn_boss()
				else:
					boss.queue_free()
					boss=null

func update_hud() -> void:
	if not is_instance_valid(info): return
	info.text = "⚡ VOLT   ♥ %d   ⚡ %d   CHEFÕES %d/20" % [int(hp),int(energy),defeated]
	if defeated < 20:
		objective.text = "ALVO: %s  |  HP: %d  |  PODER: %s" % [boss_names[defeated],int(boss_hp),power_names[min(defeated,19)]]
	else:
		objective.text = "NOVA YORK LIBERTADA!"

func create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	info = Label.new()
	info.position = Vector2(20,16)
	info.add_theme_font_size_override("font_size",25)
	root.add_child(info)
	objective = Label.new()
	objective.position = Vector2(20,52)
	objective.add_theme_font_size_override("font_size",19)
	root.add_child(objective)
	var actions := [["RAIO", "ray"],["ESPADA","sword"],["PULAR","jump"],["TURBO","turbo"],["SUBIR","climb"],["USAR","use"]]
	for i in range(actions.size()):
		var b := Button.new()
		b.text = actions[i][0]
		b.custom_minimum_size = Vector2(110,70)
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		b.position = Vector2(-390+(i%3)*125,-165+(i/3)*78)
		root.add_child(b)
		buttons[actions[i][1]]=b
		b.pressed.connect(on_action.bind(actions[i][1]))
	var note := Label.new()
	note.text = "Arraste lado direito: câmera  |  Esquerdo: movimento"
	note.set_anchors_preset(Control.PRESET_TOP_LEFT)
	note.position=Vector2(20,88)
	root.add_child(note)

func on_action(action: String) -> void:
	match action:
		"ray": attack(false)
		"sword": attack(true)
		"jump":
			if hero.is_on_floor(): hero.velocity.y = 14 if defeated<3 else 19
		"turbo": turbo = not turbo
		"climb": climbing = not climbing
		"use":
			if vehicle_mode:
				vehicle_mode=false
				vehicle=null
			else:
				var nearest: Node3D
				var dist := 5.0
				for child in get_children():
					if child is Node3D and child.has_meta("vehicle"):
						var d := hero.position.distance_to(child.position)
						if d < dist:
							dist=d
							nearest=child
				if nearest:
					vehicle=nearest
					vehicle_mode=true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x*0.42 and event.position.y > 180:
				move_touch=event.index
				look_last=event.position
			elif event.position.y > 140 and event.position.x < get_viewport().get_visible_rect().size.x*0.74:
				look_touch=event.index
				look_last=event.position
		else:
			if event.index==move_touch:
				move_touch=-1
				move_vector=Vector2.ZERO
			if event.index==look_touch: look_touch=-1
	elif event is InputEventScreenDrag:
		if event.index==move_touch:
			move_vector = ((event.position-look_last)/75).limit_length()
		elif event.index==look_touch:
			camera_yaw -= event.relative.x*0.006
			camera_pitch=clampf(camera_pitch-event.relative.y*0.004,-0.9,0.5)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw-=event.relative.x*0.006
		camera_pitch=clampf(camera_pitch-event.relative.y*0.004,-0.9,0.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: on_action("jump")
			KEY_J: on_action("ray")
			KEY_K: on_action("sword")
			KEY_SHIFT: on_action("turbo")
			KEY_E: on_action("use")
			KEY_C: on_action("climb")
