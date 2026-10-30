class_name FacilityLevel
extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	# Ensure navigation mesh is up-to-date with static geometry
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(false)

