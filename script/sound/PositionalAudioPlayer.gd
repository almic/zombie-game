## Basic utility player for positional, layered sounds
class_name PositionalAudioPlayer extends Node3D


const INVALID_ID: int = AudioStreamPlaybackPolyphonic.INVALID_ID


## The producer Node3D of this audio player. Should be set to the top-most parent
## that owns this node. Used by sound hearing systems to track sound producers.
@export var source_node: Node3D

## The sound resource to play when calling `play()`
@export var sound: SoundResource:
    set(value):
        if sound != value:
            _sound_dirty = true
            sound = value

## The groups that this player is in. Used by other sound-hearing systems.
@export var groups: Array[StringName]:
    get():
        if not groups:
            groups = []
        return groups

## Desired polyphony of the sound when played. Determines if played sounds can
## overlap, and how many times they can overlap. Acts as a multiplier when the
## sound resource is a SoundResourceLayered.
@export_range(1, 32, 1, 'or_greater')
var polyphony: int = 2


var player: AudioStreamPlayer3D
var playback: AudioStreamPlaybackPolyphonic
var bus: StringName = &"Master":
    set(value):
        bus = value
        if player:
            player.bus = bus

var _ids_no_overlap: Dictionary[RID, int]
var _ids_overlap: PackedInt64Array
var _sound_dirty: bool = false


func _init() -> void:
    player = AudioStreamPlayer3D.new()
    player.stream = AudioStreamPolyphonic.new()
    player.bus = bus

    _ids_no_overlap = {}
    _ids_overlap = PackedInt64Array()


func _ready() -> void:
    add_child(player)

    # Silly, MUST call play() before requesting the playback object
    # NOTE: confirmed October 16 2025, still undocumented behavior
    player.play()
    playback = player.get_stream_playback()

func _physics_process(_delta: float) -> void:
    if _sound_dirty:
        _update_sound()
        _sound_dirty = false


func play(from_position: float = 0.0) -> void:
    if not sound:
        return

    if _sound_dirty:
        stop()
        _update_sound()
        _sound_dirty = false

    if is_instance_of(sound, SoundResourceLayered):
        var layered: SoundResourceLayered = sound as SoundResourceLayered
        if not layered:
            return

        var max_loudness: float = 0
        for layer in layered.get_sounds():
            if not layer:
                continue
            _play_sound(layer, from_position)
            max_loudness = maxf(layer.get_loudness(), max_loudness)

        GlobalWorld.sound_played(self, max_loudness)
        return

    # TODO: other special sound container types here
    # elif is_instance_of(sound, ...):

    _play_sound(sound, from_position)
    GlobalWorld.sound_played(self, sound.get_loudness())


func stop() -> void:
    if not playback:
        push_error('stop() called with a null playback')
        return

    for id in _ids_no_overlap.keys():
        playback.stop_stream(id)
    _ids_no_overlap.clear()

    for id in _ids_overlap:
        playback.stop_stream(id)
    _ids_overlap.clear()


func _play_sound(snd: SoundResource, offset: float, volume: float = 1.0, pitch: float = 1.0, overlap: bool = true) -> void:
    if not snd:
        return

    volume *= db_to_linear(snd.get_volume())
    pitch *= snd.get_pitch()

    if is_instance_of(snd, SoundResourceLayered):
        var layered: SoundResourceLayered = sound as SoundResourceLayered
        if not layered:
            return

        for layer in layered.get_sounds():
            if not layer:
                continue
            _play_sound(layer, offset, volume, pitch, overlap and layer.can_overlap)

        return

    # TODO: other special sound container types here
    # elif is_instance_of(sound, ...):

    if not snd.is_stream_ready():
        return

    var stream := snd.get_stream()
    if not stream:
        return

    if snd is SoundResourceVariable:
        offset += snd.get_offset_seconds()

    var vol_db: float = linear_to_db(volume)

    # If this exists in no overlap, stop it first
    var snd_rid: RID = snd.get_rid()
    var last: int = _ids_no_overlap.get(snd_rid, 0)
    if last:
        playback.stop_stream(last)

    if overlap and snd.can_overlap:
        for i in range(player.stream.polyphony):
            var id: int = playback.play_stream(
                    stream,
                    offset,
                    vol_db,
                    pitch,
                    AudioServer.PLAYBACK_TYPE_DEFAULT,
                    # NOTE: godot bug, this value is ignored
                    bus
            )

            if id != INVALID_ID:
                # Sound is playing now
                _ids_overlap.append(id)
                break

            if _ids_overlap.is_empty():
                # No overlap stream to stop ??
                break

            id = _ids_overlap.get(0)
            playback.stop_stream(id)
            _ids_overlap.remove_at(0)

        # If this was a non-overlap before, erase it
        if last:
            _ids_no_overlap.erase(snd_rid)

        return

    last = playback.play_stream(
            stream,
            offset,
            vol_db,
            pitch,
            AudioServer.PLAYBACK_TYPE_DEFAULT,
            # NOTE: godot bug, this value is ignored
            bus
    )

    if last != INVALID_ID:
        _ids_no_overlap.set(snd_rid, last)
        return

    _ids_no_overlap.erase(snd_rid)


func _update_sound() -> void:
    _load_sound(sound)

    if not player:
        push_error('Failed to update sound, player is null')
        return

    var stream: AudioStreamPolyphonic = player.stream as AudioStreamPolyphonic
    if not stream:
        push_error('Failed to update sound, stream is null or not polyphonic')
        return

    stream.polyphony = polyphony * maxi(1, _calculate_polyphony(sound))

func _load_sound(snd: SoundResource) -> void:
    if not snd:
        return

    if is_instance_of(snd, SoundResourceLayered):
        var layered: SoundResourceLayered = snd as SoundResourceLayered
        if not layered:
            return

        for layer in layered.get_sounds():
            if not layer:
                continue
            _load_sound(layer)
        return

    # TODO: other special sound container types here
    # elif is_instance_of(sound, ...):

    snd.load_stream_async()


func _calculate_polyphony(snd: SoundResource) -> int:

    if is_instance_of(snd, SoundResourceLayered):
        var layered: SoundResourceLayered = snd as SoundResourceLayered
        if not layered:
            return 0

        var count: int = 0
        for layer in layered.get_sounds():
            if not layer:
                continue
            count += _calculate_polyphony(layer)
        return count

    # TODO: other special sound container types here
    # elif is_instance_of(sound, ...):

    if snd:
        return 1

    return 0
