## Basic sound resource, stores a single audio file with custom volume and pitch.
## Must be an OGG Vorbis file.
class_name SoundResource extends Resource

## File resoure path to the audio stream to load. Changing this while an audio
## stream is loaded will cause it to be unloaded.
@export_file("*.ogg")
var file: String:
    set(value):
        if file != value:
            unload_stream()
        file = value

## Default volume for playback
@export_range(-10.0, 10.0, 0.001, 'suffix:dB', 'or_less', 'or_greater')
var base_volume: float = 0.0

## Default pitch for playback
@export_range(0.001, 4.0, 0.001, 'or_greater')
var base_pitch_scale: float = 1.0


var _stream: AudioStreamOggVorbis
var _loading_async: bool = false


## Loads and returns the stream
func load_stream() -> AudioStreamOggVorbis:
    if not file:
        push_warning('Attempted to load an empty file from SoundResource!')
        return null

    if not _stream:
        _stream = AudioStreamOggVorbis.load_from_file(file)

    return _stream

## Queues the audio stream to load asynchronously. Returns `true` if the audio
## stream is already loaded.
func load_stream_async() -> bool:
    if not file:
        push_warning('Attempted to load an empty file from SoundResource!')
        return false

    if _stream:
        return true

    var err := ResourceLoader.load_threaded_request(file, '', false, ResourceLoader.CACHE_MODE_REUSE)
    if err == OK:
        _loading_async = true
    else:
        push_error('Unabled to load file asynchronously, error ' + str(err))

    return false

## Unloads the stream
func unload_stream() -> void:
    if not _stream:
        return

    _stream = null

## Get the audio stream, returns null if not loaded
func get_stream() -> AudioStreamOggVorbis:
    return _stream

## Check if the audio stream has loaded. Must be called if using `load_stream_async()`
## in order for async load requests to be queried.
func is_stream_ready() -> bool:
    if _stream:
        return true

    if not _loading_async:
        return false

    var progress: Array = []
    var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(file, progress)
    match status:
        ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            push_error('Invalid resource or not requested with `load_stream_async()`: "' + file + '"')
            return false
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            GlobalWorld.print('Loading file "' + file + '" progress: ' + ('%.2f' % (progress.front() * 100.0)))
            return false
        ResourceLoader.THREAD_LOAD_FAILED:
            push_warning('Load failed for file "' + file + '"')
            return false
        ResourceLoader.THREAD_LOAD_LOADED:
            var thing = ResourceLoader.load_threaded_get(file)
            if thing is not AudioStreamOggVorbis:
                push_error('Audio resource was not an ogg file: "' + file + '"')
                return false
            _stream = thing
            _loading_async = false
            return true
        _:
            push_error('Unknown load status: (' + str(status) + ') File: "' + file + '"')
            return false


## Get the volume for this sound
func get_volume() -> float:
    return base_volume

## Get the pitch for this sound
func get_pitch() -> float:
    return base_pitch_scale
