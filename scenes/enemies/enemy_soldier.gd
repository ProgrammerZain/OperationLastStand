class_name EnemySoldier
extends CharacterBody3D

signal enemy_died(enemy: EnemySoldier)

enum State {
	PATROL,
	CHASE,
	ATTACK,
	DEAD
}

@export_group("Stats")
@export var max_health: float = 60.0
@export var patrol_speed: float = 2.4
@export var chase_speed: float = 4.2
@export var detection_radius: float = 16.0
@export var attack_range: float = 9.0
@export var stop_distance: float = 6.5
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 12.0
@export var patrol_radius: float = 7.0

# Node References
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var torso_mesh: MeshInstance3D = $Visuals/Torso
@onready var visor_mesh: MeshInstance3D = $Visuals/Head/Visor
@onready var leg_l: MeshInstance3D = $Visuals/LegL
@onready var leg_r: MeshInstance3D = $Visuals/LegR
@onready var muzzle_flash: Node3D = $Visuals/Weapon/MuzzleFlash
@onready var audio_shoot: AudioStreamPlayer3D = $AudioShoot
@onready var audio_hurt: AudioStreamPlayer3D = $AudioHurt
@onready var audio_alert: AudioStreamPlayer3D = $AudioAlert

# Runtime State
var current_state: State = State.PATROL
var current_health: float = 60.0
var target_player: Player = null
var spawn_anchor: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var attack_timer: float = 0.0
var patrol_wait_timer: float = 0.0
var path_update_timer: float = 0.0
var flash_timer: SceneTreeTimer = null
var default_torso_mat: Material
var active_visor_mat: StandardMaterial3D = null

# Polish & Animation State
var walk_time: float = 0.0
var flinch_rot: Vector3 = Vector3.ZERO
var flinch_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_health = max_health
	spawn_anchor = global_position
	
	if torso_mesh:
		default_torso_mat = torso_mesh.get_active_material(0)
	if visor_mesh:
		var base_mat = visor_mesh.get_active_material(0)
		if base_mat:
			active_visor_mat = base_mat.duplicate() as StandardMaterial3D
			visor_mesh.material_override = active_visor_mat
	if muzzle_flash:
		muzzle_flash.visible = false

	# Wait for navigation server to initialize before setting initial patrol
	await get_tree().physics_frame
	_pick_new_patrol_destination()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Cache player reference if needed
	if not is_instance_valid(target_player):
		target_player = _find_player()

	# Tick timers
	if attack_timer > 0.0:
		attack_timer -= delta
	if path_update_timer > 0.0:
		path_update_timer -= delta

	# State Machine execution
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()
	_animate_visuals(delta)

# ================= STATE: PATROL =================
func _process_patrol(delta: float) -> void:
	# Check for player detection
	if is_instance_valid(target_player):
		var dist_to_player: float = global_position.distance_to(target_player.global_position)
		if dist_to_player <= detection_radius and has_line_of_sight_to(target_player):
			_switch_to_chase()
			return

	# Handle patrol movement
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			_pick_new_patrol_destination()
	else:
		_move_along_nav_path(patrol_speed)

func _pick_new_patrol_destination() -> void:
	patrol_wait_timer = randf_range(1.5, 3.0)
	var random_offset: Vector3 = Vector3(
		randf_range(-patrol_radius, patrol_radius),
		0,
		randf_range(-patrol_radius, patrol_radius)
	)
	var dest: Vector3 = spawn_anchor + random_offset
	nav_agent.target_position = dest

# ================= STATE: CHASE =================
func _process_chase(_delta: float) -> void:
	if not is_instance_valid(target_player):
		current_state = State.PATROL
		return

	var dist_to_player: float = global_position.distance_to(target_player.global_position)
	var has_los: bool = has_line_of_sight_to(target_player)

	# Transition to attack when close enough and has line of sight
	if dist_to_player <= stop_distance and has_los:
		current_state = State.ATTACK
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Update navigation path periodically towards player
	if path_update_timer <= 0.0:
		path_update_timer = 0.15
		nav_agent.target_position = target_player.global_position

	_move_along_nav_path(chase_speed)

func _switch_to_chase() -> void:
	current_state = State.CHASE
	if audio_alert:
		audio_alert.play()
	if is_instance_valid(target_player):
		nav_agent.target_position = target_player.global_position

# ================= STATE: ATTACK =================
func _process_attack(_delta: float) -> void:
	if not is_instance_valid(target_player):
		current_state = State.PATROL
		return

	var dist_to_player: float = global_position.distance_to(target_player.global_position)
	var has_los: bool = has_line_of_sight_to(target_player)

	# If player retreats or breaks line of sight, resume chase
	if dist_to_player > attack_range or not has_los:
		current_state = State.CHASE
		return

	# Stop and face player directly
	velocity.x = 0.0
	velocity.z = 0.0
	_look_at_horizontal(target_player.global_position)

	# Shoot when attack cooldown is ready
	if attack_timer <= 0.0:
		_perform_attack()

func _perform_attack() -> void:
	attack_timer = attack_cooldown
	
	# Visual muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		flash_timer = get_tree().create_timer(0.06)
		flash_timer.timeout.connect(func(): if muzzle_flash: muzzle_flash.visible = false)

	# Sound
	if audio_shoot:
		audio_shoot.pitch_scale = randf_range(0.9, 1.1)
		audio_shoot.play()

	# Raycast attack towards player
	if is_instance_valid(target_player):
		var eye_pos: Vector3 = global_position + Vector3(0, 1.5, 0)
		var player_chest: Vector3 = target_player.global_position + Vector3(0, 1.1, 0)
		var dir_to_player: Vector3 = (player_chest - eye_pos).normalized()
		
		# Slight spread for fair gameplay
		var spread_dir: Vector3 = (dir_to_player + Vector3(
			randf_range(-0.01, 0.01),
			randf_range(-0.01, 0.01),
			randf_range(-0.01, 0.01)
		)).normalized()
		
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(eye_pos, eye_pos + spread_dir * 40.0)
		query.collision_mask = 1 | 2  # World (1) and Player (2)
		query.exclude = [self]
		
		var result: Dictionary = space_state.intersect_ray(query)
		if result and not result.is_empty():
			var collider = result.get("collider")
			if collider:
				if collider.has_method("take_damage"):
					collider.take_damage(attack_damage)
				elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
					collider.get_parent().take_damage(attack_damage)

# ================= HELPER & COMBAT METHODS =================
func _move_along_nav_path(speed: float) -> void:
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var move_dir: Vector3 = (next_pos - global_position)
	move_dir.y = 0.0
	move_dir = move_dir.normalized()

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if move_dir.length() > 0.05:
		_look_at_horizontal(global_position + move_dir)

func _look_at_horizontal(target_point: Vector3) -> void:
	var look_target: Vector3 = Vector3(target_point.x, global_position.y, target_point.z)
	if not global_position.is_equal_approx(look_target):
		look_at(look_target, Vector3.UP)

func has_line_of_sight_to(target_node: Node3D) -> bool:
	if not is_instance_valid(target_node):
		return false
	var eye_pos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var target_eye: Vector3 = target_node.global_position + Vector3(0, 1.5, 0)
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(eye_pos, target_eye)
	query.collision_mask = 1 # Only world geometry blocks LOS
	query.exclude = [self, target_node]
	
	var result: Dictionary = space_state.intersect_ray(query)
	# If no world obstacle intersects, LOS is clear
	return result.is_empty()

func _animate_visuals(delta: float) -> void:
	# Flinch recovery
	flinch_rot = flinch_rot.lerp(Vector3.ZERO, 10.0 * delta)
	flinch_pos = flinch_pos.lerp(Vector3.ZERO, 10.0 * delta)
	visuals.rotation = flinch_rot
	visuals.position = flinch_pos

	# Procedural walk animation
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1 and is_on_floor():
		var cycle_speed: float = 10.0 if current_state == State.CHASE else 6.0
		walk_time += delta * cycle_speed
		if leg_l:
			leg_l.rotation.x = sin(walk_time) * deg_to_rad(28.0)
		if leg_r:
			leg_r.rotation.x = -sin(walk_time) * deg_to_rad(28.0)
		if torso_mesh:
			torso_mesh.position.y = 1.05 + abs(sin(walk_time)) * 0.03
	else:
		walk_time = 0.0
		if leg_l:
			leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 10.0 * delta)
		if leg_r:
			leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 10.0 * delta)
		if torso_mesh:
			torso_mesh.position.y = lerpf(torso_mesh.position.y, 1.05, 10.0 * delta)

	# Visor emission pulse during alert states
	if visor_mesh and active_visor_mat:
		if current_state == State.CHASE or current_state == State.ATTACK:
			var pulse: float = 1.2 + 0.8 * sin(Time.get_ticks_msec() * 0.009)
			active_visor_mat.emission_energy_multiplier = pulse
		else:
			active_visor_mat.emission_energy_multiplier = 0.8

func take_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	print("[ENEMY HIT] Took %s damage! HP remaining: %s/%s" % [amount, current_health, max_health])

	# Alert and chase on taking damage if currently in patrol
	if current_state == State.PATROL:
		_switch_to_chase()

	# Audio feedback
	if audio_hurt:
		audio_hurt.pitch_scale = randf_range(0.95, 1.1)
		audio_hurt.play()

	# Visual damage flash & flinch stagger
	_flash_red()
	flinch_rot = Vector3(
		randf_range(-0.20, -0.08),
		randf_range(-0.12, 0.12),
		randf_range(-0.16, 0.16)
	)
	flinch_pos = Vector3(0.0, 0.0, 0.08)

	if current_health <= 0.0:
		die()

func _flash_red() -> void:
	if torso_mesh:
		var flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(0.9, 0.2, 0.2)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(0.9, 0.2, 0.2)
		flash_mat.emission_energy_multiplier = 1.5
		torso_mesh.material_override = flash_mat
		
		get_tree().create_timer(0.08).timeout.connect(func():
			if torso_mesh:
				torso_mesh.material_override = null
		)

func die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	
	# Turn off glowing visor
	if visor_mesh:
		var dead_visor = StandardMaterial3D.new()
		dead_visor.albedo_color = Color(0.1, 0.1, 0.1)
		dead_visor.emission_enabled = false
		visor_mesh.material_override = dead_visor

	# Collapse backward onto floor
	if visuals:
		visuals.rotation = Vector3(-deg_to_rad(85.0), 0.0, 0.0)
		visuals.position = Vector3(0.0, -0.7, 0.0)

	print("[ENEMY KILLED] Enemy eliminated!")
	enemy_died.emit(self)

func _find_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
