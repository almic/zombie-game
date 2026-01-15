extends Node3D


@export var instance_id: int = -1:
    set = set_instance_id

@export_color_no_alpha
var instance_color: Color = Color.WHITE:
    set(value):
        instance_color = value
        if is_inside_tree():
            update_mesh_colors()

var instance_position: Vector3 = Vector3.ZERO:
    set(value):
        instance_position = value
        if is_inside_tree():
            global_position = instance_position
            global_position.y += instance_height
var instance_height: float = 0.0:
    set(value):
        instance_height = value
        if is_inside_tree():
            global_position = instance_position
            global_position.y += instance_height


var region: TerrainInstanceRegion:
    set = set_region

var mesh_instance: MeshInstance3D
var is_id_valid: bool = false

var original_colors: PackedColorArray


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
    mesh_instance.mesh = region.instance_node.get_instance_lod_mesh(instance_id).duplicate()
    update_mesh_colors()

func update_mesh_colors() -> void:
    # TODO: figure out how to do this
    pass
