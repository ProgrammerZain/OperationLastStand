class_name VictoryScreen
extends Control

@onready var btn_play_again: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnPlayAgain
@onready var btn_main_menu: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnMainMenu
@onready var btn_quit: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnQuit
@onready var victory_audio: AudioStreamPlayer = $VictoryAudio
@onready var click_audio: AudioStreamPlayer = $ClickAudio

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	GameManager.game_victory_triggered.connect(_on_victory_triggered)
	
	btn_play_again.pressed.connect(_on_play_again_pressed)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_victory_triggered() -> void:
	visible = true
	if victory_audio:
		victory_audio.play()

func _on_play_again_pressed() -> void:
	_play_click()
	GameManager.restart_game()

func _on_main_menu_pressed() -> void:
	_play_click()
	GameManager.go_to_main_menu()

func _on_quit_pressed() -> void:
	_play_click()
	GameManager.quit_game()

func _play_click() -> void:
	if click_audio:
		click_audio.play()

