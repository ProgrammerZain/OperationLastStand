class_name Pistol
extends WeaponBase

@onready var muzzle_flash: Node3D = $MuzzleFlash
@onready var muzzle_light: OmniLight3D = $MuzzleFlash/MuzzleLight
@onready var audio_fire: AudioStreamPlayer3D = $AudioFire
@onready var audio_reload: AudioStreamPlayer3D = $AudioReload

var flash_timer: SceneTreeTimer = null

func _ready() -> void:
	weapon_name = "Tactical 9mm Pistol"
	damage = 25.0
	fire_rate = 0.2
	magazine_capacity = 12
	current_ammo = 12
	reserve_ammo = 36
	reload_time = 1.35
	max_range = 100.0
	
	super._ready()
	
	if muzzle_flash:
		muzzle_flash.visible = false

func _on_fire_feedback() -> void:
	# 1. Muzzle Flash & Light
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf_range(0, TAU)
		
		# Auto hide after 0.05 seconds
		flash_timer = get_tree().create_timer(0.05)
		flash_timer.timeout.connect(_hide_muzzle_flash)
	
	# 2. Audio playback with randomized pitch
	if audio_fire:
		audio_fire.pitch_scale = randf_range(0.96, 1.04)
		audio_fire.play()

func _hide_muzzle_flash() -> void:
	if muzzle_flash:
		muzzle_flash.visible = false

func _on_reload_feedback() -> void:
	if audio_reload:
		audio_reload.play()

func _on_dry_fire() -> void:
	# Subtle dry click using slightly higher pitched empty sound
	if audio_fire:
		audio_fire.pitch_scale = 2.2
		audio_fire.play()

