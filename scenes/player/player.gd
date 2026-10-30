class_name Player
extends CharacterBody3D

## Configuration
@export_group("Movement Speeds")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.8
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var air_control: float = 3.5

@export_group("Mouse & Camera")
@export var mouse_sensitivity_h: float = 0.0022
@export var mouse_sensitivity_v: float = 0.0022
@export var min_pitch_deg: float = -88.0
@export var max_pitch_deg: float = 88.0
@export var base_fov: float = 75.0
@export var sprint_fov: float = 83.0
@export var fov_change_speed: float = 8.0

@export_group("Head Bob")
@export var bob_enabled: bool = true
@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.04

# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Internal state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = false
var bob_phase: float = 0.0
var default_camera_y: float = 0.0

func _ready() -> void:
	default_camera_y = camera.position.y
	capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if mouse_captured and event is InputEventMouseMotion:
		# Rotate body horizontally (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity_h)
		# Rotate head vertically (pitch)
		head.rotate_x(-event.relative.y * mouse_sensitivity_v)
		head.rotation.x = clampf(
			head.rotation.x,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		return

	# Mouse capture on window click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not mouse_captured:
			capture_mouse()
	# Mouse release on Escape / ui_cancel
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
		release_mouse()

func _physics_process(delta: float) -> void:
	# Gravity & terminal velocity
	if not is_on_floor():
		velocity.y -= gravity * delta
		velocity.y = maxf(velocity.y, -35.0)

	# Jump
	if _is_jump_pressed() and is_on_floor():
		velocity.y = jump_velocity

	# Movement calculation
	var is_sprinting: bool = _is_sprint_pressed() and is_on_floor() and velocity.length() > 0.5
	var target_speed: float = sprint_speed if is_sprinting else walk_speed

	var input_vec: Vector2 = _get_input_vector()
	var target_dir: Vector3 = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var accel: float = acceleration if is_on_floor() else air_control
	var decel: float = deceleration if is_on_floor() else air_control

	if target_dir != Vector3.ZERO:
		velocity.x = lerpf(velocity.x, target_dir.x * target_speed, accel * delta)
		velocity.z = lerpf(velocity.z, target_dir.z * target_speed, accel * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, decel * delta)
		velocity.z = lerpf(velocity.z, 0.0, decel * delta)

	move_and_slide()

	# Visual camera feel: Dynamic FOV & Head Bob
	_process_camera_effects(delta, is_sprinting)

func _process_camera_effects(delta: float, is_sprinting: bool) -> void:
	# 1. Dynamic FOV
	var target_fov: float = sprint_fov if (is_sprinting and velocity.length() > walk_speed) else base_fov
	camera.fov = lerpf(camera.fov, target_fov, fov_change_speed * delta)

	# 2. Head Bobbing
	if bob_enabled:
		var horizontal_vel: Vector2 = Vector2(velocity.x, velocity.z)
		if is_on_floor() and horizontal_vel.length() > 0.2:
			var speed_factor: float = 1.3 if is_sprinting else 1.0
			bob_phase += delta * bob_frequency * speed_factor * (horizontal_vel.length() / walk_speed)
			camera.position.y = default_camera_y + sin(bob_phase * TAU) * bob_amplitude
			camera.position.x = cos(bob_phase * PI) * (bob_amplitude * 0.5)
		else:
			bob_phase = 0.0
			camera.position.y = lerpf(camera.position.y, default_camera_y, 10.0 * delta)
			camera.position.x = lerpf(camera.position.x, 0.0, 10.0 * delta)

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

# Input helpers with both Action and Physical Key fallbacks
func _get_input_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0

	# Left / Right
	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0

	# Forward / Back (negative y is forward in 3D)
	if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0

	return Vector2(x, y).normalized()

func _is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)

func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
