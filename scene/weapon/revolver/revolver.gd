
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

var _rotate_loop_start_time: float = -1


func _rotate_loop_start() -> void:
    _rotate_loop_start_time = anim_state.get_current_play_position()
    update_ports(false)

func _reload_loop_start() -> void:
    super._reload_loop_start()
    reload_marker.visible = true
    _before_rotate_counter_clockwise()
    update_ports(false)

func _reload_loop_end() -> void:
    revolver.rotate_cylinder(-1)
    super._reload_loop_end()

func _emit_fired() -> void:
    if not is_round_live:
        revolver._hammer_cocked = false
        revolver.rotate_cylinder(1)
        revolver.trigger_mechanism.start_cycle()
        return
    super._emit_fired()

func _emit_round_loaded() -> void:
    super._emit_round_loaded()
    reload_marker.visible = false
    update_ports(false)

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
    var supported: Dictionary = revolver.get_supported_ammunition()
    for i in range(PORTS):
        pos = wrapi(i + start + revolver._cylinder_position, 0, PORTS)
        type = revolver._mixed_reserve[pos]
        if not type or revolver._cylinder_ammo_state[pos]:
            continue

        pos = wrapi(i + start, 0, PORTS)
        port = ports[pos]
        for child in port.get_children():
            port.remove_child(child)
            child.queue_free()

        ammo = supported.get(type) as AmmoResource
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
        travel(FIRE_DOUBLE)
    return true

func goto_reload_continue() -> bool:
    if not is_state(RELOAD):
        return false


    var next_pos: int = wrapi(revolver._cylinder_position - 1, 0, PORTS)
    if revolver._mixed_reserve[next_pos] > 0:
        if _reload_loop_start_time >= 0:
            seek(_rotate_loop_start_time)
            return true
        return false

    if _reload_loop_start_time >= 0:
        seek(_reload_loop_start_time)
        return true

    return false

func set_revolver(revolver_weapon: RevolverWeapon) -> void:
    if revolver:
        revolver.fired.disconnect(on_fired)

    revolver = revolver_weapon
    revolver_ammo = revolver.get_supported_ammunition()
    revolver.fired.connect(on_fired)

    update_ports()


func update_ports(skip_next_rotate: bool = true) -> void:
    _skip_next_rotate = skip_next_rotate

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
    var port: Marker3D
    for i in range(PORTS):
        target_port = ports[wrapi(i + direction, 0, PORTS)]
        port = ports[i]
        var child: Node
        if port.get_child_count() > 0:
            child = port.get_child(0)
        if not child:
            # Empty port
            continue
        ports[i].remove_child(child)

        # Add sibling keeps the new child ordered AFTER the sibling
        var sibling: Node
        if target_port.get_child_count() > 0:
            sibling = target_port.get_child(0)

        if sibling:
            sibling.add_sibling(child)
        else:
            target_port.add_child(child)
