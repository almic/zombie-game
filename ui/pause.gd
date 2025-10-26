extends Control

@onready var btn_quit: Button = %btn_quit

func _ready() -> void:
    btn_quit.pressed.connect(btn_quit_pressed)

func btn_quit_pressed() -> void:
    GlobalWorld.quit_game()
