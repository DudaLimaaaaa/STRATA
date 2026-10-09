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
	# Expedicionária temporária em silhueta; substituível por sprite.
	draw_circle(Vector2(0, -40), 12, Color("#e4b184"))
	draw_rect(Rect2(-13, -29, 26, 31), Color("#d5e1d7"), true)
	draw_rect(Rect2(-13, -8, 10, 20), Color("#334a50"), true)
	draw_rect(Rect2(3, -8, 10, 20), Color("#334a50"), true)
	draw_rect(Rect2(-19, -29, 38, 5), Color("#d99052"), true)
	draw_circle(Vector2(0, -42), 2.2, Color("#102c37"))

