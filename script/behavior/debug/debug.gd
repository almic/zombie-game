class_name BehaviorDebugScene extends Node3D


@onready var behavior_debug_ui: BehaviorDebugDisplay = %BehaviorDebugUI


func add_action(message: String, color: Color = Color()) -> void:
    behavior_debug_ui.add_action(message, color)
