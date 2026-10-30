class_name GameHUD
extends CanvasLayer

# Top UI references
@onready var objective_label: Label = $TopContainer/ObjectiveBox/ObjectiveLabel
@onready var enemy_count_label: Label = $TopContainer/EnemyBox/EnemyCountLabel

# Center UI references
@onready var reticle_center: ColorRect = $Crosshair/ReticleCenter

# Bottom-Left Health references
@onready var health_label: Label = $BottomLeft/HealthBox/HealthLabel
@onready var health_bar: ProgressBar = $BottomLeft/HealthBox/HealthBar

# Bottom-Right Ammo references
@onready var ammo_label: Label = $BottomRight/AmmoBox/AmmoLabel
@onready var status_label: Label = $BottomRight/AmmoBox/StatusLabel
@onready var weapon_name_label: Label = $BottomRight/AmmoBox/WeaponNameLabel

# Screen FX
@onready var damage_overlay: ColorRect = $DamageOverlay

func _ready() -> void:
	# Connect to global GameManager
	GameManager.enemy_count_changed.connect(_on_enemy_count_changed)
	GameManager.objective_changed.connect(_on_objective_changed)
	
	# Initial populate from GameManager
	_on_enemy_count_changed(GameManager.remaining_enemies, GameManager.total_enemies)
	_on_objective_changed(GameManager.current_objective)

func _on_enemy_count_changed(remaining: int, total: int) -> void:
	if enemy_count_label:
		enemy_count_label.text = "HOSTILES: %d / %d" % [remaining, total]
		if remaining <= 1 and total > 0:
			enemy_count_label.modulate = Color(1.0, 0.4, 0.4)
		else:
			enemy_count_label.modulate = Color(1.0, 0.85, 0.3)

func _on_objective_changed(text: String) -> void:
	if objective_label:
		objective_label.text = "OBJECTIVE: %s" % text

func update_health(current: float, max_val: float) -> void:
	if health_label:
		health_label.text = "+ %d HP" % int(current)
		if current <= 25.0:
			health_label.modulate = Color(1.0, 0.25, 0.25)
		elif current <= 50.0:
			health_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			health_label.modulate = Color(0.25, 0.95, 0.45)

	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func update_ammo(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%02d / %02d" % [current, reserve]

func set_reload_status(text: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = text
		status_label.modulate = color

func trigger_damage_flash() -> void:
	if damage_overlay:
		damage_overlay.modulate = Color(1.0, 1.0, 1.0, 0.5)
		var tween = create_tween()
		tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.25)

