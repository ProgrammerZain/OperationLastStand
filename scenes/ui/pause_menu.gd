class_name PauseMenu
extends Control

@onready var btn_resume: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnResume
@onready var btn_restart: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnRestart
@onready var btn_main_menu: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnMainMenu
@onready var btn_quit: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnQuit
@onready var click_audio: AudioStreamPlayer = $ClickAudio

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	GameManager.pause_toggled.connect(_on_pause_toggled)
	
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_pause_toggled(is_paused: bool) -> void:
	visible = is_paused

func _on_resume_pressed() -> void:
	_play_click()
	GameManager.toggle_pause()

func _on_restart_pressed() -> void:
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

