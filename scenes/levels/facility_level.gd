class_name FacilityLevel
extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var enemies_container: Node3D = $Enemies

func _ready() -> void:
	# Ensure navigation mesh is synchronized
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(false)

	# Register all level enemies with the central GameManager
	if enemies_container:
		var enemies: Array = enemies_container.get_children()
		GameManager.register_level_enemies(enemies)
