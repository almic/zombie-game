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


## Must be called to properly initialize the resource properties from its base.
## It is safe to call this when no base is defined.
func _on_load(path: String) -> void:
    # print('_on_load called for "%s" at path "%s"' % [resource_name, path])

    if not base:
        return

    # Run set method which does some validation
    set_base(base)
    set_overrides(base_overrides)

    # Copy values from base, set values from override
    var props: Array[Dictionary] = base.get_property_list()

    for prop in props:
        # Ignore these properties
        if prop.name == &'base' or prop.name == &'base_overrides':
            continue

        # Keep our values if they are overwritten
        if base_overrides.has(prop.name):
            set(prop.name, base_overrides.get(prop.name))
            continue

        set(prop.name, base.get(prop.name))

func set_base(new_base: BehaviorExtendedResource) -> void:
    if new_base == null:
        base = null
        return

    if new_base == base:
        return

    # Base must be of the same class_name
    var my_name: StringName = get_script().resource_path
    var base_name: StringName = new_base.get_script().resource_path
    if base_name != my_name:
        push_error('Cannot set a base type "%s" for my type "%s"! Base must be the same type!' % [base_name, my_name])
        return

    base = new_base
    _on_load(resource_path)


func set_overrides(overrides: Dictionary) -> void:
    # Check that all overrides are real property names
    var my_props: Array[Dictionary] = get_property_list()
    var my_prop_names: Array[StringName] = []
    var count: int = my_props.size()
    my_prop_names.resize(count)
    for i in range(count):
        my_prop_names[i] = my_props[i].name
        i += 1

    for prop in overrides:
        if not my_prop_names.has(prop):
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


func _set(property: StringName, value: Variant) -> bool:
    const extended_type = &'BehaviorExtendedResource'
    if not base:
        return false

    # Check for override property
    for prop in get_property_list():
        # NOTE: everything from 'base' onward is to be ignored
        if prop.class_name == extended_type:
            return false

        if prop.name != property:
            continue

        if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
            return false

        if prop.usage & PROPERTY_USAGE_STORAGE == 0:
            return false

        override(property, value)
        break

    return false


## Returns the property info from 'get_property_list()'
func get_property_info(property_name: StringName) -> Dictionary:
    for prop in get_property_list():
        if prop.name == property_name:
            return prop

    push_error('Cannot get property info for "%s" because it was not in the property list!' % property_name)
    return {}
