class_name Player
extends CharacterBody3D

signal health_changed(current: float, max_val: float)
signal player_died()

## Configuration
@export_group("Stats")
@export var max_health: float = 100.0

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
@onready var weapon_mount: Node3D = $Head/WeaponMount
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# State
var current_health: float = 100.0
var is_alive: bool = true
var current_weapon: WeaponBase = null
var hud: GameHUD = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = false
var bob_phase: float = 0.0
var default_camera_y: float = 0.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	default_camera_y = camera.position.y
	capture_mouse()
	
	# Cache HUD reference
	hud = get_tree().get_first_node_in_group("hud") as GameHUD
	if hud:
		hud.update_health(current_health, max_health)
	
	# Detect and initialize equipped weapon
	if weapon_mount and weapon_mount.get_child_count() > 0:
		var initial_weapon: WeaponBase = weapon_mount.get_child(0) as WeaponBase
		if initial_weapon:
			equip_weapon(initial_weapon)

func equip_weapon(weapon: WeaponBase) -> void:
	current_weapon = weapon
	if current_weapon:
		if not current_weapon.ammo_changed.is_connected(_on_ammo_changed):
			current_weapon.ammo_changed.connect(_on_ammo_changed)
		if not current_weapon.reload_started.is_connected(_on_reload_started):
			current_weapon.reload_started.connect(_on_reload_started)
		if not current_weapon.reload_finished.is_connected(_on_reload_finished):
			current_weapon.reload_finished.connect(_on_reload_finished)
		_on_ammo_changed(current_weapon.current_ammo, current_weapon.reserve_ammo)

func _unhandled_input(event: InputEvent) -> void:
	if not is_alive or GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Mouse look
	if mouse_captured and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity_h)
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
			return
		elif current_weapon:
			current_weapon.fire()
			return

	# Weapon controls (only when mouse is captured)
	if mouse_captured and current_weapon:
		if event.is_action_pressed("fire"):
			current_weapon.fire()
		elif event.is_action_pressed("reload") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_R):
			current_weapon.reload()

func _physics_process(delta: float) -> void:
	if not is_alive or GameManager.current_state != GameManager.GameState.PLAYING:
		return

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
	var target_fov: float = sprint_fov if (is_sprinting and velocity.length() > walk_speed) else base_fov
	camera.fov = lerpf(camera.fov, target_fov, fov_change_speed * delta)

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

func take_damage(amount: float) -> void:
	if not is_alive:
		return

	current_health = maxf(0.0, current_health - amount)
	print("[PLAYER DAMAGED] Took %s damage! HP: %s/%s" % [amount, current_health, max_health])
	emit_signal("health_changed", current_health, max_health)
	
	if not hud:
		hud = get_tree().get_first_node_in_group("hud") as GameHUD
	if hud:
		hud.update_health(current_health, max_health)
		hud.trigger_damage_flash()

	if current_health <= 0.0:
		_die()

func _die() -> void:
	is_alive = false
	print("[PLAYER K.I.A.] Player eliminated.")
	emit_signal("player_died")
	GameManager.on_player_died()

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

# UI / Weapon Callbacks
func _on_ammo_changed(current: int, reserve: int) -> void:
	if not hud:
		hud = get_tree().get_first_node_in_group("hud") as GameHUD
	if hud:
		hud.update_ammo(current, reserve)
		if not (current_weapon and current_weapon.is_reloading):
			if current == 0:
				hud.set_reload_status("PRESS [R] TO RELOAD", Color(1.0, 0.35, 0.35))
			else:
				hud.set_reload_status("")

func _on_reload_started(_duration: float) -> void:
	if not hud:
		hud = get_tree().get_first_node_in_group("hud") as GameHUD
	if hud:
		hud.set_reload_status("RELOADING...", Color(1.0, 0.85, 0.2))

func _on_reload_finished() -> void:
	if not hud:
		hud = get_tree().get_first_node_in_group("hud") as GameHUD
	if hud:
		hud.set_reload_status("")

# Input helpers
func _get_input_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0

	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0

	if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0

	return Vector2(x, y).normalized()

func _is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE)

func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
