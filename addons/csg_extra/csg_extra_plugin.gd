@tool
extends EditorPlugin


const NAME = "csg_extra"
const CURVE = "/csg_curve"


func _enable_plugin() -> void:
    EditorInterface.set_plugin_enabled(NAME + CURVE, true)


func _disable_plugin() -> void:
    EditorInterface.set_plugin_enabled(NAME + CURVE, false)


func _enter_tree() -> void:
    pass


func _exit_tree() -> void:
    pass
