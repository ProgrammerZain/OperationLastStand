class_name FacilityLevel
extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var enemies_container: Node3D = $Enemies
@onready var flickering_light: OmniLight3D = get_node_or_null("LightFixtures/Light_Corridor_1/OmniLight3D")

var flicker_timer: float = 0.0

func _ready() -> void:
	# Ensure navigation mesh is synchronized
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(false)

	# Register all level enemies with the central GameManager
	if enemies_container:
		var enemies: Array = enemies_container.get_children()
		GameManager.register_level_enemies(enemies)

func _exit_tree() -> void:
	var amb: AudioStreamPlayer = get_node_or_null("AmbientAudio") as AudioStreamPlayer
	if amb:
		amb.stop()

func _process(delta: float) -> void:
	if flickering_light:
		flicker_timer -= delta
		if flicker_timer <= 0.0:
			flicker_timer = randf_range(0.08, 0.28)
			if randf() > 0.82:
				flickering_light.light_energy = randf_range(0.2, 0.6)
			else:
				flickering_light.light_energy = 1.4
