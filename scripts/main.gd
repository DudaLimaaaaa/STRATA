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
	style.bg_color = Color(0.035, 0.08, 0.1, 0.92)
	style.border_color = Color("#45615d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	var hud := VBoxContainer.new()
	hud.position = Vector2(32, 25)
	hud.add_theme_constant_override("separation", 8)
	ui.add_child(hud)
	var logo := Label.new()
	logo.text = "STRATA   /   EXPEDIÇÃO PATAGÔNIA"
	logo.add_theme_font_size_override("font_size", 17)
	logo.add_theme_color_override("font_color", Color("#f0c987"))
	hud.add_child(logo)
	objective_label = Label.new()
	objective_label.text = "Localize o sítio do Amonite Dourado"
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("#e6eee8"))
	hud.add_child(objective_label)
	var keys := Label.new()
	keys.text = "A/D mover   ·   SHIFT correr   ·   ESPAÇO saltar   ·   E interagir   ·   TAB GeoAtlas   ·   ESC pausa"
	keys.position = Vector2(32, 674)
	keys.add_theme_font_size_override("font_size", 13)
	keys.add_theme_color_override("font_color", Color("#b5c8bf"))
	ui.add_child(keys)
	prompt_label = Label.new()
	prompt_label.position = Vector2(540, 595)
	prompt_label.size = Vector2(300, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("#f5d79e"))
	ui.add_child(prompt_label)
	atlas_panel = make_overlay_panel()
	pause_panel = make_overlay_panel()

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
	# Fundo em faixas: atmosfera patagônica de protótipo, sem imagens externas.
	draw_rect(Rect2(0, 0, WORLD_END, 720), Color("#102d39"), true)
	for i in range(9):
		var x := float(i) * 760.0 - 100.0
		var h := 170.0 + float((i * 37) % 90)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 480-h), Vector2(x+190, 270-h), Vector2(x+470, 450-h), Vector2(x+760, 290-h), Vector2(x+760, 570), Vector2(x,570)]), Color("#1b4148"))
	for x in range(70, int(WORLD_END), 480):
		draw_circle(Vector2(x, 98 + (x % 5) * 10), 2.0, Color(0.8,0.83,0.7,0.42))
	# Superfície terrestre e recortes das plataformas.
	for rect in [Rect2(0,570,2200,300), Rect2(2380,570,240,300), Rect2(2700,570,410,300), Rect2(3480,570,470,300), Rect2(3920,570,1530,300)]:
		draw_rect(rect, Color("#7b6852"), true)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 14), Color("#b1976e"), true)
	for rect in [Rect2(1920,452,260,35), Rect2(2180,390,350,35), Rect2(2520,345,430,35), Rect2(2940,390,280,35), Rect2(3190,445,270,35), Rect2(4740,520,350,50)]:
		draw_rect(rect, Color("#897357"), true)
		draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,8),Color("#c2a47a"),true)
	# Marco narrativo da estação.
	draw_rect(Rect2(950, 455, 128, 115), Color("#b7a27e"), true)
	draw_rect(Rect2(935, 445, 158, 20), Color("#dbbe8b"), true)
	draw_rect(Rect2(976, 492, 38, 78), Color("#37545a"), true)
	draw_rect(Rect2(1027, 482, 31, 28), Color("#73908a"), true)
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
	# GeoRelíquia: desenho dourado em espiral dentro da reentrância.
	draw_arc(Vector2(5000, 445), 29, 0, TAU * 1.7, 48, Color("#f0c56f"), 6.0, true)
	draw_arc(Vector2(5000, 445), 14, 0, TAU * 1.45, 40, Color("#f8df9d"), 4.0, true)
	draw_rect(Rect2(4870, 495, 240, 10), Color("#cfad79"), true)
	if message_time > 0.0 and screen == "playing":
		draw_string(ThemeDB.fallback_font, Vector2(player.global_position.x, player.global_position.y - 100), message, HORIZONTAL_ALIGNMENT_CENTER, 500, 17, Color("#f3d79d"))

