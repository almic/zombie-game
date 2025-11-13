## A resource type that specifies a parent and overrides properties from the
## parent.
@tool
class_name BehaviorExtendedResource extends Resource


## The base of this resource. When created, copies all property values from the
## base that are not overwritten here.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var base: BehaviorExtendedResource

## Maps overwritten properties to their values.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var base_overrides: Dictionary

## Cache of the properties that can be overridden by this resource
var base_properties: Array[StringName]


## Must be called to properly initialize the resource properties from its base.
## It is safe to call this when no base is defined.
func _on_load(path: String) -> void:
    # print('_on_load called for "%s" at path "%s"' % [resource_name, path])
    base_properties = []
    var writing_cache: bool = false
    var script_path: String = (get_script() as Script).resource_path
    for prop in get_property_list():
        if writing_cache:
            if prop.name == 'base':
                break

            if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
                continue

            if prop.usage & PROPERTY_USAGE_STORAGE == 0:
                continue

            base_properties.append(prop.name)
            # print(prop)
        elif prop.usage & PROPERTY_USAGE_CATEGORY > 0 and prop.hint_string == script_path:
            writing_cache = true

    # Run set method which does some validation
    set_base(base)
    set_overrides(base_overrides)

func set_base(new_base: BehaviorExtendedResource) -> void:
    if new_base == null:
        base = null
        return

    # Base must be of the same class_name
    var my_name: StringName = get_script().resource_path
    var base_name: StringName = new_base.get_script().resource_path
    if base_name != my_name:
        push_error('Cannot set a base type "%s" for my type "%s"! Base must be the same type!' % [base_name, my_name])
        return

    base = new_base

func set_overrides(overrides: Dictionary) -> void:
    # Check that all overrides are real property names
    for prop in overrides:
        if not base_properties.has(prop):
            push_error('Unknown property name "%s" in base_overrides. Manual fix required!')
            return

    base_overrides = overrides

func override(name: StringName, value: Variant) -> void:
    if value == null:
        print('deleting override: ' + name)
        base_overrides.erase(name)
        return

    print('setting override "%s" = %s' % [name, str(value)])
    base_overrides.set(name, value)

# NOTE: This method favors anything present in 'base_overrides', even if it is
#       not a real property or this has no base.
func _get(property: StringName) -> Variant:
    if base_overrides.has(property):
        return base_overrides.get(property)

    if base and base_properties.has(property):
        return base.get(property)

    return null

# NOTE: This method simply checks if a property should be added to the override
#       set, it will always return false so that default behavior is not lost.
func _set(property: StringName, value: Variant) -> bool:
    # Check for override property
    if base_properties.has(property):
        if base:
            override(property, value)
            emit_changed()
            return true
        emit_changed.call_deferred()
    return false

## Returns the property info from 'get_property_list()'
func get_property_info(property_name: StringName) -> Dictionary:
    for prop in get_property_list():
        if prop.name == property_name:
            return prop

    push_error('Cannot get property info for "%s" because it was not in the property list!' % property_name)
    return {}

## Returns true if the resource path points to a sub_resource defined by another
func is_sub_resource() -> bool:
    if resource_scene_unique_id.is_empty():
        return false
    return resource_path.ends_with(resource_scene_unique_id)

static func get_script_from_name(name: StringName) -> GDScript:
    for clss in ProjectSettings.get_global_class_list():
        if clss.class != name:
            continue
        if clss.path.is_empty():
            push_error('Class "%s" has no path?' % name)
            return null
        var script: GDScript = ResourceLoader.load(clss.path) as GDScript
        if not script:
            push_error('Failed to load class "%s" from "%s" as GDScript type!' % [name, clss.path])
            return null
        return script
    return null
