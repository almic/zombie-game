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

@export var bus: StringName = &"Master":
    set(value):
        bus = value
        if player:
            player.bus = bus


@export_group("Limitation", "limit")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var limit_enabled: bool = false

## Number of ticks between limit tests
@export_range(0, 120, 1, 'or_greater')
var limit_tick_time: int = 60

## Number of closest nodes in the given group that this node must be to play
## sounds. Set to zero to disable.
@export_range(0, 50, 1, 'or_greater')
var limit_closest_count: int = 20

## Group to check when limiting by closest nodes in a group.
@export var limit_closest_group: StringName = &""


var player: AudioStreamPlayer3D
var playback: AudioStreamPlaybackPolyphonic

var _ids_no_overlap: Dictionary[int, int]
var _playing_ids: PackedInt64Array
var _sound_dirty: bool = false
var _sound_queue: PackedFloat32Array

var _limiter_tick_time: int = 0
var _is_too_far: bool = false


func _init() -> void:
    player = AudioStreamPlayer3D.new()
    player.stream = AudioStreamPolyphonic.new()
    player.bus = bus

    _ids_no_overlap = {}
    _playing_ids = PackedInt64Array()
    _sound_queue = PackedFloat32Array()


func _ready() -> void:
    for group in groups:
        add_to_group(group)

    if limit_enabled:
        _is_too_far = true
        if limit_closest_group:
            add_to_group(limit_closest_group)

    add_child(player)

func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint():
        # AAHOHEAOEHATHSNUS
        return

    if _sound_dirty:
        _update_sound()
        _sound_dirty = false

    for item in _sound_queue:
        GlobalWorld.sound_played(self, item)
    _sound_queue.clear()

    if limit_enabled:
        _update_limit()

func _update_limit() -> void:
    _limiter_tick_time -= 1
    if _limiter_tick_time >= 0:
        return

    _limiter_tick_time = limit_tick_time

    if not limit_closest_group or limit_closest_count < 1:
        return

    var closest := GlobalWorld.get_closest_nodes_in_group(
            get_viewport().get_camera_3d().global_position,
            limit_closest_count,
            limit_closest_group
    )

    if closest.has(self):
        _is_too_far = false
    else:
        _is_too_far = true


func play(from_position: float = 0.0) -> void:
    if _is_too_far:
        return

    if not sound:
        return

    var in_physics: bool = Engine.is_in_physics_frame()

    if _sound_dirty:
        # NOTE: IDK why but having this line just nukes all audio for the player
        #       PERMANENTLY. Even replacing the stream doesn't fix it. Maybe Godot bug.
        # stop()
        _update_sound()
        _sound_dirty = false
    else:
        # Check all playing streams
        var idx: int = 0
        for stream in _playing_ids:
            if playback.is_stream_playing(stream):
                _playing_ids[idx] = stream
                idx += 1
        _playing_ids.resize(idx)

    var max_loudness: float = foreach_sound(-INF, sound, false, func(snd: SoundResource, loudness: float):
        var snd_loudness: float = snd.get_loudness()
        if snd_loudness > loudness:
            loudness = snd_loudness
        _play_sound(snd, from_position)
        return loudness
    )

    if in_physics:
        GlobalWorld.sound_played(self, max_loudness)
    else:
        _sound_queue.append(max_loudness)


func stop() -> void:
    # TODO: figure out why this happens to all audio output. Possibly caused by
    #       the lock() / unlock() maybe getting reordered?
    push_error('This method sometimes breaks ALL audio permanently. Please don\'t use it.')

    if not playback:
        push_error('stop() called with a null playback')
        return

    playback.stop()

    # NOTE: this looks wrong, but this must be restarted in order for future
    #       play() calls to work. This doesn't actually cause anything to play,
    #       it only allows the playback to output future sounds.
    playback.start()

    _playing_ids.clear()
    _ids_no_overlap.clear()


func _play_sound(snd: SoundResource, offset: float, volume: float = 1.0, pitch: float = 1.0, overlap: bool = true) -> void:
    if not snd:
        return

    volume *= db_to_linear(snd.get_volume())
    pitch *= snd.get_pitch()

    if not snd.is_stream_ready():
        return

    var stream := snd.get_stream()
    if not stream:
        return

    if snd is SoundResourceVariable:
        offset += snd.get_offset_seconds()

    var vol_db: float = linear_to_db(volume)

    # If this exists in no overlap, stop it first
    var snd_id: int = snd.get_instance_id()
    var stream_id: int = _ids_no_overlap.get(snd_id, 0)
    if stream_id:
        playback.stop_stream(stream_id)

    stream_id = playback.play_stream(
            stream,
            offset,
            vol_db,
            pitch,
            AudioServer.PLAYBACK_TYPE_DEFAULT,
            # NOTE: godot bug, this value is ignored
            bus
    )

    if stream_id != INVALID_ID:
        _playing_ids.append(stream_id)
    else:
        GlobalWorld.print('not enough polyphonic! polyphonic: ' + str(player.stream.polyphony) + ' ; streams: ' + str(_playing_ids.size()))

    if overlap and snd.can_overlap:
        # erase just in case
        _ids_no_overlap.erase(snd_id)
        return

    if stream_id != INVALID_ID:
        _ids_no_overlap.set(snd_id, stream_id)
        return

    _ids_no_overlap.erase(snd_id)


func _update_sound() -> void:
    load_sound(sound)

    if not player:
        push_error('Failed to update sound, player is null')
        return

    var stream: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
    stream.polyphony = polyphony * maxi(1, _calculate_polyphony(sound))

    player.stream = stream

    # Silly, MUST call play() before requesting the playback object
    # NOTE: confirmed October 16 2025, still undocumented behavior
    player.play()
    playback = player.get_stream_playback()


static func load_sound(snd: SoundResource) -> void:
    foreach_sound(null, snd, true, func(res: SoundResource, _unused):
        res.load_stream_async()
    )

static func _calculate_polyphony(snd: SoundResource) -> int:
    return foreach_sound(0, snd, true, func(res: SoundResource, value: int):
        if res.can_overlap:
            value += 1
        return value
    )

## Iterates through all sounds and runs `lambda` with each basic SoundResource or
## SoundResourceVariable. The function is passed two parameters, the current
## sound and the last returned value. For the first call, the initial value is
## passed. Returns the last return value of the lambda.
@warning_ignore("shadowed_variable")
static func foreach_sound(initial, sound: SoundResource, all: bool, lambda: Callable) -> Variant:
    if not sound:
        return initial

    var value = initial
    var seen: Array[SoundResource] = []
    var parents: Array[SoundResource] = []
    var check: Array[SoundResource] = [sound]

    while not check.is_empty():
        var res: SoundResource = check.pop_back()

        # nulls mark parent's end
        if res == null:
            parents.resize(parents.size() - 1)
            continue

        seen.append(res)

        if is_instance_of(res, SoundResourceChoice):
            var choice: SoundResourceChoice = res as SoundResourceChoice
            if not choice:
                continue

            parents.append(choice)
            check.append(null) # Mark a parent pop

            if all:
                for option in choice.get_sounds():
                    if not option:
                        continue

                    if parents.has(option):
                        push_error('Self-referenced SoundResource in SoundResourceChoice "' + res.resource_path + '"! Self-reference is not allowed!')
                        return

                    if seen.has(option):
                        continue

                    check.append(option)
            else:
                var option := choice.pick_sound()

                if not option:
                    continue

                if parents.has(option):
                    push_error('Self-referenced SoundResource in SoundResourceChoice "' + res.resource_path + '"! Self-reference is not allowed!')
                    return

                if seen.has(option):
                    continue

                check.append(option)

            continue

        if is_instance_of(res, SoundResourceLayered):
            var layered: SoundResourceLayered = res as SoundResourceLayered
            if not layered:
                continue

            parents.append(layered)
            check.append(null) # Mark a parent pop

            for layer in layered.get_sounds():
                if not layer:
                    continue

                if parents.has(layer):
                    push_error('Self-referenced SoundResource in SoundResourceLayered "' + res.resource_path + '"! Self-reference is not allowed!')
                    return

                if seen.has(layer):
                    continue

                check.append(layer)

            continue

        if is_instance_of(res, SoundResourceMap):
            if not all:
                push_error('Cannot iterate a SoundResourceMap with `all` disabled!')
                return

            var map: SoundResourceMap = res as SoundResourceMap
            if not map:
                continue

            parents.append(map)
            check.append(null) # Mark a parent pop

            for option in map.get_sounds():
                if not option:
                    continue

                if parents.has(option):
                    push_error('Self-referenced SoundResource in SoundResourceMap "' + res.resource_path + '"! Self-reference is not allowed!')
                    return

                if seen.has(option):
                    continue

                check.append(option)

            continue

        # TODO: other special sound container types here
        # elif is_instance_of(sound, ...):

        # Regular resource
        value = lambda.call(res, value)

    return value
