@icon("res://icon/weapon.svg")

class_name WeaponScene extends Node3D


@onready var mesh: Node3D = %Mesh
@onready var animation_tree: AnimationTree = %AnimationTree
var anim_state: AnimationNodeStateMachinePlayback


## For animations that change the main hand
signal swap_hand(time: float)

## Weapon has fired
signal fired()

## Weapon has melee'd
signal melee()

## A round ejects from the gun
signal round_ejected()

## For animations that load individual rounds
signal round_loaded()

## For weapons that use a looping reload
signal reload_loop()

## For animations that charge the gun (to put one in the chamber)
signal charged()


## Location of round ejection
@export var eject_marker: Marker3D

## Location to create projectiles from
@export var projectile_marker: Marker3D

## Location of the particle system
@export var particle_marker: Marker3D

## Location of reload mesh (round / magazine)
@export var reload_marker: Marker3D


var _reload_loop_start_time: float = -1

var is_walking: bool = false

var anim_locked: bool = false


func _ready() -> void:
    animation_tree.active = false
    anim_state = animation_tree['parameters/StateMachine/playback']
    animation_tree.animation_started.connect(_anim_start)

func _seek(time: float) -> void:
    animation_tree['parameters/TimeSeek/seek_request'] = time

func _travel(to_node: StringName) -> void:
    anim_state.travel(to_node)

func _reload_loop_start() -> void:
    _reload_loop_start_time = anim_state.get_current_play_position()

func _reload_loop_end() -> void:
    reload_loop.emit()
    _reload_loop_start_time = -1

func _lock_anim() -> void:
    anim_locked = true

func _unlock_anim() -> void:
    anim_locked = false

func _emit_fired() -> void:
    fired.emit()

func _emit_melee() -> void:
    melee.emit()

func _emit_swap_hand(time: float) -> void:
    swap_hand.emit(time)

func _emit_round_ejected() -> void:
    round_ejected.emit()

func _emit_round_loaded() -> void:
    round_loaded.emit()

func _emit_charged() -> void:
    charged.emit()

func _anim_start(_anim: StringName) -> void:
    anim_locked = false


## Weapon is ready to be used
func goto_ready() -> void:
    animation_tree.active = true

    var anim: StringName = &'idle'
    if is_walking:
        anim = &'walk'

    anim_state.travel(anim)

## Weapon should fire
func goto_fire() -> void:
    anim_state.travel(&'fire')

## Weapon should melee
func goto_melee() -> void:
    anim_state.travel(&'melee')

## Weapon starts to reload
func goto_reload() -> void:
    anim_state.travel(&'reload')

## Weapon continues (loops) the reload
func goto_reload_continue() -> void:
    if _reload_loop_start_time >= 0:
        _seek(_reload_loop_start_time)

## Weapon should charge (put one in the chamber)
func goto_charge() -> void:
    anim_state.travel(&'charge')

## Controller is walking with the weapon
func set_walking(walking: bool = true) -> void:
    is_walking = walking
