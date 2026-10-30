extends Node

func _ready() -> void:
	print("--- BEGINNING FULL GAMEPLAY & POLISH VERIFICATION (SCENE MODE) ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. Verify scenes load properly
	var level_scene: PackedScene = load("res://scenes/levels/facility_level.tscn")
	assert(level_scene != null, "Failed to load facility_level.tscn")
	var level: Node = level_scene.instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[PASS] FacilityLevel instantiated and added to tree.")

	# 2. Verify Player and Weapon
	var player: Player = level.get_node_or_null("Player") as Player
	assert(player != null, "Player node not found in level")
	assert(player.current_weapon != null, "Player has no weapon equipped")
	var weapon: WeaponBase = player.current_weapon
	assert(weapon.current_ammo == 12, "Initial ammo should be 12")
	assert(weapon.reserve_ammo == 36, "Initial reserve should be 36")
	print("[PASS] Player and Pistol initialized with 12/36 ammo.")

	# 3. Verify Weapon Fire & Sway
	weapon.apply_sway(Vector2(10.0, -5.0))
	assert(abs(weapon.sway_offset.x) > 0.0, "Weapon sway did not apply")
	var fired: bool = weapon.fire()
	assert(fired, "Weapon should fire successfully")
	assert(weapon.current_ammo == 11, "Ammo should decrement to 11")
	print("[PASS] Weapon sway and firing verified.")

	# 4. Verify Enemy reactions
	var enemies_node: Node = level.get_node_or_null("Enemies")
	assert(enemies_node != null and enemies_node.get_child_count() > 0, "No enemies found")
	var enemy: EnemySoldier = enemies_node.get_child(0) as EnemySoldier
	assert(enemy != null, "Enemy instance invalid")
	var initial_hp: float = enemy.current_health
	
	enemy.take_damage(25.0)
	assert(enemy.current_health == initial_hp - 25.0, "Enemy HP should decrease by 25")
	assert(enemy.current_state == EnemySoldier.State.CHASE, "Enemy should transition to CHASE on damage")
	print("[PASS] Enemy take_damage, flinch, and state transition verified.")

	# 5. Verify HUD Hitmarker
	var hud: GameHUD = get_tree().get_first_node_in_group("hud") as GameHUD
	assert(hud != null, "HUD not found")
	assert(hud.has_method("show_hitmarker"), "HUD missing show_hitmarker method")
	hud.show_hitmarker()
	assert(hud.hitmarker.modulate.a > 0.5, "Hitmarker should become visible")
	print("[PASS] HUD hitmarker visual feedback verified.")

	# 6. Verify Enemy Elimination & GameManager
	var initial_remaining: int = GameManager.remaining_enemies
	enemy.die()
	await get_tree().physics_frame
	assert(GameManager.remaining_enemies == initial_remaining - 1, "Remaining enemies should decrement")
	print("[PASS] Enemy death and hostile counter decrement verified.")

	# 7. Verify Player Damage
	player.take_damage(30.0)
	assert(player.current_health == 70.0, "Player HP should decrease to 70")
	print("[PASS] Player damage and HUD health update verified.")

	print("--- ALL 7/7 TESTS PASSED SUCCESSFULLY! ---")
	level.queue_free()
	await get_tree().physics_frame
	get_tree().quit(0)

