@tool

## Resource for loading dynamic sounds. Must be an OGG Vorbis file.
class_name SoundResource extends Resource

## File resoure path to the audio stream to load
@export_file("*.ogg")
var file: String

## Base volume for playback. Can be varied with randomization parameters.
@export_range(-10.0, 10.0, 0.001, 'suffix:dB', 'or_less', 'or_greater')
var base_volume: float = 0.0

## Base pitch for playback. Can be varied with randomization parameters.
@export_range(0.001, 4.0, 0.001, 'or_greater')
var base_pitch_scale: float = 1.0

## Base PLAYBACK offset in milliseconds. Can be varied with randomization
## parameters. THIS IS NOT A DELAY! Sounds must be rendered with leading silence!
## If the randomized offset goes after leading silence, sounds will clip in and
## probably not sound good.
@export_range(0.0, 100.0, 0.01, 'suffix:ms', 'or_greater')
var base_offset_ms: float = 0.0


@export_group("Volume Randomization", "volume")

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


var _stream: AudioStreamOggVorbis
func get_stream() -> AudioStreamOggVorbis:
    if not file:
        return null

    if not _stream:
        _stream = AudioStreamOggVorbis.load_from_file(file)

    return _stream

## Obtain a randomized volume level for this sound
func get_volume() -> float:
    return distribute(
            base_volume,
            volume_relative_min,
            volume_relative_max,
            volume_distribution
    )

## Obtain a randomized pitch scale for this sound
func get_pitch() -> float:
    return max(0.01, distribute(
            base_pitch_scale,
            pitch_relative_min,
            pitch_relative_max,
            pitch_distribution
    ))

## Obtain a randomized offset for this sound
func get_offset_seconds() -> float:
    return max(0.0, distribute(
            base_offset_ms,
            offset_relative_min,
            offset_relative_max,
            offset_distribution
    ) / 1000.0)

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
