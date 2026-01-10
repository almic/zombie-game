@tool
class_name TerrainInstanceColorSettings extends Resource


## Relative probability within this color group
@export_range(1, 10, 1, 'or_greater', 'hide_slider')
var weight: int = 1

## Color modulation, white means no color change
@export_color_no_alpha
var color: Color = Color.WHITE:
    set(value):
        color = value
        _update_previews()


@export_group('Hue', 'hue')

## How far the hue can change from the base color value
@export_range(0.0, 0.01, 0.0001, 'or_greater')
var hue_variation: float = 0.0:
    set(value):
        hue_variation = value
        _update_previews(&'hue')

## Hue deviation, set to be non-zero to use a normal distribution.
## Higher values result in extreme hues more often.
## Zero will use a linear distribution.
@export_range(0.0, 0.05, 0.0001, 'or_greater')
var hue_deviation: float = 0.0:
    set(value):
        hue_deviation = value
        _update_previews(&'hue')

## Preview of the maximum hue variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var hue_preview_max: Color

## Preview of the maximum hue variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var hue_preview_min: Color


@export_group('Lightness', 'lit')

## How far the lightness can change from the base color value
@export_range(0.0, 0.1, 0.0001, 'or_greater')
var lit_variation: float = 0.0:
    set(value):
        lit_variation = value
        _update_previews(&'lightness')

## Lightness deviation, set to be non-zero to use a normal distribution.
## Higher values result in extreme values more often.
## Zero will use a linear distribution.
@export_range(0.0, 0.2, 0.0001, 'or_greater')
var lit_deviation: float = 0.0:
    set(value):
        lit_deviation = value
        _update_previews(&'lightness')

## Preview of the maximum lightness variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var lit_preview_max: Color

## Preview of the maximum lightness variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var lit_preview_min: Color


@export_group('Saturation', 'sat')

## How far the saturation can change from the base color value
@export_range(0.0, 0.1, 0.0001, 'or_greater')
var sat_variation: float = 0.0:
    set(value):
        sat_variation = value
        _update_previews(&'saturation')

## Saturation deviation, set to be non-zero to use a normal distribution.
## Higher values result in extreme colors more often.
## Zero will use a linear distribution.
@export_range(0.0, 0.2, 0.0001, 'or_greater')
var sat_deviation: float = 0.0:
    set(value):
        sat_deviation = value
        _update_previews(&'saturation')

## Preview of the maximum saturation variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var sat_preview_max: Color

## Preview of the maximum saturation variation
@export_custom(PROPERTY_HINT_COLOR_NO_ALPHA, '', PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var sat_preview_min: Color


func _update_previews(type: StringName = &'all') -> void:
    if not Engine.is_editor_hint():
        return

    var do_hue: bool = false
    var do_lit: bool = false
    var do_sat: bool = false

    if type == &'all':
        do_hue = true
        do_lit = true
        do_sat = true
    elif type == &'hue':
        do_hue = true
    elif type == &'lightness':
        do_lit = true
    elif type == &'saturation':
        do_sat = true

    if do_hue:
        hue_preview_max = color
        hue_preview_min = color
        hue_preview_max.ok_hsl_h += hue_variation
        hue_preview_min.ok_hsl_h -= hue_variation
    if do_lit:
        lit_preview_max = color
        lit_preview_min = color
        lit_preview_max.ok_hsl_l = minf(sat_preview_max.ok_hsl_l + lit_variation, 1.0)
        lit_preview_min.ok_hsl_l = maxf(sat_preview_max.ok_hsl_l - lit_variation, 0.0)
    if do_sat:
        sat_preview_max = color
        sat_preview_min = color
        sat_preview_max.ok_hsl_s = minf(sat_preview_max.ok_hsl_s + sat_variation, 1.0)
        sat_preview_min.ok_hsl_s = maxf(sat_preview_min.ok_hsl_s - sat_variation, 0.0)
