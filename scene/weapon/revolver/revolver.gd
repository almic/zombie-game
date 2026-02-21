
## Special scene just for the revolver
class_name RevolverWeaponScene extends WeaponScene

const PORTS = 6
const PORT_ANGLE = TAU / PORTS
const FIRE_DOUBLE = &'fire_double'

const OPEN_CYLINDER_RELOAD = &'open_cylinder_reload'
const EJECT_ROUNDS_BEFORE_RELOAD = &'eject_rounds_before_reload'
const EJECT_TO_RELOAD = &'eject_to_reload'
const OPEN_TO_RELOAD = &'open_to_reload'
const RELOAD_SPIN = &'reload_spin'
const RELOAD_OUT_SPIN = &'reload_out_spin'
const RELOAD_TO_UNLOAD = &'reload_to_unload'
const OUT_RELOAD = &'out_reload'

const OPEN_CYLINDER_UNLOAD = &'open_cylinder_unload'
const EJECT_ROUNDS_BEFORE_UNLOAD = &'eject_rounds_before_unload'
const EJECT_TO_UNLOAD = &'eject_to_unload'
const OPEN_TO_UNLOAD = &'open_to_unload'
const UNLOAD_SPIN = &'unload_spin'
const UNLOAD_OUT_SPIN = &'unload_out_spin'
const UNLOAD_TO_RELOAD = &'unload_to_reload'
const OUT_UNLOAD = &'out_unload'

const FIRE_FAN = &'fire_fan'
const FIRE_FAN_CHARGE = &'fire_fan_charge'


const CYLINDER_ROTATE = &'revolver/cylinder_rotate'
const REVOLVER_CHARGE = &'revolver/' + CHARGE

@onready var cylinder_spin: Node3D = %cylinder_spin
@onready var hammer_axel: Node3D = %hammer_axel

@onready var ports: Array[Marker3D] = [
    %Port1Marker,
    %Port2Marker,
    %Port3Marker,
    %Port4Marker,
    %Port5Marker,
    %Port6Marker,
]


## Unique signal to request logical cylinder position rotation
signal cylinder_rotated(steps: int)


## Marker for the round to be unloaded
@export var unload_marker: Marker3D


var supported_ammo: Dictionary

var is_fanning: bool = false
var cocked: bool = false
var mixed_reserve: PackedInt32Array
var cylinder_ammo_state: PackedByteArray
var cylinder_position: int

#var has_used_rounds: bool = false
var has_used_rounds: bool:
    get():
        for i in range(PORTS):
            if mixed_reserve[i] > 0 and not cylinder_ammo_state[i]:
                return true
        return false


var has_empty_ports: bool:
    get():
        return mixed_reserve.find(0) != -1


var cylinder_anim: Animation
var cylinder_apply_on_finish: bool = false

var cylinder_interp: Interpolation = Interpolation.new()

var _unload_one_spin: bool = false


func _ready() -> void:
    super._ready()
    cylinder_anim = animation_tree.get_animation(CYLINDER_ROTATE)
    if not cylinder_anim:
        push_error("Revolver could not get the cylinder rotation animation!! Investigate!")

func _process(delta: float) -> void:
    if cylinder_interp.is_done:
        return

    var current_time: float = cylinder_interp.update(delta)
    if cylinder_interp.is_done:
        apply_rotate_cylinder()
        return

    var current_value: float = cylinder_anim.bezier_track_interpolate(0, fposmod(current_time, 1.0))
    # NOTE: animation runs from 0 to -1, invert when going backwards
    if current_time < 0.0:
        current_value += PORT_ANGLE

    # NOTE: Clockwise is a NEGATIVE spin
    var angle: float = (
            -PORT_ANGLE * cylinder_position
            + (-PORT_ANGLE * int(current_time) + current_value)
    )
    cylinder_spin.rotation.z = angle

func _reload_loop_start() -> void:
    apply_rotate_cylinder()

    # NOTE: It may be possible for all cylinders to be filled, so check for that
    if mixed_reserve.find(0) == -1:
        travel(OUT_RELOAD, true)
        return

    # If the current port is full, travel straight to the reload spin
    if mixed_reserve[cylinder_position] > 0:
        travel(RELOAD_SPIN, true)

func _unload_loop_start() -> void:
    apply_rotate_cylinder()

    # If the current port is empty, travel straight to the unload spin
    var type: int = mixed_reserve[cylinder_position]
    if not type:
        if _unload_one_spin:
            _unload_one_spin = false
            travel(UNLOAD_SPIN, true)
        elif cocked:
            travel(UNLOAD_OUT_SPIN, true)
        else:
            travel(OUT_UNLOAD, true)
        return

    # Apply current round unload scene
    if not unload_marker:
        return

    # Expect only one child max, so just remove and break
    for child in unload_marker.get_children():
        unload_marker.remove_child(child)
        break

    var ammo: AmmoResource = supported_ammo.get(type) as AmmoResource
    if not ammo:
        return

    # NOTE: unloaded rounds should always be live
    var round_scene: PackedScene = ammo.scene_round_unloaded

    var round_node: Node3D = round_scene.instantiate() as Node3D
    round_node.process_mode = PROCESS_MODE_DISABLED

    unload_marker.add_child(round_node)

    var ttl: float = 1.3

    get_tree().create_timer(ttl).timeout.connect(round_node.queue_free)


## Sets the visibility of the current port for unloading
func _hide_unload_port() -> void:
    var port: Marker3D = ports[cylinder_position]

    # NOTE: only one child expected, so break after the first
    for child in port.get_children():
        child.visible = false
        break

func _emit_round_loaded() -> void:
    super._emit_round_loaded()
    update_ports()

func _emit_round_unloaded() -> void:
    super._emit_round_unloaded()
    update_ports()

    if not unload_marker:
        return

    # Activate the unload marker child
    for child in unload_marker.get_children():
        var child_transform: Transform3D = child.global_transform
        unload_marker.remove_child(child)
        get_tree().current_scene.add_child(child)
        child.global_transform = child_transform
        child.process_mode = Node.PROCESS_MODE_INHERIT
        break

func _emit_magazine_unloaded() -> void:
    # HACK: This sucks, but it will work... for now...
    var velocity: Vector3
    var weapon_node: WeaponNode = get_parent_node_3d() as WeaponNode
    if weapon_node and weapon_node.controller:
        velocity = weapon_node.controller.velocity

    # For the revolver, we can simply go through all the ports and "eject" them
    var tree: SceneTree = get_tree()
    var start: int = randi_range(0, PORTS - 1)
    var delay: float = 0.0
    var pos: int
    var port: Marker3D
    var type: int
    var ammo: AmmoResource
    for i in range(PORTS):
        pos = wrapi(i + start + cylinder_position, 0, PORTS)
        type = mixed_reserve[pos]
        if not type or cylinder_ammo_state[pos]:
            continue

        pos = wrapi(i + start, 0, PORTS)
        port = ports[pos]
        for child in port.get_children():
            port.remove_child(child)
            child.queue_free()

        ammo = supported_ammo.get(type) as AmmoResource
        if not ammo:
            continue

        var ammo_scene: PackedScene = ammo.scene_round_expended
        if not ammo_scene:
            continue

        var ammo_node: Node3D = ammo_scene.instantiate()
        tree.current_scene.add_child(ammo_node)
        tree.create_timer(10.0, false, true).timeout.connect(ammo_node.queue_free)

        ammo_node.global_transform = port.global_transform

        if ammo_node is RigidBody3D:
            ammo_node.process_mode = Node.PROCESS_MODE_DISABLED
            tree.create_timer(delay, false).timeout.connect(
                func ():
                    ammo_node.process_mode = Node.PROCESS_MODE_INHERIT
            )

        delay += randf_range(0.02, 0.06)

    super._emit_magazine_unloaded()

func can_aim() -> bool:
    return (
           is_idle()
        or state == FIRE
        or state == CHARGE
        or state == FIRE_DOUBLE
    )

func goto_fire() -> bool:
    if is_idle():
        if is_fanning:
            travel(FIRE_FAN, true)
        elif cocked:
            travel(FIRE)
        else:
            travel(FIRE_DOUBLE)
        return true
    elif (
           state == CHARGE
    ):
        travel(FIRE_DOUBLE, true)
    elif (
           state == FIRE_FAN
        or state == FIRE_FAN_CHARGE
    ):
        travel(FIRE_FAN, true)
        return true

    return false

func goto_reload() -> bool:
    if (
           is_idle()
        or state == OPEN_CYLINDER_UNLOAD
        or state == OUT_UNLOAD
    ):
        travel(OPEN_CYLINDER_RELOAD)
        return true
    elif state == RELOAD_TO_UNLOAD:
        travel(UNLOAD_TO_RELOAD)
        return true
    elif state == UNLOAD_TO_RELOAD:
        return true
    elif (
           state == UNLOAD
        or state == UNLOAD_SPIN
        or state == UNLOAD_OUT_SPIN
        or state == EJECT_ROUNDS_BEFORE_UNLOAD
        or state == EJECT_TO_UNLOAD
        or state == OPEN_TO_UNLOAD
    ):
        travel(RELOAD)
        return true
    return false

func goto_unload() -> bool:
    if (
           is_idle()
        or state == OPEN_CYLINDER_RELOAD
        or state == OUT_RELOAD
    ):
        travel(OPEN_CYLINDER_UNLOAD)
        _unload_one_spin = true
        return true
    elif state == UNLOAD_TO_RELOAD:
        travel(RELOAD_TO_UNLOAD)
        _unload_one_spin = true
        return true
    elif state == RELOAD_TO_UNLOAD:
        return true
    elif (
           state == RELOAD
        or state == RELOAD_SPIN
        or state == RELOAD_OUT_SPIN
        or state == EJECT_ROUNDS_BEFORE_RELOAD
        or state == EJECT_TO_RELOAD
        or state == OPEN_TO_RELOAD
    ):
        travel(UNLOAD)
        _unload_one_spin = true
        return true
    return false

func goto_reload_continue() -> bool:
    if state != RELOAD:
        return false

    # NOTE: It may be possible for all cylinders to be filled, so check for that
    if mixed_reserve.find(0) == -1:
        return false

    travel(RELOAD_SPIN)
    return true

func goto_unload_continue() -> bool:
    _unload_one_spin = true

    if state == UNLOAD:
        travel(UNLOAD_SPIN)
        return true

    return state == UNLOAD_SPIN

func get_cylinder_rotation() -> float:
    return cylinder_spin.rotation.z

func update_ports() -> void:
    var type: int
    var ammo: AmmoResource
    for i in range(PORTS):
        # A port would only have 1 child for the mesh scene
        for child in ports[i].get_children():
            ports[i].remove_child(child)
            child.queue_free()
            break

        type = mixed_reserve[i]
        if not type:
            # Empty port (type == 0)
            continue

        ammo = supported_ammo.get(type) as AmmoResource

        var node: Node3D
        if cylinder_ammo_state[i]:
            node = ammo.scene_round.instantiate() as Node3D
        else:
            node = ammo.scene_round_expended.instantiate() as Node3D
            # NOTE: likely a RigidBody, so just disable this
            node.process_mode = Node.PROCESS_MODE_DISABLED

        ports[i].add_child(node)

func update_cylinder_spin() -> void:
    # NOTE: Ports are organized COUNTER CLOCKWISE
    var rotation_z: float = cylinder_position * -PORT_ANGLE

    # Cancel animation if the cylinder position changes
    if not cylinder_interp.is_done:
        cylinder_apply_on_finish = false
        cylinder_interp.reset(0.0)

    cylinder_spin.rotation.z = rotation_z

## Force hammer axel to match cocked state
func update_hammer() -> void:
    if cocked:
        # Last frame of charge animation
        var anim: Animation = animation_tree.get_animation(REVOLVER_CHARGE)
        var hammer_path: NodePath = get_path_to(hammer_axel)
        hammer_path = NodePath(str(hammer_path) + ':rotation:x')
        var track_id: int = anim.find_track(hammer_path, Animation.TYPE_BEZIER)
        if track_id == -1:
            push_error('Failed to set hammer position of revolver, track "%s" not found!' % str(hammer_path))
            return
        var rot: float = anim.bezier_track_interpolate(track_id, anim.length)
        hammer_axel.rotation.x = rot
    else:
        # Zero rotation for axel
        hammer_axel.rotation.x = 0


func on_weapon_updated(weapon: WeaponResource) -> void:
    supported_ammo = weapon.get_supported_ammunition()
    mixed_reserve = weapon.get_mixed_reserve()
    is_fanning = weapon.alt_mode

    if weapon is RevolverWeapon:
        cylinder_position = weapon._cylinder_position
        cylinder_ammo_state = weapon._cylinder_ammo_state
        cocked = weapon.hammer_cocked
    else:
        cylinder_position = 0
        cylinder_ammo_state = []
        cylinder_ammo_state.resize(PORTS)
        cylinder_ammo_state.fill(0)
        cocked = false

    update_ports()
    update_cylinder_spin()
    update_hammer()

func rotate_cylinder(duration: float, apply_on_end: bool, places: int) -> void:
    apply_rotate_cylinder()

    cylinder_apply_on_finish = apply_on_end
    cylinder_interp.reset(0.0)
    cylinder_interp.set_target_delta(float(places), float(places), 0.0)
    cylinder_interp.duration = duration

func apply_rotate_cylinder() -> void:
    if not cylinder_apply_on_finish:
        return

    cylinder_apply_on_finish = false
    cylinder_rotated.emit(roundi(cylinder_interp.target))
    cylinder_interp.reset(0.0)
