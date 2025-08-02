@tool

extends WeaponScene

@onready var animation_tree: AnimationTree = %AnimationTree

var anim_state: AnimationNodeStateMachinePlayback


func _ready() -> void:
    anim_state = animation_tree['parameters/playback']
    animation_tree.active = false

func on_ready() -> void:
    animation_tree.active = true

func on_fire() -> void:
    # If we are in the middle of a transition, we must teleport
    if anim_state.get_fading_from_node():
        anim_state.start('shovel_swing')
    else:
        anim_state.travel('shovel_swing')

func on_walking(is_walking: bool = true) -> void:
    if is_walking:
        animation_tree['parameters/conditions/idle'] = false
        animation_tree['parameters/conditions/walking'] = true
    else:
        animation_tree['parameters/conditions/idle'] = true
        animation_tree['parameters/conditions/walking'] = false

func swap_side(time: float = 0.0) -> void:
    # TODO: shovel should flip sides when being used
    # This should be done with a custom node to flip animation
    # track values along the X axis (rotation Y/Z)
    swap_hand.emit(time)
