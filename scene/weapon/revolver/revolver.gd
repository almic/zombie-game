
## Special scene just for the revolver
class_name RevolverWeaponScene extends WeaponScene

const PORTS = 6
const FIRE_DOUBLE = &'fire_double'
const FIRE_EMPTY = &'fire_empty'
const SET_CYLINDER = &'set_cylinder'


@onready var ports: Array[Marker3D] = [
    %Port1Marker,
    %Port2Marker,
    %Port3Marker,
    %Port4Marker,
    %Port5Marker,
    %Port6Marker,
]


var revolver: RevolverWeapon:
    set = set_revolver

var revolver_ammo: Dictionary

var cocked: bool:
    get(): return revolver._hammer_cocked

var is_round_live: bool:
    get(): return revolver.is_round_live()

var _skip_next_rotate: bool = false


func _emit_fired() -> void:
    if not is_round_live:
        revolver._hammer_cocked = false
        revolver.rotate_cylinder(1)
        revolver.trigger_mechanism.start_cycle()
        return
    super._emit_fired()


func can_aim() -> bool:
    var state: StringName = anim_state.get_current_node()
    return (
           state == WALK
        or state == IDLE
        or state == FIRE
        or state == CHARGE
        or state == FIRE_DOUBLE
        or state == FIRE_EMPTY
        or state == SET_CYLINDER
    )


func goto_fire() -> bool:
    if not is_idle():
        return false

    if cocked:
        if is_round_live:
            travel(FIRE)
        else:
            travel(FIRE_EMPTY)
    else:
        var current: StringName = anim_state.get_current_node()
        travel(FIRE_DOUBLE)
    return true


func set_revolver(revolver_weapon: RevolverWeapon) -> void:
    if revolver:
        revolver.fired.disconnect(on_fired)

    revolver = revolver_weapon
    revolver_ammo = revolver.get_supported_ammunition()
    revolver.fired.connect(on_fired)

    update_ports()


func update_ports() -> void:
    _skip_next_rotate = true

    var reserve: PackedInt32Array = revolver.get_mixed_reserve()
    var type: int
    var ammo: AmmoResource
    var pos: int
    for i in range(PORTS):
        # NOTE: read reserve from cylinder position
        pos = wrapi(i + revolver._cylinder_position, 0, PORTS)

        # A port would only have 1 child for the mesh scene
        for child in ports[i].get_children():
            ports[i].remove_child(child)
            child.queue_free()
            break

        type = reserve[pos]
        if not type:
            # Empty port (type == 0)
            continue

        ammo = revolver_ammo.get(type) as AmmoResource

        var node: Node3D
        if revolver._cylinder_ammo_state[pos]:
            node = ammo.scene_round.instantiate() as Node3D
        else:
            node = ammo.scene_round_expended.instantiate() as Node3D
            # NOTE: likely a RigidBody, so just disable this
            node.process_mode = Node.PROCESS_MODE_DISABLED

        ports[i].add_child(node)

func on_fired() -> void:
    revolver._cylinder_ammo_state[revolver._cylinder_position] = 0
    revolver._hammer_cocked = false
    revolver.rotate_cylinder(1)

func _before_rotate_clockwise() -> void:
    _before_rotate(-1)

func _before_rotate_counter_clockwise() -> void:
    _before_rotate(1)

func _before_rotate(direction: int) -> void:
    if _skip_next_rotate:
        _skip_next_rotate = false
        return

    var target_port: Marker3D
    for i in range(PORTS):
        target_port = ports[wrapi(i + direction, 0, PORTS)]
        var child: Node = ports[i].get_child(0)
        if not child:
            # Empty port
            continue
        ports[i].remove_child(child)

        # Add sibling keeps the new child ordered AFTER the sibling
        var sibling: Node = target_port.get_child(0)
        if sibling:
            sibling.add_sibling(child)
        else:
            target_port.add_child(child)
