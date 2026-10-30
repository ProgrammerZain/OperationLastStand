extends Control

@onready var btn_play: Button = $CenterContainer/VBoxContainer/BtnPlay
@onready var btn_quit: Button = $CenterContainer/VBoxContainer/BtnQuit
@onready var click_audio: AudioStreamPlayer = $ClickAudio

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	btn_play.pressed.connect(_on_play_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	if click_audio:
		click_audio.play()
	GameManager.start_game()

func _on_quit_pressed() -> void:
	if click_audio:
		click_audio.play()
	GameManager.quit_game()

