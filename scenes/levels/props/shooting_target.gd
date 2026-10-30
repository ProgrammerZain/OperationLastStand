class_name ShootingTarget
extends StaticBody3D

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_down: bool = false

@onready var target_pivot: Node3D = $Pivot
@onready var target_mesh: MeshInstance3D = $Pivot/TargetFace
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio

var default_mat: Material
var flash_mat: StandardMaterial3D

func _ready() -> void:
	current_health = max_health
	if target_mesh:
		default_mat = target_mesh.get_active_material(0)
	
	# Create bright flash material
	flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.95, 0.4)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.9, 0.3)
	flash_mat.emission_energy_multiplier = 2.0

func _process(delta: float) -> void:
	if not is_down and target_pivot:
		# Smoothly recover to upright rotation
		target_pivot.rotation.x = lerpf(target_pivot.rotation.x, 0.0, 12.0 * delta)

func take_damage(amount: float, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if is_down:
		return

	current_health -= amount
	print("[TARGET HIT] Damage: %s | Remaining HP: %s/%s" % [amount, current_health, max_health])
	
	# Play hit audio
	if hit_audio:
		hit_audio.pitch_scale = randf_range(0.95, 1.1)
		hit_audio.play()

	# Impact wobble kickback
	if target_pivot:
		target_pivot.rotation.x = -deg_to_rad(20.0)

	# Visual flash
	if target_mesh:
		target_mesh.material_override = flash_mat
		var flash_timer = get_tree().create_timer(0.08)
		flash_timer.timeout.connect(_reset_flash)

	# Check destruction
	if current_health <= 0.0:
		_knockdown()

func _reset_flash() -> void:
	if target_mesh and not is_down:
		target_mesh.material_override = null

func _knockdown() -> void:
	is_down = true
	print("[TARGET DESTROYED] Target knocked down! Resetting in 2.5s...")
	if target_pivot:
		target_pivot.rotation.x = -deg_to_rad(85.0)
	
	# Disable collision while down
	collision_shape.set_deferred("disabled", true)

	var reset_timer = get_tree().create_timer(2.5)
	reset_timer.timeout.connect(_reset_target)

func _reset_target() -> void:
	current_health = max_health
	is_down = false
	if target_pivot:
		target_pivot.rotation.x = 0.0
	if target_mesh:
		target_mesh.material_override = null
	collision_shape.set_deferred("disabled", false)
	print("[TARGET READY] Target has reset to full health.")

