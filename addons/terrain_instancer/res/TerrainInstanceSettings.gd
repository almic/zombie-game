@tool
class_name TerrainInstanceSettings extends Resource


signal on_randomize(type: StringName)


@export_range(-1, 10, 1, 'or_greater')
var id: int = -1

@export var enabled: bool = true

## Expected count per 256 sq. meters, or 16x16 meter area
@export_range(0.01, 10.0, 0.01, 'or_greater')
var density: float = 1.0

## Standard deviation in density, used to randomly seed areas with slightly
## more or less instances
@export_range(0.01, 10.0, 0.01, 'or_greater')
var density_deviation: float = 2.0

## Density reduction according to local slope for instances. This acts as an
## additional probability function, and can only reduce the density. If you want
## to have "higher" densities at certain slopes, you must increase the base
## density and modify the curve appropriately.
@export
var density_slope: Curve

@export_custom(
    PROPERTY_HINT_DICTIONARY_TYPE,
    '2/1:-1,10,1,or_greater;3/1:0.1,10.0,0.1,or_greater'
)
var minimum_distances: Dictionary


@export_group('Variation')


@export_subgroup('Color', 'v')

@export var v_colors: Array[TerrainInstanceColorSettings]


@export_subgroup('Height', 'v_height')

## Base height offset
@export_range(-1.0, 1.0, 0.01, 'or_less', 'or_greater')
var v_height_offset: float = 0.0

## Low bound, how far below the height offset the instance can be
@export_range(0.0, 1.0, 0.01, 'or_greater')
var v_height_low: float = 0.0

## High bound, how far above the height offset the instance can be
@export_range(0.0, 1.0, 0.01, 'or_greater')
var v_height_high: float = 0.0

## Height deviation, set to be non-zero to use a normal distribution, bound
## by the high/ low settings. Zero will use a linear distribution.
@export_range(0.0, 10.0, 0.01, 'or_greater')
var v_height_deviation: float = 0.0


@export_subgroup('Spin', 'v_spin')

## Base spin (Y-axis) offset
@export_range(-180.0, 180.0, 0.01, 'or_less', 'or_greater', 'radians_as_degrees')
var v_spin_offset: float = 0.0

## Low spin bound, how far counter-clockwise from the base spin the instance can be
@export_range(0.0, 360.0, 1.0, 'or_greater', 'radians_as_degrees')
var v_spin_low: float = 0.0

## High spin bound, how far clockwise from the base spin the instance can be
@export_range(0.0, 360.0, 1.0, 'or_greater', 'radians_as_degrees')
var v_spin_high: float = 0.0

## Spin deviation, set to be non-zero to use a normal distribution, bound
## by the high/ low settings. Zero will use a linear distribution.
@export_range(0.0, 15.0, 0.1, 'or_greater', 'radians_as_degrees')
var v_spin_deviation: float = 0.0


@export_subgroup('Tilt', 'v_tilt')

## Base tilt (XZ-axis) offset
@export_range(-180.0, 180.0, 0.01, 'or_less', 'or_greater', 'radians_as_degrees')
var v_tilt_offset: float = 0.0

## Low tilt bound, how far back from the base tilt the instance can be
@export_range(0.0, 360.0, 1.0, 'or_greater', 'radians_as_degrees')
var v_tilt_low: float = 0.0

## High spin bound, how far into the base tilt the instance can be
@export_range(0.0, 360.0, 1.0, 'or_greater', 'radians_as_degrees')
var v_tilt_high: float = 0.0

## Tilt deviation, set to be non-zero to use a normal distribution, bound
## by the high/ low settings. Zero will use a linear distribution.
@export_range(0.0, 15.0, 0.1, 'or_greater', 'radians_as_degrees')
var v_tilt_deviation: float = 0.0


@export_subgroup('Scale', 'v_scale')

## Base scale
@export_range(0.01, 2.0, 0.01, 'or_greater')
var v_scale_multiplier: float = 1.0

## Low scale bound, how much smaller, as a percentage of the base scale, the instance can be
@export_range(0.0, 0.999, 0.01)
var v_scale_low: float = 0.0

## High scale bound, how much larger, added to the base scale, the instance can be
@export_range(0.0, 1.0, 0.01, 'or_greater')
var v_scale_high: float = 0.0

## Scale deviation, set to be non-zero to use a normal distribution, bound
## by the high/ low settings. Zero will use a linear distribution.
@export_range(0.0, 1.0, 0.01, 'or_greater')
var v_scale_deviation: float = 0.0


var _parent: TerrainInstanceSettings = null


func _validate_property(property: Dictionary) -> void:
    if not _parent:
        return

    # Hidden properties when used by the add instance tool
    if (
           property.name == 'id'
        or property.name == 'enabled'
        or property.name == 'density'
        or property.name == 'density_deviation'
        or property.name == 'density_slope'
        or property.name == 'minimum_distances'
        # hide the main variation group from this editor
        or property.name == 'Variation'
        # hide the resource values
        or property.name == 'resource_local_to_scene'
        or property.name == 'resource_path'
        or property.name == 'resource_name'
    ):
        property.usage = PROPERTY_USAGE_NONE


func _property_can_revert(property: StringName) -> bool:
    if (
           property == &'id'
        or property == &'enabled'
        or property == &'density_slope'
    ):
        return false

    return true

func _property_get_revert(property: StringName) -> Variant:
    if _parent:
        if property == &'v_colors':
            return _parent.v_colors.duplicate_deep(DeepDuplicateMode.DEEP_DUPLICATE_ALL)
        return _parent.get(property)
    if property == &'v_colors':
        return v_colors # Do not allow reverting colors...
    return null
