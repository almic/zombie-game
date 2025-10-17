# HACK: Tool is needed to hide the `file` value
@tool
## A special sound resource that contains named sound layers. Must be extended.
class_name SoundResourceLayered extends SoundResource


## Sound resources to layer together
@export var sounds: Array[SoundResource]:
    get = get_sounds


## Hides the `file` export from the inspector and disables storage
func _validate_property(property: Dictionary) -> void:
    if property.name == 'file':
        property.usage = PROPERTY_USAGE_NONE


func get_sounds() -> Array[SoundResource]:
    if not sounds:
        sounds = []
    return sounds


func load_stream() -> AudioStreamOggVorbis:
    push_error('Cannot call "load_stream()" on SoundResourceLayered!')
    return null

## Queues the audio stream to load asynchronously. Returns `true` if the audio
## stream is already loaded.
func load_stream_async() -> bool:
    push_error('Cannot call "load_stream_async()" on SoundResourceLayered!')
    return false

## Unloads the stream
func unload_stream() -> void:
    push_error('Cannot call "unload_stream()" on SoundResourceLayered!')

## Get the audio stream, returns null if not loaded
func get_stream() -> AudioStreamOggVorbis:
    push_error('Cannot call "get_stream()" on SoundResourceLayered!')
    return null

## Check if the audio stream has loaded. Must be called if using `load_stream_async()`
## in order for async load requests to be queried.
func is_stream_ready() -> bool:
    push_error('Cannot call "is_stream_ready()" on SoundResourceLayered!')
    return false

## Compute the loudness of all layers
func get_loudness() -> float:
    var max_loudness: float = -1000.0

    for sound in sounds:
        max_loudness = maxf(max_loudness, sound.get_loudness())

    return linear_to_db(
              db_to_linear(base_volume)
            * db_to_linear(loudness)
            * db_to_linear(max_loudness)
    )
