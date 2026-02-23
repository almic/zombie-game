@icon("res://icon/weapon.svg")

class_name WeaponScene extends Node3D

const START = &'Start'
const END = &'End'
const FIRE = &'fire'
const MELEE = &'melee'
const CHARGE = &'charge'
const RELOAD = &'reload'
const UNLOAD = &'unload'


@onready var mesh: Node3D = %Mesh
@onready var animation_tree: AnimationTree = %AnimationTree
var anim_state: AnimationNodeStateMachinePlayback
var state_machine: AnimationNodeStateMachine

var state: StringName = &''

## For animations that change the main hand
signal swap_hand(time: float)

## Weapon has melee'd
signal melee()

## For animations that load individual rounds
signal round_loaded()

## For animations that unload individual rounds
signal round_unloaded()

## For animations that unload an entire magazine
signal magazine_loaded()

## For animations that load an entire magazine
signal magazine_unloaded()

## For weapons that use a looping reload
signal reload_loop()

## For weapons that use a looping unload
signal unload_loop()

## For animations that charge the gun (to put one in the chamber)
signal charged()

## For animations that un-charge the gun (only the Revolver right now)
signal uncharged()


## Location of round ejection
@export var eject_marker: Marker3D

## Location to create projectiles from
@export var projectile_marker: Marker3D

## Location of the particle system
@export var particle_marker: Marker3D

## Location of reload mesh (round / magazine)
@export var reload_marker: Marker3D

## Location of magazine mesh while in the gun
@export var magazine_marker: Marker3D

## Brace point of the weapon. For weapons with stocks, this should be the back
## center of the stock. Otherwise, should be back center of the grip.
@export var brace_marker: Marker3D


## If the weapon has mechanical animations when melee'ing
## At the moment, none of the weapons change appearance when used for melee
var _has_melee_anim: bool = false
## If the weapon has mechanical animations when firing. Some weapons have no
## visual changes when firing (with the exception of triggers)
var _has_fire_anim: bool = false

var _reload_loop_start_time: float = -1
var _unload_loop_start_time: float = -1


func _ready() -> void:
    animation_tree.active = false
    anim_state = animation_tree['parameters/StateMachine/playback']

    var root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
    state_machine = root.get_node('StateMachine') as AnimationNodeStateMachine

    if reload_marker:
        reload_marker.visible = false

    anim_state.state_started.connect(
        func(s: StringName) -> void:
            state = s
            print('state: %s' % state)
    )
    _has_melee_anim = state_machine.has_node(MELEE)
    _has_fire_anim = state_machine.has_node(FIRE)

func _reload_loop_start() -> void:
    _reload_loop_start_time = anim_state.get_current_play_position()

func _reload_loop_end() -> void:
    reload_loop.emit()

func _unload_loop_start() -> void:
    _unload_loop_start_time = anim_state.get_current_play_position()

func _unload_loop_end() -> void:
    unload_loop.emit()

func _emit_melee() -> void:
    melee.emit()

func _emit_swap_hand(time: float) -> void:
    swap_hand.emit(time)

func _emit_round_loaded() -> void:
    round_loaded.emit()

func _emit_round_unloaded() -> void:
    round_unloaded.emit()

func _emit_magazine_loaded() -> void:
    magazine_loaded.emit()

func _emit_magazine_unloaded() -> void:
    magazine_unloaded.emit()

func _emit_charged() -> void:
    charged.emit()

func _emit_uncharged() -> void:
    uncharged.emit()


func set_reload_scene(scene: PackedScene) -> void:
    if not reload_marker:
        return

    # Expect only one child max, so just remove and break
    for child in reload_marker.get_children():
        reload_marker.remove_child(child)
        break

    if not scene:
        return

    reload_marker.add_child(scene.instantiate())

func set_magazine_scene(scene: PackedScene) -> void:
    if not magazine_marker:
        return

    # Expect only one child max, so just remove and break
    for child in magazine_marker.get_children():
        magazine_marker.remove_child(child)
        break

    if not scene:
        return

    magazine_marker.add_child(scene.instantiate())

# TODO: This function should only take a RigidBody3D, velocity, and impulse
func eject_round(
        round_dict: Dictionary,
        velocity: Vector3,
        direction: Vector3,
        direction_range: float,
        force: float,
        force_range: float
) -> void:
    if not eject_marker:
        return

    var round_scene: PackedScene
    var ttl: float

    if round_dict.is_live:
        round_scene = round_dict.ammo.scene_round_unloaded
        ttl = 0.3
    else:
        round_scene = round_dict.ammo.scene_round_expended
        ttl = 10.0

    if not round_scene:
        return

    var round_node: Node3D = round_scene.instantiate()
    get_tree().current_scene.add_child(round_node)
    get_tree().create_timer(ttl, false, true).timeout.connect(round_node.queue_free)

    round_node.global_position = eject_marker.global_position
    round_node.global_basis = eject_marker.global_basis

    # If not a physics body, we are done (weird?)
    var round_body: RigidBody3D = round_node as RigidBody3D
    if not round_body:
        return

    round_body.linear_velocity = velocity

    var eject_basis: Basis = mesh.basis
    eject_basis = Basis.looking_at(
            -direction,
            eject_basis.z.cross(direction)
    )
    eject_basis *= global_basis

    var forward: Vector3 = eject_basis.z

    # Randomize direction
    if direction_range > 0.0:
        var right: Vector3 = eject_basis.x
        var spread: float = sqrt(randf_range(0.0, 1.0))
        spread *= direction_range
        forward = forward.rotated(right, spread)
        forward = forward.rotated(eject_basis.z, randf_range(0.0, TAU))

    # Randomize force
    if force_range > 0.0:
        force += randf_range(0, force_range) * 2 - force_range

    var impulse_point: Vector3 = round_node.global_basis.z * 0.08

    round_body.apply_impulse(forward * force, impulse_point)

func seek(time: float) -> void:
    animation_tree['parameters/TimeSeek/seek_request'] = time

func travel(node: StringName, immediate: bool = false) -> void:
    if immediate:
        anim_state.start(node)
        #print('Teleporting to ' + node)
        return

    # NOTE: For development only, remove later
    if state_machine == null:
        push_warning('Did you override WeaponScene\'s _ready() method? Make sure you call super._ready()!!!')

    var anim_node: AnimationNodeAnimation = state_machine.get_node(node) as AnimationNodeAnimation
    if not anim_node:
        push_error('Missing animation node "%s" for %s' % [node, self.name])
        return

    #print('Traveling to ' + node + ' (' + anim_node.animation + ')')
    if state == END:
        # TODO: this should be handled by Godot, teleport to Start when
        #       traveling from End. Compile!
        anim_state.start(START)
    anim_state.travel(node)

## Weapon should fire
func goto_fire() -> bool:
    if _has_fire_anim:
        travel(FIRE)

    return true

## Weapon should melee
func goto_melee() -> bool:
    if _has_melee_anim:
        travel(MELEE)

    return true

## Weapon starts to reload
func goto_reload() -> bool:
    if not is_idle():
        return false

    travel(RELOAD)
    return true

## Weapon continues (loops) the reload
func goto_reload_continue() -> bool:
    if state != RELOAD:
        return false

    if _reload_loop_start_time >= 0:
        seek(_reload_loop_start_time)
        return true

    return false

## Weapon starts to unload
func goto_unload() -> bool:
    if not is_idle():
        return false

    travel(UNLOAD)
    return true

## Weapon continues (loops) the reload
func goto_unload_continue() -> bool:
    if state != UNLOAD:
        return false

    if _unload_loop_start_time >= 0:
        seek(_unload_loop_start_time)
        return true

    return false

## Weapon should charge (put one in the chamber)
func goto_charge() -> bool:
    if not is_idle():
        return false

    travel(CHARGE)
    return true

## If the animation state is an 'idle' or 'walk' state
func is_idle() -> bool:
    return state == END or state == START

## If the animation state allows aiming
func can_aim() -> bool:
    if is_idle():
        return true
    elif state == FIRE:
        return true
    return false

## Show the reload mesh and hide the magazine mesh
func detach_magazine() -> void:
    # NOTE: it is an error to call this from animation without these markers
    magazine_marker.visible = false
    reload_marker.visible = true

## Hide the reload mesh and show the magazine mesh
func attach_magazine() -> void:
    # NOTE: it is an error to call this from animation without these markers
    reload_marker.visible = false
    magazine_marker.visible = true

## Handles visual scene changes when the weapon state changes. Implemented per
## weapon scene.
@warning_ignore("unused_parameter")
func on_weapon_updated(weapon: WeaponResource) -> void:
    pass
