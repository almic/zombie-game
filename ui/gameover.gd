class_name GameoverScreen extends Control

@onready var btn_quit: Button = %btn_quit
@onready var menu: VBoxContainer = %Menu
@onready var background: ColorRect = $background

func _ready() -> void:
    background.modulate = Color(1, 1, 1, 0)
    menu.modulate = Color(1, 1, 1, 0)
    menu.visible = false
    btn_quit.pressed.connect(btn_quit_pressed)

func play_gameover() -> void:
    var fade_in: Tween = get_tree().create_tween()
    fade_in.tween_property(background, 'modulate', Color.WHITE, 2.0)
    fade_in.tween_callback(
        func ():
            menu.visible = true
            var fade_in2: Tween = get_tree().create_tween()
            fade_in2.tween_property(menu, 'modulate', Color.WHITE, 0.5)
    )

func btn_quit_pressed() -> void:
    GlobalWorld.quit_game()
