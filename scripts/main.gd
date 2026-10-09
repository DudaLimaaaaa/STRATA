extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const WORLD_END := 5450.0
const GROUND_Y := 570.0

var player
var camera: Camera2D
var ui: CanvasLayer
var prompt_label: Label
var objective_label: Label
var atlas_panel: PanelContainer
var pause_panel: PanelContainer
var overlay: ColorRect
var atlas_hud: PanelContainer
var current_interaction := ""
var screen := "title"
var checkpoint := Vector2(150, GROUND_Y)
var station_found := false
var lookout_found := false
var fossil_found := false
var vale_checkpoint_set := false
var rock_phase := 0.0
var rock_warning := false
var rock_active := true
var hazard_timers := {"valley": -1.0, "low_route": -1.0}
var hazard_done := {"valley": false, "low_route": false}
var message := ""
var message_time := 0.0

var interactables := [
	{"id":"station", "pos":Vector2(1020, GROUND_Y), "radius":90.0},
	{"id":"lookout", "pos":Vector2(2880, 340), "radius":100.0},
	{"id":"fossil", "pos":Vector2(5040, 450), "radius":100.0},
]

func _ready() -> void:
	create_world()
	create_player()
	create_ui()
	show_title()

func create_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.position = checkpoint
	player.fell.connect(respawn)
	add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(0, -260)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_END)
	camera.limit_top = 0
	camera.limit_bottom = 720
	player.add_child(camera)
	camera.make_current()

func create_world() -> void:
	# Um corredor de reencontro conduz à mesma descoberta pelas duas rotas.
	platform(0, GROUND_Y, 2200, 300)
	platform(2380, GROUND_Y, 240, 300)
	platform(2700, GROUND_Y, 410, 300)
	platform(3480, GROUND_Y, 470, 300)
	platform(3920, GROUND_Y, 1530, 300)
	# Rota alta: plataformas longas, mirante opcional e descida suave.
	platform(1920, 452, 260, 35)
	platform(2180, 390, 350, 35)
	platform(2520, 345, 430, 35)
	platform(2940, 390, 280, 35)
	platform(3190, 445, 270, 35)
	# Abrigo e último salto.
	platform(4740, 520, 350, 50)
	# Delimitadores laterais e decoração gerada em _draw.
	queue_redraw()

func platform(x: float, y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + width * 0.5, y + height * 0.5)
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

func create_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, 0.91)
	style.border_color = Color("#d7c9a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(20, 18)
	hud_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(hud_panel)
	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", 7)
	hud_panel.add_child(hud)
	var logo := Label.new()
	logo.text = "▲   OBJETIVO: alcançar a estação"
	logo.add_theme_font_size_override("font_size", 20)
	logo.add_theme_color_override("font_color", Color("#f5e8c8"))
	hud.add_child(logo)
	objective_label = Label.new()
	objective_label.text = "Explore o vale e registre a descoberta"
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.add_theme_color_override("font_color", Color("#dfd8ca"))
	hud.add_child(objective_label)
	var controls := HBoxContainer.new()
	controls.position = Vector2(30, 111)
	controls.add_theme_constant_override("separation", 9)
	ui.add_child(controls)
	_add_control_chip(controls, "◈  Mapa", "TAB")
	_add_control_chip(controls, "✋  Interação", "E")
	_add_control_chip(controls, "⇧  Saltar", "ESPAÇO")
	var map_panel := PanelContainer.new()
	map_panel.position = Vector2(963, 20)
	map_panel.custom_minimum_size = Vector2(290, 102)
	map_panel.add_theme_stylebox_override("panel", _hud_style())
	ui.add_child(map_panel)
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 4)
	map_panel.add_child(map_box)
	var map_title := Label.new()
	map_title.text = "GeoAtlas  /  SETOR AUSTRAL"
	map_title.add_theme_font_size_override("font_size", 13)
	map_title.add_theme_color_override("font_color", Color("#f2e5c8"))
	map_box.add_child(map_title)
	var map_route := Label.new()
	map_route.text = "● ─── ◆ ─── ◇ ─── ◉"
	map_route.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_route.add_theme_font_size_override("font_size", 22)
	map_route.add_theme_color_override("font_color", Color("#f0c56f"))
	map_box.add_child(map_route)
	var map_caption := Label.new()
	map_caption.text = "BASE       ESTAÇÃO       VALE       SÍTIO"
	map_caption.add_theme_font_size_override("font_size", 9)
	map_caption.add_theme_color_override("font_color", Color("#c8c4b8"))
	map_box.add_child(map_caption)
	prompt_label = Label.new()
	prompt_label.position = Vector2(540, 595)
	prompt_label.size = Vector2(300, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("#f5d79e"))
	ui.add_child(prompt_label)
	atlas_panel = make_overlay_panel()
	pause_panel = make_overlay_panel()

func _hud_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, 0.88)
	style.border_color = Color("#e3d7bd")
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _add_control_chip(parent: HBoxContainer, title: String, key: String) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _hud_style())
	parent.add_child(chip)
	var label := Label.new()
	label.text = "%s   [%s]" % [title, key]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#f3eee2"))
	chip.add_child(label)

func make_overlay_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(550, 350)
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.visible = false
	ui.add_child(panel)
	return panel

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.08, 0.1, 0.97)
	style.border_color = Color("#bb8c56")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	return style

func _process(delta: float) -> void:
	if screen == "playing":
		update_hazards(delta)
		if not vale_checkpoint_set and player.global_position.x >= 3980.0:
			checkpoint = Vector2(3980, GROUND_Y)
			vale_checkpoint_set = true
			show_message("Ponto seguro alcançado.")
		update_interaction()
		if Input.is_action_just_pressed("toggle_atlas"):
			toggle_atlas()
		if Input.is_action_just_pressed("pause"):
			toggle_pause()
	elif screen == "atlas" and Input.is_action_just_pressed("toggle_atlas"):
		toggle_atlas()
	elif screen == "paused" and Input.is_action_just_pressed("pause"):
		toggle_pause()
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message = ""
	queue_redraw()

func update_interaction() -> void:
	current_interaction = ""
	for item in interactables:
		if item.id == "lookout" and lookout_found:
			continue
		if item.id == "station" and station_found:
			continue
		if item.id == "fossil" and fossil_found:
			continue
		if player.global_position.distance_to(item.pos) <= item.radius:
			current_interaction = item.id
			break
	prompt_label.text = "E  ·  interagir" if current_interaction != "" else ""
	if current_interaction != "" and Input.is_action_just_pressed("interact"):
		interact(current_interaction)

func interact(id: String) -> void:
	match id:
		"station":
			station_found = true
			checkpoint = Vector2(1110, GROUND_Y)
			objective_label.text = "Registro da estação recuperado · siga pelo vale"
			show_message("Último registro: o sítio fica além do vale.")
		"lookout":
			lookout_found = true
			show_message("Mirante registrado no GeoAtlas.")
		"fossil":
			fossil_found = true
			objective_label.text = "Amonite Dourado registrado"
			show_end()

func show_message(text: String) -> void:
	message = text
	message_time = 3.5

func update_hazards(delta: float) -> void:
	var x: float = player.global_position.x
	var zones := [{"id":"valley", "x":1670.0, "start":1390.0, "end":1770.0}, {"id":"low_route", "x":3000.0, "start":2820.0, "end":3120.0}]
	rock_warning = false
	for zone in zones:
		var id: String = zone.id
		if bool(hazard_done[id]):
			continue
		if id == "low_route" and player.global_position.y < 500.0:
			continue
		if float(hazard_timers[id]) < 0.0 and x >= float(zone.start) and x <= float(zone.end):
			hazard_timers[id] = 1.8
			message = "Pedras soltas à frente — observe o vale"
			message_time = 2.8
		if float(hazard_timers[id]) >= 0.0:
			hazard_timers[id] = float(hazard_timers[id]) - delta
			rock_warning = rock_warning or float(hazard_timers[id]) > 0.0
			if float(hazard_timers[id]) <= 0.0:
				hazard_timers[id] = -1.0
				hazard_done[id] = true
				if absf(x - float(zone.x)) < 52.0 and player.global_position.y > 500.0:
					respawn()

func respawn() -> void:
	player.global_position = checkpoint
	player.velocity = Vector2.ZERO
	hazard_timers = {"valley": -1.0, "low_route": -1.0}
	rock_warning = false
	show_message("De volta ao último ponto seguro.")

func toggle_atlas() -> void:
	if screen == "playing":
		screen = "atlas"
		player.disabled = true
		atlas_panel.visible = true
		_fill_atlas()
	elif screen == "atlas":
		atlas_panel.visible = false
		screen = "playing"
		player.disabled = false

func _fill_atlas() -> void:
	for child in atlas_panel.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	atlas_panel.add_child(box)
	var title := Label.new()
	title.text = "GEOATLAS  /  PATAGÔNIA AUSTRAL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0c987"))
	box.add_child(title)
	var map := Label.new()
	map.text = "INÍCIO  ───── ESTAÇÃO  ───── VALE  ───── SÍTIO\n   ◉                    %s                    %s                   %s" % ["●" if station_found else "○", "●" if lookout_found else "○", "●" if fossil_found else "○"]
	map.add_theme_font_size_override("font_size", 18)
	map.add_theme_color_override("font_color", Color("#c8d8cc"))
	box.add_child(map)
	var note := Label.new()
	note.text = "Setor fictício inspirado nas paisagens sedimentares do sudoeste de Santa Cruz.\nOs pontos do percurso e o Amonite Dourado são elementos ficcionais."
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("#b5c8bf"))
	box.add_child(note)
	var close := Button.new()
	close.text = "Voltar à expedição  ·  TAB"
	close.pressed.connect(toggle_atlas)
	box.add_child(close)

func toggle_pause() -> void:
	if screen == "playing":
		screen = "paused"
		player.disabled = true
		_fill_pause()
		pause_panel.visible = true
	elif screen == "paused":
		pause_panel.visible = false
		screen = "playing"
		player.disabled = false

func _fill_pause() -> void:
	for child in pause_panel.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)
	var title := Label.new()
	title.text = "EXPEDIÇÃO EM PAUSA"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Continuar"
	resume.pressed.connect(toggle_pause)
	box.add_child(resume)
	var restart := Button.new()
	restart.text = "Reiniciar fase"
	restart.pressed.connect(restart_level)
	box.add_child(restart)
	var menu := Button.new()
	menu.text = "Voltar ao menu"
	menu.pressed.connect(show_title)
	box.add_child(menu)

func restart_level() -> void:
	station_found = false
	lookout_found = false
	fossil_found = false
	vale_checkpoint_set = false
	checkpoint = Vector2(150, GROUND_Y)
	hazard_timers = {"valley": -1.0, "low_route": -1.0}
	hazard_done = {"valley": false, "low_route": false}
	rock_warning = false
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.disabled = false
	pause_panel.visible = false
	screen = "playing"
	objective_label.text = "Localize o sítio do Amonite Dourado"

func show_title() -> void:
	screen = "title"
	player.disabled = true
	_build_center_panel(atlas_panel, "STRATA", "A primeira descoberta  /  Demo 01", "Uma expedição, um vale e um registro perdido.", "Iniciar expedição", start_game)
	atlas_panel.visible = true

func start_game() -> void:
	atlas_panel.visible = false
	station_found = false
	lookout_found = false
	fossil_found = false
	vale_checkpoint_set = false
	checkpoint = Vector2(150, GROUND_Y)
	hazard_timers = {"valley": -1.0, "low_route": -1.0}
	hazard_done = {"valley": false, "low_route": false}
	screen = "playing"
	player.disabled = false
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	show_message("Localize o sítio do Amonite Dourado.")

func show_end() -> void:
	screen = "end"
	player.disabled = true
	_build_center_panel(atlas_panel, "REGISTRO CONCLUÍDO", "Amonite Dourado", "A descoberta foi documentada e preservada no GeoAtlas.", "Jogar novamente", restart_from_end)
	atlas_panel.visible = true

func restart_from_end() -> void:
	atlas_panel.visible = false
	restart_level()

func _build_center_panel(panel: PanelContainer, heading: String, subheading: String, body: String, button_text: String, callback: Callable) -> void:
	for child in panel.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	panel.add_child(box)
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 28)
	h.add_theme_color_override("font_color", Color("#f0c987"))
	box.add_child(h)
	var s := Label.new()
	s.text = subheading
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 18)
	box.add_child(s)
	var b := Label.new()
	b.text = body
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(callback)
	box.add_child(button)

func _draw() -> void:
	# Céu azul patagônico, cadeias de montanhas nevadas e vale glacial em planos.
	draw_rect(Rect2(0, 0, WORLD_END, 720), Color("#55a6df"), true)
	for i in range(8):
		var x := float(i) * 780.0 - 120.0
		var peak := 160.0 + float((i * 41) % 110)
		var ridge := PackedVector2Array([Vector2(x, 420), Vector2(x+170, peak+90), Vector2(x+240, peak), Vector2(x+310, peak+86), Vector2(x+490, 410), Vector2(x+700, peak+50), Vector2(x+780, 420), Vector2(x+780, 570), Vector2(x,570)])
		draw_colored_polygon(ridge, Color("#dce9ef"))
		draw_colored_polygon(PackedVector2Array([Vector2(x+170, peak+90),Vector2(x+240,peak),Vector2(x+310,peak+86),Vector2(x+270,peak+64),Vector2(x+242,peak+82),Vector2(x+215,peak+65)]), Color("#f7f5ec"))
		draw_colored_polygon(PackedVector2Array([Vector2(x,420),Vector2(x+170,peak+90),Vector2(x+100,430),Vector2(x+300,570),Vector2(x,570)]), Color("#84a9b8"))
	# Nuvens leves e serras distantes para dar escala à travessia.
	for i in range(24):
		var cx := float(i) * 260.0 + 55.0
		var cy := float(72 + (i * 29) % 120)
		draw_circle(Vector2(cx,cy), 21, Color(0.94,0.97,1.0,0.18))
		draw_circle(Vector2(cx+23,cy+4), 15, Color(0.94,0.97,1.0,0.16))
	# Lago glacial turquesa entre os paredões.
	draw_colored_polygon(PackedVector2Array([Vector2(0,525),Vector2(620,492),Vector2(1450,515),Vector2(2050,485),Vector2(2600,530),Vector2(3320,490),Vector2(4100,520),Vector2(5450,475),Vector2(5450,590),Vector2(0,590)]), Color("#278dad"))
	for i in range(34):
		var wx := float(i) * 170.0 + 30.0
		var wy := 520.0 + float((i * 17) % 47)
		draw_line(Vector2(wx,wy),Vector2(wx+54,wy-3),Color(0.72,0.92,0.95,0.46),2.0,true)
	# Parede rochosa irregular, com faces quentes e neve acumulada nas bordas.
	for rect in [Rect2(0,570,2200,300), Rect2(2380,570,240,300), Rect2(2700,570,410,300), Rect2(3480,570,470,300), Rect2(3920,570,1530,300)]:
		draw_rect(rect, Color("#52443c"), true)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 9), Color("#b8a487"), true)
		for i in range(int(rect.size.x / 78.0)):
			var rx: float = rect.position.x + float(i) * 78.0 + float((i * 23) % 27)
			var ry := 592.0 + float((i * 31) % 138)
			draw_colored_polygon(PackedVector2Array([Vector2(rx,ry),Vector2(rx+25,ry-17),Vector2(rx+52,ry+3),Vector2(rx+39,ry+28),Vector2(rx+9,ry+32)]), Color("#705a4b"))
			draw_line(Vector2(rx+4,ry+2),Vector2(rx+24,ry-12),Color("#a48567",0.65),2.0,true)
	for rect in [Rect2(1920,452,260,35), Rect2(2180,390,350,35), Rect2(2520,345,430,35), Rect2(2940,390,280,35), Rect2(3190,445,270,35), Rect2(4740,520,350,50)]:
		draw_rect(rect, Color("#665043"), true)
		draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,7),Color("#d1bd9b"),true)
	# Estação de pesquisa em madeira e metal no penhasco.
	draw_rect(Rect2(950, 430, 155, 140), Color("#7d4435"), true)
	draw_rect(Rect2(938, 420, 180, 18), Color("#d38e5c"), true)
	for wx in [965.0, 1012.0, 1060.0]:
		draw_rect(Rect2(wx,450,29,31),Color("#90c5d0"),true)
		draw_line(Vector2(wx+14,450),Vector2(wx+14,481),Color("#eee5d0"),3.0,true)
		draw_rect(Rect2(wx,450,29,3),Color("#eee5d0"),true)
	draw_rect(Rect2(994, 493, 43, 77), Color("#3c3534"), true)
	# Pernas e vigas sobre a encosta, com bandeirola de vento.
	for bx in [960.0, 1093.0]:
		draw_line(Vector2(bx,535),Vector2(bx-18,570),Color("#493c35"),8.0,true)
		draw_line(Vector2(bx+22,535),Vector2(bx+40,570),Color("#493c35"),8.0,true)
	draw_line(Vector2(1125,410),Vector2(1125,330),Color("#54483e"),5.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(1126,332),Vector2(1190,344),Vector2(1128,359)]),Color("#f5eee1"))
	draw_colored_polygon(PackedVector2Array([Vector2(1126,332),Vector2(1157,338),Vector2(1130,345)]),Color("#de754b"))
	# Rota alta: corrimão/mirante e fita de segurança nos setores de queda.
	draw_rect(Rect2(2670, 300, 4, 45), Color("#dfbd82"), true)
	draw_rect(Rect2(2668, 300, 108, 3), Color("#dfbd82"), true)
	if rock_warning:
		var warning_x := 3000.0 if float(hazard_timers["low_route"]) > 0.0 else 1670.0
		draw_circle(Vector2(warning_x, 515), 38, Color(0.96,0.59,0.28,0.24))
		draw_string(ThemeDB.fallback_font, Vector2(warning_x - 9.0, 468), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#f4cb83"))
		var remaining: float = maxf(0.0, float(hazard_timers["low_route"] if warning_x == 3000.0 else hazard_timers["valley"]))
		var rock_y := 260.0 + (1.8 - remaining) * 130.0
		draw_rect(Rect2(warning_x - 17.0, rock_y, 34, 30), Color("#b18d66"), true)
	# Reentrância de arenito iluminada, com o fóssil em ouro.
	draw_colored_polygon(PackedVector2Array([Vector2(4840,520),Vector2(4880,440),Vector2(4950,395),Vector2(5030,405),Vector2(5100,465),Vector2(5115,520)]),Color("#a26535"))
	draw_circle(Vector2(4990,460),49,Color("#382d28"))
	draw_circle(Vector2(4990,460),38,Color("#a76420"))
	draw_arc(Vector2(4990,460), 29, 0, TAU * 1.7, 48, Color("#ffcf61"), 7.0, true)
	draw_arc(Vector2(4990,460), 14, 0, TAU * 1.45, 40, Color("#ffe6a0"), 4.0, true)
	draw_rect(Rect2(4870, 495, 240, 10), Color("#cfad79"), true)
	if message_time > 0.0 and screen == "playing":
		draw_string(ThemeDB.fallback_font, Vector2(player.global_position.x, player.global_position.y - 100), message, HORIZONTAL_ALIGNMENT_CENTER, 500, 17, Color("#f3d79d"))

