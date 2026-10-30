class_name WeaponBase
extends Node3D

signal fired(current_ammo: int, max_ammo: int)
signal reloaded(current_ammo: int, reserve_ammo: int)
signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal reload_started(duration: float)
signal reload_finished()
signal out_of_ammo()

@export_group("Weapon Properties")
@export var weapon_name: String = "BaseWeapon"
@export var damage: float = 25.0
@export var fire_rate: float = 0.2
@export var magazine_capacity: int = 12
@export var current_ammo: int = 12
@export var reserve_ammo: int = 36
@export var max_reserve_ammo: int = 48
@export var reload_time: float = 1.35
@export var max_range: float = 100.0

@export_group("Recoil & Feel")
@export var recoil_position_kick: Vector3 = Vector3(0.0, 0.015, 0.055)
@export var recoil_rotation_kick: Vector3 = Vector3(0.16, 0.02, -0.01)
@export var recoil_recovery_speed: float = 14.0
@export var sway_amount: float = 0.0018
@export var max_sway: float = 0.035

var can_fire: bool = true
var is_reloading: bool = false

var base_position: Vector3
var base_rotation: Vector3
var target_recoil_pos: Vector3 = Vector3.ZERO
var target_recoil_rot: Vector3 = Vector3.ZERO
var sway_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	base_position = position
	base_rotation = rotation
	emit_signal("ammo_changed", current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	target_recoil_pos = target_recoil_pos.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	target_recoil_rot = target_recoil_rot.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	sway_offset = sway_offset.lerp(Vector3.ZERO, 8.0 * delta)
	
	position = base_position + target_recoil_pos + sway_offset
	rotation = base_rotation + target_recoil_rot

func apply_sway(mouse_relative: Vector2) -> void:
	sway_offset.x = clampf(sway_offset.x - mouse_relative.x * sway_amount, -max_sway, max_sway)
	sway_offset.y = clampf(sway_offset.y + mouse_relative.y * sway_amount, -max_sway, max_sway)

func can_shoot() -> bool:
	return can_fire and not is_reloading and current_ammo > 0

func fire() -> bool:
	if not can_shoot():
		if current_ammo == 0 and not is_reloading:
			emit_signal("out_of_ammo")
			_on_dry_fire()
		return false

	current_ammo -= 1
	can_fire = false
	
	_apply_recoil()
	_on_fire_feedback()
	_perform_hitscan()
	
	emit_signal("fired", current_ammo, magazine_capacity)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	
	var fire_timer: SceneTreeTimer = get_tree().create_timer(fire_rate)
	fire_timer.timeout.connect(_on_fire_cooldown_finished)
	return true

func reload() -> void:
	if is_reloading or current_ammo == magazine_capacity or reserve_ammo <= 0:
		return
	
	is_reloading = true
	emit_signal("reload_started", reload_time)
	_on_reload_feedback()
	
	target_recoil_pos += Vector3(0.0, -0.06, -0.03)
	target_recoil_rot += Vector3(-0.28, 0.05, -0.08)
	
	var reload_timer: SceneTreeTimer = get_tree().create_timer(reload_time)
	reload_timer.timeout.connect(_on_reload_finished)

func _on_reload_finished() -> void:
	if not is_reloading:
		return
	var needed: int = magazine_capacity - current_ammo
	var amount_to_add: int = mini(needed, reserve_ammo)
	current_ammo += amount_to_add
	reserve_ammo -= amount_to_add
	is_reloading = false
	
	emit_signal("reloaded", current_ammo, reserve_ammo)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	emit_signal("reload_finished")

func _on_fire_cooldown_finished() -> void:
	can_fire = true

func _apply_recoil() -> void:
	target_recoil_pos += recoil_position_kick
	target_recoil_rot += recoil_rotation_kick

func _perform_hitscan() -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return {}

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var end: Vector3 = origin + forward * max_range

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 | 4 | 8
	
	var player_node: Node = _find_player_parent()
	if player_node:
		query.exclude = [player_node]

	var result: Dictionary = space_state.intersect_ray(query)
	var hit_point: Vector3 = result.get("position", end)
	
	# Spawn bullet tracer from weapon muzzle to hit point
	_spawn_tracer(global_position + (-global_transform.basis.z * 0.25), hit_point)

	if result and not result.is_empty():
		_handle_hit(result)
	return result

func _handle_hit(hit_info: Dictionary) -> void:
	var collider: Object = hit_info.get("collider")
	var hit_pos: Vector3 = hit_info.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = hit_info.get("normal", Vector3.UP)
	
	var did_hit_target: bool = false
	if collider:
		if collider.has_method("take_damage"):
			collider.take_damage(damage, hit_pos, hit_normal)
			did_hit_target = true
		elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
			collider.get_parent().take_damage(damage, hit_pos, hit_normal)
			did_hit_target = true
			
	if did_hit_target:
		var hud = get_tree().get_first_node_in_group("hud") as GameHUD
		if hud and hud.has_method("show_hitmarker"):
			hud.show_hitmarker()
			
	_spawn_impact_effect(hit_pos, hit_normal)

func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var tracer_scene = load("res://scenes/weapons/bullet_tracer.tscn")
	if tracer_scene:
		var tracer = tracer_scene.instantiate()
		get_tree().root.add_child(tracer)
		tracer.init_tracer(from_pos, to_pos)

func _spawn_impact_effect(hit_pos: Vector3, hit_normal: Vector3) -> void:
	var decal_scene = load("res://scenes/weapons/bullet_decal.tscn")
	if decal_scene:
		var decal: Node3D = decal_scene.instantiate() as Node3D
		get_tree().root.add_child(decal)
		decal.global_position = hit_pos
		if hit_normal != Vector3.ZERO and not hit_normal.is_equal_approx(Vector3.UP):
			decal.look_at(hit_pos + hit_normal, Vector3.UP)

func _find_player_parent() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is CharacterBody3D:
			return cur
		cur = cur.get_parent()
	return null

func _on_fire_feedback() -> void:
	pass

func _on_dry_fire() -> void:
	pass

func _on_reload_feedback() -> void:
	pass
