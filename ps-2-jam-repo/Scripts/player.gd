
extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D

const GRAVITY := 20.0

var camera_pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(-85), deg_to_rad(85))

		camera.rotation.x = camera_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Movement input
	var input_dir := Input.get_vector(
	"move_left",
	"move_right",
	"move_forward",
	"move_backward"
	)

	# Camera-relative movement
	var direction := (transform.basis * Vector3(
		input_dir.x, 0, input_dir.y
	)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()
