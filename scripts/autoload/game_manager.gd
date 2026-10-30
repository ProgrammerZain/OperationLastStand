extends Node

signal enemy_count_changed(remaining: int, total: int)
signal objective_changed(text: String)
signal game_victory_triggered()
signal game_over_triggered()
signal pause_toggled(is_paused: bool)

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	VICTORY,
	GAME_OVER
}

var current_state: GameState = GameState.MENU
var total_enemies: int = 0
var remaining_enemies: int = 0
var current_objective: String = "Clear the facility of all hostile forces"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	# Handle Escape key toggling pause during active gameplay or pause
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
		if current_state == GameState.PLAYING:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif current_state == GameState.PAUSED:
			toggle_pause()
			get_viewport().set_input_as_handled()

func start_game() -> void:
	get_tree().paused = false
	current_state = GameState.PLAYING
	current_objective = "Clear the facility of all hostile forces"
	get_tree().change_scene_to_file("res://scenes/levels/facility_level.tscn")

func restart_game() -> void:
	get_tree().paused = false
	current_state = GameState.PLAYING
	current_objective = "Clear the facility of all hostile forces"
	get_tree().reload_current_scene()

func go_to_main_menu() -> void:
	get_tree().paused = false
	current_state = GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func quit_game() -> void:
	get_tree().quit()

func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_toggled.emit(true)
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_toggled.emit(false)

func register_level_enemies(enemies_list: Array) -> void:
	total_enemies = enemies_list.size()
	remaining_enemies = total_enemies
	current_state = GameState.PLAYING
	
	for enemy in enemies_list:
		if enemy is EnemySoldier:
			if not enemy.enemy_died.is_connected(on_enemy_killed):
				enemy.enemy_died.connect(on_enemy_killed)
	
	enemy_count_changed.emit(remaining_enemies, total_enemies)
	objective_changed.emit(current_objective)

func on_enemy_killed(_enemy: EnemySoldier) -> void:
	if remaining_enemies > 0:
		remaining_enemies -= 1
		print("[GAME MANAGER] Enemy down! Remaining: %s / %s" % [remaining_enemies, total_enemies])
		enemy_count_changed.emit(remaining_enemies, total_enemies)
		
		if remaining_enemies <= 0:
			trigger_victory()

func on_player_died() -> void:
	if current_state == GameState.PLAYING:
		trigger_game_over()

func trigger_victory() -> void:
	current_state = GameState.VICTORY
	current_objective = "Facility Secured — Mission Complete"
	objective_changed.emit(current_objective)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[GAME MANAGER] VICTORY ACHIEVED!")
	game_victory_triggered.emit()

func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	current_objective = "Operative K.I.A. — Mission Failed"
	objective_changed.emit(current_objective)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[GAME MANAGER] GAME OVER — PLAYER DEFEATED!")
	game_over_triggered.emit()

