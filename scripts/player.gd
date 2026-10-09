extends CharacterBody2D
class_name StrataPlayer

signal fell

const WALK_SPEED := 260.0
const RUN_SPEED := 390.0
const ACCELERATION := 1700.0
const FRICTION := 2100.0
const JUMP_VELOCITY := -610.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_left := 0.0
var jump_buffer_left := 0.0
var disabled := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 17.0
	capsule.height = 54.0
	shape.shape = capsule
	shape.position.y = -27.0
	add_child(shape)

func _physics_process(delta: float) -> void:
	if disabled:
		velocity = Vector2.ZERO
		return
	if is_on_floor():
		coyote_left = COYOTE_TIME
	else:
		coyote_left = maxf(0.0, coyote_left - delta)
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = JUMP_BUFFER
	else:
		jump_buffer_left = maxf(0.0, jump_buffer_left - delta)
	if jump_buffer_left > 0.0 and coyote_left > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_left = 0.0
		coyote_left = 0.0
	if Input.is_action_just_released("jump") and velocity.y < -180.0:
		velocity.y *= 0.55
	var direction := Input.get_axis("move_left", "move_right")
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
	if global_position.y > 900.0:
		fell.emit()

func _draw() -> void:
	# Exploradora de campo com mochila, casaco ocre e detalhes de equipamento.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	draw_rect(Rect2(-16, -28, 12, 24), Color("#38464a"), true)
	draw_rect(Rect2(4, -28, 12, 24), Color("#38464a"), true)
	draw_line(Vector2(-12,-5),Vector2(-17,0),Color("#252f31"),6.0,true)
	draw_line(Vector2(10,-5),Vector2(16,0),Color("#252f31"),6.0,true)
	draw_rect(Rect2(-18,-49,36,29),Color("#c27a35"),true)
	draw_rect(Rect2(-24,-47,12,27),Color("#465355"),true)
	draw_rect(Rect2(11,-45,12,23),Color("#596263"),true)
	draw_rect(Rect2(-9,-45,5,22),Color("#f0c16d"),true)
	draw_line(Vector2(-17,-38),Vector2(18,-38),Color("#f0c16d"),3.0,true)
	draw_circle(Vector2(0,-58),11,Color("#d99b6d"))
	draw_rect(Rect2(-12,-66,24,6),Color("#3a302b"),true)
	draw_colored_polygon(PackedVector2Array([Vector2(-15,-64),Vector2(0,-72),Vector2(16,-64)]),Color("#4a3930"))
	draw_line(Vector2(17,-34),Vector2(27,-10),Color("#d6d1c4"),3.0,true)
	draw_circle(Vector2(0,-58),1.8,Color("#332b28"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

