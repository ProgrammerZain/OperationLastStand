class_name Player
extends CharacterBody3D

## Configuration
@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var air_control: float = 4.0
@export var jump_velocity: float = 4.8

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = true

func _ready() -> void:
	capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not mouse_captured:
			capture_mouse()
	elif event.is_action_pressed("ui_cancel"):
		release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		# Horizontal rotation around Y axis (body)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertical rotation around X axis (head)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	var wants_jump: bool = _is_jump_pressed()
	if wants_jump and is_on_floor():
		velocity.y = jump_velocity

	# Determine speed (walk or sprint)
	var is_sprinting: bool = _is_sprint_pressed() and is_on_floor()
	var current_speed: float = sprint_speed if is_sprinting else walk_speed

	# Get movement input direction relative to player orientation
	var input_dir: Vector2 = _get_movement_vector()
	var target_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Horizontal acceleration / deceleration
	var accel: float = acceleration if is_on_floor() else air_control
	var target_vel_x: float = target_dir.x * current_speed
	var target_vel_z: float = target_dir.z * current_speed

	if target_dir != Vector3.ZERO:
		velocity.x = lerpf(velocity.x, target_vel_x, accel * delta)
		velocity.z = lerpf(velocity.z, target_vel_z, accel * delta)
	else:
		var decel: float = deceleration if is_on_floor() else air_control
		velocity.x = lerpf(velocity.x, 0.0, decel * delta)
		velocity.z = lerpf(velocity.z, 0.0, decel * delta)

	move_and_slide()

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

# Input helpers with both Action and Physical Key fallbacks
func _get_movement_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0

	# Left / Right
	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0

	# Forward / Back (y negative = forward in 3D)
	if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0

	return Vector2(x, y).normalized()

func _is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)

func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)

