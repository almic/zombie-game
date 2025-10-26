class_name BehaviorDebugDisplay extends Control


@onready var action_log: VBoxContainer = %action_log
@onready var mind_state: MarginContainer = %mind_state


var action_base: MarginContainer


func _ready() -> void:
    action_base = %action_base.duplicate()

    for child in action_log.get_children():
        child.queue_free()

    action_log.sort_children.connect(post_log_sort, CONNECT_DEFERRED)


func add_action(message: String, color: Color) -> void:
    var new_action := action_base.duplicate()
    var bg_color: ColorRect = new_action.get_node('color_bg')
    var label: RichTextLabel = new_action.get_node('action_text_container/text')

    # Make color always transparent
    if color.a > 0.67:
        color.a = 0.67

    bg_color.color = color
    label.text = message

    action_log.add_child(new_action)


func post_log_sort() -> void:
    var max_height: float = size.y
    var state_height: float = mind_state.size.y

    if action_log.size.y + state_height > max_height:
        action_log.remove_child(action_log.get_child(0))
        action_log.queue_sort()
