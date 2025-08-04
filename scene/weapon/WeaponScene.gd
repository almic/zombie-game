@icon("res://icon/weapon.svg")

class_name WeaponScene extends Node3D


@onready var animation_tree: AnimationTree = %AnimationTree
var anim_state: AnimationNodeStateMachinePlayback
var anim_player: AnimationPlayer


## For animations that change the main hand
signal swap_hand(time: float)

## For animations that load individual rounds
signal round_loaded()

## For weapons that use a looping reload
signal reload_loop()

## For animations that charge the gun (to put one in the chamber)
signal charged()



## Location to create projectiles from
@export var projectile_marker: Marker3D

## Location of the particle system
@export var particle_marker: Marker3D


var _reload_loop_start_time: float = 0

var is_walking: bool = false

var can_fire: bool = false


func _ready() -> void:
    animation_tree.active = false
    anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
    anim_state = animation_tree['parameters/StateMachine/playback']

func _seek(time: float) -> void:
    animation_tree['parameters/TimeSeek/seek_request'] = time

func _reload_loop_start() -> void:
    _reload_loop_start_time = anim_state.get_current_play_position()

func _reload_loop_end() -> void:
    reload_loop.emit()

func _ready_to_fire() -> void:
    can_fire = true

func _emit_swap_hand(time: float) -> void:
    swap_hand.emit(time)

func _emit_round_loaded() -> void:
    round_loaded.emit()

func _emit_charged() -> void:
    charged.emit()


## Weapon is ready to be used
func on_ready() -> void:
    animation_tree.active = true

## Weapon has been triggered
func on_fire() -> void:
    can_fire = false
    if anim_state.get_fading_from_node():
        # If we are in the middle of a transition, we must teleport
        anim_state.start('fire', true)
    else:
        anim_state.travel('fire')

## Weapon starts to reload
func on_reload() -> void:
    can_fire = false
    anim_state.travel('reload')

## Weapon continues (loops) the reload
func on_reload_continue() -> void:
    if _reload_loop_start_time > 0:
        _seek(_reload_loop_start_time)

func on_charge() -> void:
    can_fire = false
    anim_state.travel('charge')

## Controller is walking with the weapon
func on_walking(walking: bool = true) -> void:
    is_walking = walking
