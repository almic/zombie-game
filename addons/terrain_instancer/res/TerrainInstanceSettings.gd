@tool
class_name TerrainInstanceSettings extends Resource


signal on_randomize(type: StringName)


## The main matching mesh asset ID of the terrain asset
@export_range(-1, 10, 1, 'or_greater')
var id: int = -1

## The mesh asset ID weights of this instance group. Can be used to place variations of the
## primary asset. When populating, existing assets with these IDs are mapped to the primary ID.
@export_custom(
    PROPERTY_HINT_DICTIONARY_TYPE,
    "2/1:0,10,1,or_greater;2/1:0,10,1,or_greater"
)
var ids: Dictionary[int, int]

@export var enabled: bool = true

@export var seed: int

@export_tool_button('Randomize Seed', 'RandomNumberGenerator')
var btn_randomize_seed = func():
    randomize()
    seed = randi()

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

#region Variation Settings
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

#endregion

@export_group('Slope Fixing', 'slope_fix')

## Offsets the height of the instance using the slope and the base radius to
## reduce the likelihood of the asset "floating" off the terrain. It is important
## that the base radius be accurate. If placing on extreme terrain, set a limit
## to prevent instances from disappearing into the ground.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, 'checkbox_only')
var slope_fix_enabled: bool = false

## Radius of the base of the instance for slope fixing at normal scale. If the
## instance used scaling variation, this will be scaled appropriately.
@export_range(0.0, 3.0, 0.001, 'or_greater')
var slope_fix_base_radius: float = 0.0

## Maximum lowering allowed. Useful only when instances are placed on extreme
## slopes, while being wide but short, to prevent being fully obscured.
@export_range(0.0, 2.0, 0.001, 'or_greater')
var slope_fix_limit: float = 0.0

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
    if _parent:
        return true
    return false

func _property_get_revert(property: StringName) -> Variant:
    if _parent:
        if property == &'v_colors':
            return _parent.v_colors.duplicate_deep(DeepDuplicateMode.DEEP_DUPLICATE_ALL)
        return _parent.get(property)
    if property == &'v_colors':
        return v_colors # Do not allow reverting colors...
    return null

func rand_id(rng: RandomNumberGenerator) -> int:
    var result: int = _vary_id(rng, ids)
    if result != -1:
        return result
    return id

func rand_color(rng: RandomNumberGenerator) -> Color:
    return _vary_color(rng, v_colors)

func rand_height(rng: RandomNumberGenerator) -> float:
    return _vary(rng, v_height_offset, v_height_low, v_height_high, v_height_deviation)

func rand_spin(rng: RandomNumberGenerator) -> float:
    return _vary(rng, v_spin_offset, v_spin_low, v_spin_high, v_spin_deviation)

func rand_tilt(rng: RandomNumberGenerator) -> float:
    return _vary(rng, v_tilt_offset, v_tilt_low, v_tilt_high, v_tilt_deviation)

func rand_scale(rng: RandomNumberGenerator) -> float:
    return _vary(rng, v_scale_multiplier, v_scale_low * v_scale_multiplier, v_scale_high, v_scale_deviation)

static func _vary(rng: RandomNumberGenerator, base: float, low: float, high: float, d: float) -> float:
    if is_zero_approx(low) and is_zero_approx(high):
        if is_zero_approx(d):
            return base

        return rng.randfn(base, d)

    if is_zero_approx(d):
        return rng.randf_range(base - low, base + high)

    return clampf(rng.randfn(base, d), base - low, base + high)

static func _vary_id(rng: RandomNumberGenerator, ids: Dictionary[int, int]) -> int:
    print(ids)
    var max_ticket: int = 0
    for id in ids:
        max_ticket += ids.get(id)

    if max_ticket < 1:
        return -1

    var ticket: int = rng.randi_range(1, max_ticket)
    for id in ids:
        ticket -= ids.get(id)
        if ticket <= 0:
            return id

    return -1

static func _vary_color(rng: RandomNumberGenerator, colors: Array[TerrainInstanceColorSettings]) -> Color:
    # Compute ticket range
    var max_ticket: int = 0
    for choice in colors:
        max_ticket += choice.weight

    if max_ticket < 1:
        return Color.WHITE

    var ticket: int = rng.randi_range(1, max_ticket)
    var color_setting: TerrainInstanceColorSettings
    for choice in colors:
        ticket -= choice.weight
        if ticket <= 0:
            color_setting = choice
            break

    if not color_setting:
        # Make it clear this was an error
        return Color.PURPLE

    var color: Color = color_setting.color
    var h: float = color.ok_hsl_h
    var s: float = color.ok_hsl_s
    var l: float = color.ok_hsl_l

    if not is_zero_approx(color_setting.hue_deviation):
        h += clampf(
                rng.randfn(0.0, color_setting.hue_deviation),
                -color_setting.hue_variation,
                 color_setting.hue_variation,
        )
    else:
        h += rng.randf_range(
                -color_setting.hue_variation,
                 color_setting.hue_variation
        )

    if not is_zero_approx(color_setting.lit_deviation):
        l += clampf(
                rng.randfn(0.0, color_setting.lit_deviation),
                -color_setting.lit_variation,
                 color_setting.lit_variation,
        )
    else:
        l += rng.randf_range(
                -color_setting.lit_variation,
                 color_setting.lit_variation
        )

    if not is_zero_approx(color_setting.sat_deviation):
        s += clampf(
                rng.randfn(0.0, color_setting.sat_deviation),
                -color_setting.sat_variation,
                 color_setting.sat_variation,
        )
    else:
        s += rng.randf_range(
                -color_setting.sat_variation,
                 color_setting.sat_variation
        )

    return Color.from_ok_hsl(h, s, l)
