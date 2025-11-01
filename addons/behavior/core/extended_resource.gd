## A resource type that specifies a parent and overrides properties from the
## parent.
class_name BehaviorExtendedResource extends Resource


## The base of this resource. When created, copies all property values from the
## base that are not overwritten here.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var base: BehaviorExtendedResource:
    set = set_base


## Maps overwritten properties to their values.
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var base_overrides: Dictionary:
    set = set_overrides


## If this resource had 'init_from_base()' called on it.
var initialized: bool = false


## Must be called to properly initialize the resource properties from its base.
## It is safe to call this when no base is defined.
func init_from_base() -> void:
    initialized = true

    if not base:
        return

    # Ensure setters run which do some validation
    base = base
    base_overrides = base_overrides

    # Ensure base is initialized
    if not base.initialized:
        base.init_from_base()

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

    # Base must be of the same class_name
    var my_name: StringName = get_script().get_global_name()
    var base_name: StringName = new_base.get_script().get_global_name()
    if base_name != my_name:
        push_error('Cannot set a base type "%s" for my type "%s"! Base must be the same type!' % [base_name, my_name])
        return

    base = new_base


func set_overrides(overrides: Dictionary) -> void:
    # Check that all overrides are real property names
    var my_props: Array[Dictionary] = get_property_list()
    var my_prop_names: Array[StringName] = []
    my_prop_names.resize(my_props.size())
    var i: int = 0
    for prop in my_props:
        my_prop_names[i] = prop.name
        i += 1

    for prop in overrides:
        if not my_prop_names.has(prop):
            push_error('Unknown property name "%s" in base_overrides. Manual fix required!')
            return

    base_overrides = overrides
