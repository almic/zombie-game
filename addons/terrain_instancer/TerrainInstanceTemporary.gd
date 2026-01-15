extends Node3D


@export var instance_id: int = -1:
    set = set_instance_id

@export_color_no_alpha
var instance_color: Color = Color.WHITE:
    set(value):
        instance_color = value
        update_mesh_colors()

var instance_position: Vector3 = Vector3.ZERO:
    set(value):
        instance_position = value
        queue_update_transform()

var instance_height: float = 0.0:
    set(value):
        instance_height = value
        queue_update_transform()

var instance_spin: float = 0.0:
    set(value):
        instance_spin = value
        queue_update_transform()

var _tilt_axis_spin: float = 0.0
var instance_tilt: float = 0.0:
    set(value):
        instance_tilt = value
        queue_update_transform()

var instance_scale: float = 1.0:
    set(value):
        instance_scale = value
        queue_update_transform()


var region: TerrainInstanceRegion:
    set = set_region

var mesh_instance: MeshInstance3D
var is_id_valid: bool = false

var original_colors: PackedColorArray

var _queued_transform: bool = false


func _init() -> void:
    mesh_instance = MeshInstance3D.new()
    add_child(mesh_instance, false, Node.INTERNAL_MODE_FRONT)

func _ready() -> void:
    if not region:
        push_error('Instance temporary added to scene without a region, please fix!')
        update_configuration_warnings()
        return

    is_id_valid = validate_instance_id(instance_id)
    if is_id_valid:
        update_instance_mesh()
    update_configuration_warnings()

func _validate_property(property: Dictionary) -> void:
    if property.name != 'instance_id':
        return

    if not region:
        return

    property.hint = PROPERTY_HINT_ENUM
    var hint_str: String = ''
    for option in region.settings.instances:
        if not hint_str.is_empty():
            hint_str += ','
        hint_str += '%s:%d' % [
                region.instance_node.get_instance_name(option.id),
                option.id
        ]
    property.hint_string = hint_str
    property.usage = PROPERTY_USAGE_EDITOR

func _get_configuration_warnings() -> PackedStringArray:
    var warns: PackedStringArray
    if not region:
        warns.append('No valid region assigned, please move this node to a region or delete it!')
    if not is_id_valid:
        warns.append('Instance ID %d is not in the region settings' % instance_id)
    return warns

func set_region(new_region: TerrainInstanceRegion) -> void:
    region = new_region
    is_id_valid = validate_instance_id(instance_id)

    notify_property_list_changed()
    update_configuration_warnings()

func set_instance_id(id: int) -> void:
    if not region:
        instance_id = id
        is_id_valid = false
        return

    notify_property_list_changed()

    is_id_valid = validate_instance_id(id)
    if not is_id_valid:
        update_configuration_warnings()
        return

    instance_id = id
    update_configuration_warnings()
    update_instance_mesh()

func validate_instance_id(id: int) -> bool:
    if (not region) or (not region.settings):
        return false

    for option in region.settings.instances:
        if option.id == id:
            return true

    return false

func update_instance_mesh() -> void:
    if not is_inside_tree():
        return
    mesh_instance.mesh = region.instance_node.get_instance_lod_mesh(instance_id).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
    update_mesh_colors()

func update_mesh_colors() -> void:
    var mat: Material = mesh_instance.mesh.surface_get_material(0)
    if mat is BaseMaterial3D:
        mat.albedo_color = instance_color
    elif mat is ShaderMaterial:
        mat.set_shader_parameter(&'instance_color', instance_color)

func rand_tilt_axis() -> void:
    _tilt_axis_spin = randf() * TAU

func queue_update_transform() -> void:
    _queued_transform = true
    _update_transform.call_deferred()

func _update_transform() -> void:
    if not _queued_transform:
        return
    _queued_transform = false

    if not is_inside_tree():
        return

    global_position = instance_position
    global_position.y += instance_height

    var new_basis: Basis = Basis.IDENTITY
    new_basis = new_basis.rotated(Vector3.FORWARD.rotated(Vector3.UP, _tilt_axis_spin), instance_tilt)
    new_basis = new_basis.rotated(Vector3.DOWN, instance_spin)
    new_basis = new_basis.scaled(Vector3(instance_scale, instance_scale, instance_scale))

    global_basis = new_basis
