extends Node2D
# Original 2D arena-survival action game, inspired by mobile hero progression games.
const W := 1280.0
const H := 720.0
const WORLD := 3300.0
const BOSSES := ["CONDUTOR", "FERRUM", "SPECTRA", "SENTINELA", "MERCURIO", "VORTEX", "COLOSSO", "NEXUS", "CARRASCO", "TEMPESTADE", "CROMO", "ESPECTRO", "MAGNETAR", "TITAN", "PHANTOM", "APAGAO", "ORACULO", "REATOR", "OMEGA", "ZERO ABSOLUTO"]
const CYAN := Color("44f3ff")
const NAVY := Color("101c36")
const GOLD := Color("ffce71")
var hero := Vector2(1650, 1650)
var cam := Vector2.ZERO
var hp := 100.0
var max_hp := 100.0
var energy := 100.0
var level := 1
var xp := 0.0
var xp_need := 70.0
var kills := 0
var boss_index := 0
var boss: Dictionary = {}
var boss_wait := 18.0
var enemies: Array = []
var bullets: Array = []
var sparks: Array = []
var drops: Array = []
var buildings: Array = []
var cars: Array = []
var elapsed := 0.0
var spawn_clock := 0.0
var fire_clock := 0.0
var dash_clock := 0.0
var dash_time := 0.0
var pulse_clock := 0.0
var slash_clock := 0.0
var invuln := 0.0
var hero_flash := 0.0
var shake := 0.0
var aim := Vector2.RIGHT
var move_axis := Vector2.ZERO
var stick_id := -1
var stick_origin := Vector2(170, 555)
var stick_current := Vector2(170, 555)
var button_touches := {}
var upgrade_choices: Array = []
var upgrade_screen := false
var won := false
var damage := 20.0
var rate := 0.36
var speed := 290.0
var chain_count := 1
var pickup_radius := 90.0
var aura_level := 0
var last_notice := "DISTRITO 01  /  SOBREVIVA E EVOLUA"
var notice_time := 4.0
var rng := RandomNumberGenerator.new()
var ui_font: Font

func _ready() -> void:
	rng.seed = 20261015
	ui_font = ThemeDB.fallback_font
	generate_city()
	for i in range(9):
		spawn_enemy()
	queue_redraw()

func generate_city() -> void:
	# City blocks occupy islands between wide walkable avenues.
	for gx in range(1, 11):
		for gy in range(1, 11):
			if gx >= 5 and gx <= 6 and gy >= 5 and gy <= 6:
				continue
			var center := Vector2(gx * 300.0, gy * 300.0)
			var height := rng.randf_range(85.0, 145.0)
			var width := rng.randf_range(105.0, 160.0)
			var tint := rng.randi_range(0, 3)
			buildings.append({"rect": Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height)), "tint": tint, "seed": gx * 71 + gy * 13})
	for i in range(35):
		var p := Vector2(rng.randf_range(100, 3200), rng.randf_range(100, 3200))
		if not blocked(p, 55.0):
			cars.append({"p": p, "color": [Color("b8495d"), Color("4c89ad"), Color("d1b778")][i % 3], "horizontal": i % 2 == 0})

func blocked(p: Vector2, padding: float = 12.0) -> bool:
	for b in buildings:
		if b["rect"].grow(padding).has_point(p):
			return true
	return false

func valid_position(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 40.0, WORLD - 40.0), clampf(p.y, 40.0, WORLD - 40.0))

func spawn_enemy() -> void:
	if enemies.size() >= 65:
		return
	for trial in range(22):
		var a := rng.randf_range(-PI, PI)
		var distance := rng.randf_range(470, 740)
		var p := valid_position(hero + Vector2.RIGHT.rotated(a) * distance)
		if not blocked(p, 22.0) and p.distance_to(hero) > 310:
			var kind := rng.randi_range(0, 2)
			var life := 34.0 + float(level) * 6.0 + float(kind) * 8.0
			enemies.append({"p": p, "hp": life, "max": life, "kind": kind, "hit": 0.0, "phase": rng.randf_range(0, 6.28)})
			return

func spawn_boss() -> void:
	if boss_index >= BOSSES.size():
		won = true
		return
	var pos := hero + Vector2(0, -360)
	if blocked(pos, 65.0):
		pos = hero + Vector2(300, 0)
	boss = {"p": valid_position(pos), "hp": 460.0 + boss_index * 170.0, "max": 460.0 + boss_index * 170.0, "attack": 2.5, "phase": 0.0, "hit": 0.0, "kind": boss_index % 5}
	last_notice = "CHEFAO %02d/20  -  %s" % [boss_index + 1, BOSSES[boss_index]]
	notice_time = 4.0
	shake = 9.0

func _physics_process(dt: float) -> void:
	elapsed += dt
	if notice_time > 0.0:
		notice_time -= dt
	if upgrade_screen or won:
		queue_redraw()
		return
	invuln = maxf(0.0, invuln - dt)
	hero_flash = maxf(0.0, hero_flash - dt)
	shake = maxf(0.0, shake - dt * 35.0)
	fire_clock -= dt
	dash_clock -= dt
	dash_time -= dt
	pulse_clock -= dt
	slash_clock -= dt
	boss_wait -= dt
	spawn_clock -= dt
	energy = minf(100.0, energy + dt * 12.0)
	var direction := move_axis + Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = direction.limit_length()
	if direction.length() > 0.15:
		aim = direction.normalized()
	var multiplier := 2.7 if dash_time > 0 else 1.0
	var delta_move := direction * speed * multiplier * dt
	move_hero(delta_move)
	if aura_level > 0:
		for e in enemies:
			if e["p"].distance_to(hero) < 100.0 + aura_level * 25.0:
				e["hp"] -= dt * aura_level * 8.0
	if spawn_clock <= 0.0:
		spawn_enemy()
		spawn_clock = maxf(0.28, 1.1 - elapsed * 0.003)
	if boss.is_empty() and boss_wait <= 0.0:
		spawn_boss()
	if fire_clock <= 0.0:
		fire_auto()
		fire_clock = rate
	update_enemies(dt)
	update_boss(dt)
	update_bullets(dt)
	update_sparks(dt)
	collect_drops(dt)
	cam = (hero - Vector2(W, H) * 0.5).clamp(Vector2.ZERO, Vector2(WORLD - W, WORLD - H))
	queue_redraw()

func move_hero(delta_move: Vector2) -> void:
	var next := valid_position(hero + Vector2(delta_move.x, 0))
	if not blocked(next, 19):
		hero.x = next.x
	next = valid_position(hero + Vector2(0, delta_move.y))
	if not blocked(next, 19):
		hero.y = next.y

func fire_auto() -> void:
	var nearest := 570.0
	var target := Vector2.ZERO
	for e in enemies:
		var d: float = hero.distance_to(e["p"])
		if d < nearest:
			nearest = d
			target = e["p"]
	if not boss.is_empty():
		var d: float = hero.distance_to(boss["p"])
		if d < nearest:
			nearest = d
			target = boss["p"]
	if nearest >= 570.0:
		return
	var direction: Vector2 = (target - hero).normalized()
	for i in range(chain_count):
		var spread := (float(i) - float(chain_count - 1) * 0.5) * 0.17
		bullets.append({"p": hero + direction * 29.0, "v": direction.rotated(spread) * 780.0, "life": 0.75, "dmg": damage, "enemy": false, "color": CYAN})
	add_spark(hero + direction * 29.0, CYAN, 7)

func use_dash() -> void:
	if dash_clock > 0.0 or energy < 18.0:
		return
	dash_clock = 1.3
	dash_time = 0.19
	invuln = 0.25
	energy -= 18.0
	add_spark(hero, CYAN, 16)

func use_pulse() -> void:
	if pulse_clock > 0.0 or energy < 35.0:
		return
	pulse_clock = 5.0
	energy -= 35.0
	shake = 9.0
	add_spark(hero, CYAN, 38)
	for e in enemies:
		if e["p"].distance_to(hero) < 230.0:
			e["hp"] -= damage * 2.6
			e["hit"] = 0.18
	if not boss.is_empty() and boss["p"].distance_to(hero) < 260.0:
		boss["hp"] -= damage * 2.6
		boss["hit"] = 0.2

func use_slash() -> void:
	if slash_clock > 0.0:
		return
	slash_clock = 0.55
	add_spark(hero + aim * 55.0, GOLD, 14)
	for e in enemies:
		if e["p"].distance_to(hero) < 105.0:
			e["hp"] -= damage * 1.65
			e["hit"] = 0.15
	if not boss.is_empty() and boss["p"].distance_to(hero) < 120.0:
		boss["hp"] -= damage * 1.65
		boss["hit"] = 0.15

func update_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e["hp"] <= 0.0:
			drops.append({"p": e["p"], "value": 12.0 + level * 2.0})
			add_spark(e["p"], Color("ff648f"), 9)
			enemies.remove_at(i)
			kills += 1
			continue
		var diff: Vector2 = hero - e["p"]
		var distance := diff.length()
		if distance > 1250.0:
			enemies.remove_at(i)
			continue
		var step := diff.normalized() * (94.0 + float(e["kind"]) * 25.0 + level * 2.0) * dt
		if distance > 34.0:
			var p: Vector2 = valid_position(e["p"] + Vector2(step.x, 0))
			if not blocked(p, 18):
				e["p"] = p
			p = valid_position(e["p"] + Vector2(0, step.y))
			if not blocked(p, 18):
				e["p"] = p
		if distance < 36.0:
			hurt(9.0 + level * 0.7)
		e["hit"] = maxf(0.0, e["hit"] - dt)
		e["phase"] += dt * 5.0

func update_boss(dt: float) -> void:
	if boss.is_empty():
		return
	if boss["hp"] <= 0.0:
		add_spark(boss["p"], GOLD, 55)
		for i in range(16):
			drops.append({"p": boss["p"] + Vector2(rng.randf_range(-85, 85), rng.randf_range(-85, 85)), "value": 24.0})
		boss_index += 1
		boss.clear()
		boss_wait = 15.0
		if boss_index >= 20:
			won = true
		else:
			last_notice = "CHEFAO DERROTADO!  %d/20" % boss_index
			notice_time = 4.0
		return
	var diff: Vector2 = hero - boss["p"]
	var dist := diff.length()
	boss["phase"] += dt
	boss["hit"] = maxf(0.0, boss["hit"] - dt)
	if dist > 82.0:
		var step := diff.normalized() * (80.0 + boss_index * 2.0) * dt
		var p: Vector2 = valid_position(boss["p"] + step)
		if not blocked(p, 50.0):
			boss["p"] = p
	if dist < 67.0:
		hurt(20.0 + boss_index * 2.0)
	boss["attack"] -= dt
	if boss["attack"] <= 0.0:
		boss["attack"] = maxf(0.85, 2.5 - boss_index * 0.06)
		var count := 7 + int(boss_index / 4)
		for j in range(count):
			var a := float(j) * TAU / count + boss["phase"]
			bullets.append({"p": boss["p"], "v": Vector2.RIGHT.rotated(a) * (210.0 + boss_index * 8.0), "life": 3.0, "dmg": 12.0 + boss_index, "enemy": true, "color": Color("ff5a9c")})
		add_spark(boss["p"], Color("ff5a9c"), 16)

func update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["life"] -= dt
		b["p"] += b["v"] * dt
		if b["life"] <= 0.0 or blocked(b["p"], 0):
			bullets.remove_at(i)
			continue
		var hit := false
		if b["enemy"]:
			if b["p"].distance_to(hero) < 23.0:
				hurt(b["dmg"])
				hit = true
		else:
			for e in enemies:
				if b["p"].distance_to(e["p"]) < 27.0:
					e["hp"] -= b["dmg"]
					e["hit"] = 0.15
					hit = true
					break
			if not hit and not boss.is_empty() and b["p"].distance_to(boss["p"]) < 55.0:
				boss["hp"] -= b["dmg"]
				boss["hit"] = 0.13
				hit = true
		if hit:
			add_spark(b["p"], b["color"], 6)
			bullets.remove_at(i)

func hurt(amount: float) -> void:
	if invuln > 0.0:
		return
	hp -= amount
	invuln = 0.75
	hero_flash = 0.3
	shake = 7.0
	if hp <= 0.0:
		hp = max_hp
		energy = 100.0
		enemies.clear()
		boss.clear()
		boss_wait = 10.0
		last_notice = "VOLT REANIMADO  -  CONTINUE A MISSAO"
		notice_time = 3.0

func collect_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[i]
		var diff: Vector2 = hero - drop["p"]
		if diff.length() < pickup_radius * 2.0:
			drop["p"] += diff.normalized() * dt * 450.0
		if diff.length() < 27.0:
			xp += drop["value"]
			drops.remove_at(i)
			if xp >= xp_need and not upgrade_screen:
				xp -= xp_need
				level += 1
				xp_need = 65.0 + level * 28.0
				upgrade_screen = true
				upgrade_choices = ["PODER +25%", "ATAQUE MAIS RAPIDO", "VIDA +30", "RAIOS EXTRAS", "CAMPO ELETRICO", "VELOCIDADE +15%"]

func add_spark(p: Vector2, color: Color, amount: int) -> void:
	for i in range(amount):
		var v := Vector2.RIGHT.rotated(rng.randf_range(0, TAU)) * rng.randf_range(70, 310)
		sparks.append({"p": p, "v": v, "life": rng.randf_range(0.16, 0.52), "max": 0.52, "color": color})
	if sparks.size() > 380:
		sparks = sparks.slice(sparks.size() - 380)

func update_sparks(dt: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["life"] -= dt
		s["p"] += s["v"] * dt
		s["v"] *= 0.9
		if s["life"] <= 0.0:
			sparks.remove_at(i)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("0a1224"))
	var offset := -cam
	if shake > 0.0:
		offset += Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	draw_set_transform(offset)
	draw_city()
	for drop in drops:
		var p: Vector2 = drop["p"]
		if visible_world(p, 25):
			draw_circle(p, 13.0, Color("20c7d5", 0.2))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11), p + Vector2(9, 0), p + Vector2(0, 11), p + Vector2(-9, 0)]), CYAN)
	for e in enemies:
		if visible_world(e["p"], 40):
			draw_enemy(e)
	if not boss.is_empty() and visible_world(boss["p"], 100):
		draw_boss()
	for b in bullets:
		if visible_world(b["p"], 25):
			draw_circle(b["p"], 15.0 if not b["enemy"] else 10.0, Color(b["color"], 0.2))
			draw_line(b["p"] - b["v"].normalized() * 19.0, b["p"], b["color"], 6.0, true)
			draw_circle(b["p"], 5.0, Color.WHITE)
	for s in sparks:
		if visible_world(s["p"], 10):
			draw_circle(s["p"], maxf(1.0, s["life"] * 7.0), Color(s["color"], clampf(s["life"] * 2.0, 0, 1)))
	draw_hero()
	draw_set_transform(Vector2.ZERO)
	draw_hud()

func visible_world(p: Vector2, pad: float) -> bool:
	return p.x > cam.x - pad and p.x < cam.x + W + pad and p.y > cam.y - pad and p.y < cam.y + H + pad

func draw_city() -> void:
	var area := Rect2(cam - Vector2(80, 80), Vector2(W + 160, H + 160))
	draw_rect(area, Color("1c2c3e"))
	# Asphalt grid with zebra crossings, road lane markings and sidewalks.
	for n in range(12):
		var coord := float(n) * 300.0
		if coord > cam.x - 130 and coord < cam.x + W + 130:
			draw_rect(Rect2(coord - 55, cam.y - 80, 110, H + 160), Color("101a2c"))
			for k in range(int(cam.y / 90) - 1, int((cam.y + H) / 90) + 2):
				draw_rect(Rect2(coord - 2, float(k) * 90, 4, 40), Color("d9bd7c", 0.55))
		if coord > cam.y - 130 and coord < cam.y + H + 130:
			draw_rect(Rect2(cam.x - 80, coord - 55, W + 160, 110), Color("101a2c"))
			for k in range(int(cam.x / 90) - 1, int((cam.x + W) / 90) + 2):
				draw_rect(Rect2(float(k) * 90, coord - 2, 40, 4), Color("d9bd7c", 0.55))
	for b in buildings:
		var rect: Rect2 = b["rect"]
		if not rect.intersects(area):
			continue
		var palette := [Color("314762"), Color("354058"), Color("344b50"), Color("53475b")]
		draw_rect(rect.grow(13), Color("69798a"))
		draw_rect(rect.grow(6), Color("182337"))
		draw_rect(rect, palette[b["tint"]])
		draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), palette[b["tint"]].lightened(0.10))
		draw_rect(Rect2(rect.position + Vector2(14, 13), Vector2(rect.size.x - 28, 8)), Color("718b9c", 0.55))
		for wx in range(int(rect.size.x / 25) - 1):
			for wy in range(int(rect.size.y / 27) - 1):
				var light := (wx * 11 + wy * 7 + b["seed"]) % 5 != 0
				var c := Color("b7e8e7") if light else Color("17263c")
				draw_rect(Rect2(rect.position + Vector2(19 + wx * 25, 29 + wy * 27), Vector2(12, 13)), c)
		# Rooftop air conditioners and neon strip.
		draw_rect(Rect2(rect.position + Vector2(18, rect.size.y - 32), Vector2(45, 21)), Color("1c2a39"))
		draw_rect(Rect2(rect.position + Vector2(21, rect.size.y - 29), Vector2(39, 15)), Color("70858f"))
		draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, Color("36c8e5", 0.4), 3)
	for car in cars:
		var p: Vector2 = car["p"]
		if not visible_world(p, 45):
			continue
		var dimensions := Vector2(52, 27) if car["horizontal"] else Vector2(27, 52)
		draw_rect(Rect2(p - dimensions * 0.5 + Vector2(4, 5), dimensions), Color("030916", 0.6))
		draw_rect(Rect2(p - dimensions * 0.5, dimensions), car["color"])
		draw_rect(Rect2(p - dimensions * 0.24, dimensions * 0.48), Color("1a2e49"))

func draw_hero() -> void:
	var p := hero
	var a := elapsed * 4.0
	if aura_level > 0:
		draw_arc(p, 100.0 + aura_level * 25.0, 0, TAU, 60, Color("3ceaff", 0.25 + sin(a) * 0.1), 4)
	if dash_time > 0.0:
		for i in range(3):
			draw_circle(p - aim * (20.0 + i * 20.0), 19.0 - i * 3.0, Color("22d9ff", 0.22))
	draw_circle(p + Vector2(0, 17), 22.0, Color("020914", 0.55))
	var suit := Color("e7f5ff") if hero_flash > 0 else Color("203e62")
	draw_circle(p + Vector2(0, 4), 24.0, Color("061327"))
	draw_circle(p + Vector2(0, 4), 20.0, suit)
	draw_circle(p + Vector2(0, -13), 14.0, Color("0c1a30"))
	draw_arc(p + Vector2(0, -13), 12, PI, TAU, 14, CYAN, 3)
	draw_line(p + Vector2(-11, -16), p + Vector2(-3, -16), CYAN, 4)
	draw_line(p + Vector2(3, -16), p + Vector2(11, -16), CYAN, 4)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -1), p + Vector2(10, 7), p + Vector2(0, 17), p + Vector2(-10, 7)]), CYAN)
	draw_circle(p + aim * 26.0, 8.0, CYAN)
	if slash_clock > 0.3:
		draw_arc(p, 79.0, aim.angle() - 0.9, aim.angle() + 0.9, 22, GOLD, 9.0, true)
	if pulse_clock > 4.7:
		draw_arc(p, (5.0 - pulse_clock) * 700.0, 0, TAU, 70, CYAN, 9, true)

func draw_enemy(e: Dictionary) -> void:
	var p: Vector2 = e["p"]
	var palette := [Color("f55c83"), Color("d48b63"), Color("ac76ed")]
	var c: Color = Color.WHITE if e["hit"] > 0 else palette[e["kind"]]
	draw_circle(p + Vector2(4, 9), 24, Color("030915", 0.6))
	draw_circle(p, 21, Color("1d243c"))
	draw_circle(p, 16, c)
	draw_rect(Rect2(p + Vector2(-11, -7), Vector2(22, 7)), Color("162136"))
	draw_circle(p + Vector2(-6, -3), 3, CYAN)
	draw_circle(p + Vector2(6, -3), 3, CYAN)
	draw_rect(Rect2(p + Vector2(-18, -31), Vector2(36, 4)), Color("131a28"))
	draw_rect(Rect2(p + Vector2(-18, -31), Vector2(36.0 * maxf(0.0, e["hp"] / e["max"]), 4)), Color("f87591"))

func draw_boss() -> void:
	var p: Vector2 = boss["p"]
	var colors := [Color("eb627e"), Color("9d7ff4"), Color("ffc074"), Color("58e8bf"), Color("f47cbd")]
	var c: Color = Color.WHITE if boss["hit"] > 0 else colors[boss["kind"]]
	draw_circle(p + Vector2(5, 12), 61, Color("030714", 0.7))
	draw_arc(p, 75 + sin(elapsed * 3) * 4, 0, TAU, 64, Color(c, 0.48), 4, true)
	draw_circle(p, 54, Color("111c35"))
	draw_circle(p, 45, c)
	draw_circle(p, 30, Color("1a2948"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -25), p + Vector2(24, 0), p + Vector2(0, 25), p + Vector2(-24, 0)]), c)
	draw_circle(p, 11, Color.WHITE)
	for i in range(6):
		var a := float(i) * TAU / 6.0 + elapsed * 0.7
		draw_circle(p + Vector2.RIGHT.rotated(a) * 42, 6, Color("0b1931"))

func label_at(s: String, p: Vector2, font_size: int, color: Color = Color.WHITE) -> void:
	draw_string(ui_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func bar(p: Vector2, width: float, fraction: float, c: Color) -> void:
	draw_rect(Rect2(p, Vector2(width, 13)), Color("142239"))
	draw_rect(Rect2(p, Vector2(width * clampf(fraction, 0.0, 1.0), 13)), c)
	draw_rect(Rect2(p, Vector2(width, 13)), Color("5a6b85"), false, 1)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, 106), Color("071326", 0.91))
	label_at("VOLT", Vector2(26, 39), 35, CYAN)
	label_at("NV %d" % level, Vector2(156, 37), 22, GOLD)
	bar(Vector2(26, 52), 280, hp / max_hp, Color("ff6580"))
	bar(Vector2(26, 76), 280, energy / 100.0, CYAN)
	label_at("VIDA", Vector2(317, 64), 14)
	label_at("ENERGIA", Vector2(317, 88), 14)
	label_at("XP", Vector2(462, 36), 18, GOLD)
	bar(Vector2(505, 23), 260, xp / xp_need, GOLD)
	label_at("ABATES %d" % kills, Vector2(795, 37), 20)
	label_at("CHEFOES %02d/20" % boss_index, Vector2(1002, 37), 20, CYAN)
	if not boss.is_empty():
		label_at("%02d  %s" % [boss_index + 1, BOSSES[boss_index]], Vector2(480, 74), 19, Color("ffb1c9"))
		bar(Vector2(710, 65), 460, boss["hp"] / boss["max"], Color("f86b9c"))
	elif boss_index < 20:
		label_at("PROXIMO CHEFAO EM %ds" % maxi(0, ceili(boss_wait)), Vector2(910, 78), 18, GOLD)
	if notice_time > 0:
		var width := minf(800, 280 + last_notice.length() * 11.0)
		draw_rect(Rect2(W * 0.5 - width * 0.5, 115, width, 42), Color("091a31", 0.9))
		label_at(last_notice, Vector2(W * 0.5 - width * 0.5 + 15, 143), 19, CYAN)
	# Virtual joystick
	draw_circle(stick_origin, 94, Color("102e47", 0.55))
	draw_arc(stick_origin, 94, 0, TAU, 48, Color("5b8da4", 0.5), 3)
	draw_circle(stick_current, 40, Color("43eaff", 0.34))
	draw_circle(stick_current, 27, Color("53cfe5", 0.75))
	button_draw(Vector2(1090, 572), 66, "PULSO", pulse_clock <= 0.0, CYAN)
	button_draw(Vector2(963, 620), 55, "ESPADA", slash_clock <= 0.0, GOLD)
	button_draw(Vector2(1190, 659), 48, "DASH", dash_clock <= 0.0, Color("af93ff"))
	label_at("RAIO AUTOMATICO", Vector2(510, 690), 17, CYAN)
	if upgrade_screen:
		draw_rect(Rect2(0, 0, W, H), Color("030a17", 0.9))
		label_at("NOVO NIVEL!  ESCOLHA SUA EVOLUCAO", Vector2(292, 190), 34, GOLD)
		for i in range(3):
			var rect := Rect2(160 + i * 332, 285, 302, 176)
			draw_rect(rect, Color("16324b"))
			draw_rect(rect, CYAN, false, 3)
			label_at(upgrade_choices[(level + i * 2) % upgrade_choices.size()], rect.position + Vector2(15, 90), 20, Color.WHITE)
		label_at("TOQUE EM UMA CARTA PARA CONTINUAR", Vector2(407, 535), 20)
	if won:
		draw_rect(Rect2(0, 0, W, H), Color("061024", 0.93))
		label_at("VOLT: NOVA YORK SALVA!", Vector2(320, 280), 43, CYAN)
		label_at("20 CHEFOES DERROTADOS", Vector2(418, 350), 27, GOLD)
		label_at("TOQUE NA TELA PARA RECOMECAR", Vector2(410, 420), 23)

func button_draw(p: Vector2, r: float, title: String, ready: bool, c: Color) -> void:
	draw_circle(p, r + 5, Color("081426", 0.8))
	draw_circle(p, r, Color(c, 0.55 if ready else 0.15))
	draw_arc(p, r, 0, TAU, 48, c if ready else Color("4c6073"), 4)
	var width := ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	label_at(title, p + Vector2(-width * 0.5, 6), 17)

func choose_upgrade(i: int) -> void:
	var pick := (level + i * 2) % upgrade_choices.size()
	match pick:
		0:
			damage *= 1.25
		1:
			rate = maxf(0.12, rate * 0.83)
		2:
			max_hp += 30
			hp = minf(max_hp, hp + 45)
		3:
			chain_count = mini(5, chain_count + 1)
		4:
			aura_level = mini(6, aura_level + 1)
		5:
			speed *= 1.15
	upgrade_screen = false
	last_notice = "NIVEL %d  /  PODER AUMENTADO" % level
	notice_time = 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if won:
				get_tree().reload_current_scene()
				return
			if upgrade_screen:
				for i in range(3):
					if Rect2(160 + i * 332, 285, 302, 176).has_point(t.position):
						choose_upgrade(i)
					return
			if t.position.x < 430 and t.position.y > 300 and stick_id == -1:
				stick_id = t.index
				stick_origin = t.position
				stick_current = t.position
			elif t.position.distance_to(Vector2(1090, 572)) < 83:
				use_pulse()
			elif t.position.distance_to(Vector2(963, 620)) < 73:
				use_slash()
			elif t.position.distance_to(Vector2(1190, 659)) < 67:
				use_dash()
		else:
			if t.index == stick_id:
				stick_id = -1
				move_axis = Vector2.ZERO
				stick_origin = Vector2(170, 555)
				stick_current = stick_origin
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == stick_id:
			move_axis = ((d.position - stick_origin) / 70.0).limit_length()
			stick_current = stick_origin + move_axis * 68.0
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			use_dash()
		elif event.keycode == KEY_J:
			use_slash()
		elif event.keycode == KEY_K:
			use_pulse()
		elif upgrade_screen and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			choose_upgrade(event.keycode - KEY_1)
