@tool
extends EditorPlugin


const MainScreen = preload("uid://os0fy1o7hann")
var main_screen


func _has_main_screen() -> bool:
    return true


func _get_plugin_name():
    return "Behavior"


func _get_plugin_icon():
    return preload("uid://cdixpsmune8bp")


func _handles(object: Object) -> bool:
    return object is BehaviorMindSettings

func _edit(object: Object) -> void:
    if _handles(object):
        main_screen.edit(object)

func _enable_plugin() -> void:
    # Add autoloads here.
    pass


func _disable_plugin() -> void:
    # Remove autoloads here.
    pass


func _enter_tree() -> void:
    main_screen = MainScreen.instantiate()
    EditorInterface.get_editor_main_screen().add_child(main_screen)
    _make_visible(false)


func _exit_tree() -> void:
    if main_screen:
        main_screen.queue_free()


func _make_visible(visible):
    if main_screen:
        main_screen.visible = visible
