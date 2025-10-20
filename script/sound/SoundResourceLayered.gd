# HACK: Tool is needed to hide export values
@tool
## A special sound resource that contains named sound layers. Must be extended.
class_name SoundResourceLayered extends SoundResource


## Sound resources to layer together
@export var sounds: Array[SoundResource]:
    get = get_sounds


## Hide certain exports from the inspector and disable storage
func _validate_property(property: Dictionary) -> void:
    const hidden = [
            'file',
            'base_volume',
            'base_pitch_scale',
            'loudness',
            'can_overlap',
    ]

    if property.name in hidden:
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
