extends Node3D

var player: CharacterBody3D
var view: Camera3D
var move_axis := Vector2.ZERO
var start_touch := Vector2.ZERO
var move_finger := -1
var look_finger := -1
var yaw := 0.0
var pitch := -0.22
var energy := 100.0
var hp := 100.0
var defeated := 0
var foes: Array[CharacterBody3D] = []
var status: Label
var boss: CharacterBody3D
var boss_hp := 100.0
var boost := false
var cooldown := 0.0

func block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(node)
	node.position = pos
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		node.add_child(shape)
	var mesh := MeshInstance3D.new()
	var boxmesh := BoxMesh.new()
	boxmesh.size = size
	mesh.mesh = boxmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	node.add_child(mesh)
	return node

func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8ab8d9")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.85
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	block(self, Vector3(0, -1.0, 0), Vector3(330, 2, 330), Color("273643"), true)
	for x in range(-5, 6):
		for z in range(-5, 6):
			var px := float(x) * 27.0
			var pz := float(z) * 27.0
			block(self, Vector3(px, 0.1, pz), Vector3(18, 0.2, 18), Color("758797"))
			if abs(x) < 2 and abs(z) < 2:
				continue
			var height := randf_range(12, 58)
			block(self, Vector3(px, height / 2.0, pz), Vector3(14, height, 14), Color.from_hsv(randf_range(0.55, 0.63), 0.27, randf_range(0.35, 0.65)), true)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 2, 0)
	add_child(player)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	player.add_child(col)
	block(player, Vector3(0, 1.1, 0), Vector3(0.85, 1.2, 0.55), Color("14233b"))
	block(player, Vector3(0, 1.95, 0), Vector3(0.6, 0.6, 0.6), Color("14233b"))
	block(player, Vector3(0, 1.2, -0.3), Vector3(0.6, 0.12, 0.08), Color("00e7ff"))
	view = Camera3D.new()
	view.current = true
	add_child(view)
	for i in range(12):
		spawn_foe(Vector3(randf_range(-80, 80), 2, randf_range(-80, 80)))
	spawn_boss()
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	status = Label.new()
	status.position = Vector2(22, 16)
	status.add_theme_font_size_override("font_size", 25)
	ui.add_child(status)
	var names := ["RAIO", "ESPADA", "PULAR", "TURBO"]
	for i in range(names.size()):
		var button := Button.new()
		button.text = names[i]
		button.custom_minimum_size = Vector2(125, 76)
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.position = Vector2(-280 + (i % 2) * 135, -205 + int(i / 2) * 90)
		ui.add_child(button)
		button.pressed.connect(action.bind(i))
	status.text = "VOLT | Nova York"

func spawn_foe(where: Vector3) -> void:
	var foe := CharacterBody3D.new()
	foe.position = where
	add_child(foe)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.9
	col.position.y = 0.95
	col.shape = cap
	foe.add_child(col)
	block(foe, Vector3(0, 1, 0), Vector3(0.8, 1.8, 0.5), Color("a33451"))
	foe.set_meta("hp", 50.0)
	foes.append(foe)

func spawn_boss() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = CharacterBody3D.new()
	boss.position = Vector3(0, 2, -45)
	add_child(boss)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 3.0
	cap.radius = 0.8
	col.position.y = 1.5
	col.shape = cap
	boss.add_child(col)
	block(boss, Vector3(0, 1.5, 0), Vector3(1.5, 2.8, 1.0), Color("732a8b"))
	boss_hp = 120.0 + float(defeated) * 40.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	energy = minf(100.0, energy + delta * 9.0)
	var axis := move_axis
	axis.x += Input.get_axis("ui_left", "ui_right")
	axis.y += Input.get_axis("ui_up", "ui_down")
	axis = axis.limit_length()
	var direction := Vector3(cos(yaw) * axis.x + sin(yaw) * axis.y, 0, -sin(yaw) * axis.x + cos(yaw) * axis.y)
	player.velocity.x = direction.x * (18.0 if boost else 8.0)
	player.velocity.z = direction.z * (18.0 if boost else 8.0)
	if not player.is_on_floor():
		player.velocity.y -= 24.0 * delta
	player.move_and_slide()
	if direction.length() > 0.1:
		player.rotation.y = atan2(-direction.x, -direction.z)
	var focus := player.global_position + Vector3(0, 1.5, 0)
	var target := focus + Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * 7.0
	view.global_position = view.global_position.lerp(target, minf(1.0, delta * 10.0))
	view.look_at(focus, Vector3.UP)
	for foe in foes:
		if not is_instance_valid(foe):
			continue
		var diff: Vector3 = player.global_position - foe.global_position
		if diff.length() < 20.0:
			foe.velocity = Vector3(diff.x, 0, diff.z).normalized() * 3.0
			foe.move_and_slide()
			if diff.length() < 2.0 and randf() < delta * 0.4:
				hp -= 5.0
	if is_instance_valid(boss):
		var diff: Vector3 = player.global_position - boss.global_position
		if diff.length() < 38.0:
			boss.velocity = Vector3(diff.x, 0, diff.z).normalized() * 3.5
			boss.move_and_slide()
			if diff.length() < 3.0 and randf() < delta * 0.5:
				hp -= 8.0
	if hp <= 0:
		hp = 100.0
		player.position = Vector3(0, 3, 0)
	status.text = "VOLT   VIDA %d   ENERGIA %d   CHEFOES %d/20" % [int(hp), int(energy), defeated]

func action(index: int) -> void:
	if index == 2:
		if player.is_on_floor():
			player.velocity.y = 13.0
		return
	if index == 3:
		boost = not boost
		return
	if cooldown > 0.0 or energy < 12.0:
		return
	cooldown = 0.4
	energy -= 12.0
	var reach := 5.0 if index == 1 else 28.0
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	for foe in foes.duplicate():
		if not is_instance_valid(foe):
			continue
		var diff: Vector3 = foe.global_position - player.global_position
		if diff.length() < reach and (diff.normalized().dot(forward) > 0.2 or diff.length() < 3.0):
			foe.set_meta("hp", float(foe.get_meta("hp")) - 30.0)
			if float(foe.get_meta("hp")) <= 0.0:
				foes.erase(foe)
				foe.queue_free()
	if is_instance_valid(boss):
		var diff: Vector3 = boss.global_position - player.global_position
		if diff.length() < reach and (diff.normalized().dot(forward) > 0.2 or diff.length() < 3.0):
			boss_hp -= 30.0
			if boss_hp <= 0.0:
				defeated += 1
				if defeated < 20:
					spawn_boss()
				else:
					boss.queue_free()
					boss = null

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < get_viewport().get_visible_rect().size.x * 0.45:
				move_finger = touch.index
				start_touch = touch.position
			elif touch.position.x < get_viewport().get_visible_rect().size.x * 0.72:
				look_finger = touch.index
		else:
			if touch.index == move_finger:
					move_finger = -1
					move_axis = Vector2.ZERO
				if touch.index == look_finger:
					look_finger = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == move_finger:
			move_axis = ((drag.position - start_touch) / 75.0).limit_length()
		elif drag.index == look_finger:
			yaw -= drag.relative.x * 0.006
			pitch = clampf(pitch - drag.relative.y * 0.004, -0.85, 0.4)
