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
        anim_state.start('shotgun_fire')
    else:
        anim_state.travel('shotgun_fire')
