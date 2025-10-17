## Resource for loading dynamic sounds. Must be an OGG Vorbis file.
class_name SoundResourceVariable extends SoundResource


## Base offset in milliseconds. THIS IS NOT A DELAY! Sounds must be rendered
## with leading silence for this to work correctly. If the randomized offset
## goes after leading silence, sounds will clip in and probably not sound good.
@export_range(0.0, 100.0, 0.01, 'suffix:ms', 'or_greater')
var base_offset_ms: float = 0.0


@export_group("Volume Randomization", "volume")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var volume_random_enabled: bool = false

## Distribution function.
@export_enum("Linear:0", "Normal:1")
var volume_distribution: int = 1

## Relative minimum, subtracted from the base to get an absolute value.
@export_range(-10.0, 0.0, 0.001, 'suffix:dB', 'or_less')
var volume_relative_min: float = 0.0

## Relative maximum, added from the base to get an absolute value. Must be
## greater than or equal to "Relative Min".
@export_range(0.0, 10.0, 0.001, 'suffix:dB', 'or_greater')
var volume_relative_max: float = 0.0


@export_group("Pitch Randomization", "pitch")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var pitch_random_enabled: bool = false

## Distribution function.
@export_enum("Linear:0", "Normal:1")
var pitch_distribution: int = 1

## Relative minimum, subtracted from the base to get an absolute value. Must be
## greater than the negation of the base pitch.
@export_range(-4.0, 0.0, 0.001, 'or_less')
var pitch_relative_min: float = 0.0

## Relative maximum, added from the base to get an absolute value.
@export_range(0.0, 4.0, 0.001, 'or_greater')
var pitch_relative_max: float = 0.0


@export_group("Offset Randomization", "offset")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var offset_random_enabled: bool = false

## Distribution function.
@export_enum("Linear:0", "Normal:1")
var offset_distribution: int = 1

## Relative minimum, subtracted from the base to get an absolute value. Must be
## greater than the negation of the offset.
@export_range(-100.0, 0.0, 0.01, 'suffix:ms', 'or_less')
var offset_relative_min: float = 0.0

## Relative maximum, added from the base to get an absolute value.
@export_range(0.0, 100.0, 0.01, 'suffix:ms', 'or_greater')
var offset_relative_max: float = 0.0


## Obtain a randomized volume level for this sound
func get_volume() -> float:
    var result: float
    if volume_random_enabled:
        result = distribute(
                base_volume,
                volume_relative_min,
                volume_relative_max,
                volume_distribution
        )
    else:
        result = base_volume
    return result

## Obtain a randomized pitch scale for this sound
func get_pitch() -> float:
    var result: float
    if pitch_random_enabled:
        result = distribute(
                base_pitch_scale,
                pitch_relative_min,
                pitch_relative_max,
                pitch_distribution
        )
    else:
        result = base_pitch_scale
    return maxf(0.01, result)

## Obtain a randomized offset for this sound
func get_offset_seconds() -> float:
    var result: float
    if offset_random_enabled:
        result = distribute(
                base_offset_ms,
                offset_relative_min,
                offset_relative_max,
                offset_distribution
        )
    else:
        result = base_offset_ms
    return maxf(0.0, result / 1000.0)

## Helper distribution function
func distribute(base: float, low: float, high: float, is_normal: bool) -> float:
    if is_zero_approx(low) and is_zero_approx(high):
        return base

    var weight: float
    if is_normal:
        # Values computed to give a smooth 99.83% distribution range
        weight = clampf(randfn(0.5, 1.0 / TAU), 0.0, 1.0)
    else:
        weight = randf()

    return lerpf(base + low, base + high, weight)
