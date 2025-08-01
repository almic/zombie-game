@tool

## Basic utility player for mixing weapons that use multiple audio streams
class_name WeaponAudioPlayer extends AudioStreamPlayer3D


const INVALID: int = AudioStreamPlaybackPolyphonic.INVALID_ID


@export var weapon_sound_resource: WeaponAudioResource


var _player: AudioStreamPlaybackPolyphonic
var _ids_no_overlap: PackedInt64Array = []
var _ids_overlap: PackedInt64Array = []


func _ready() -> void:
    var stream_poly = AudioStreamPolyphonic.new()
    # Double polyphony, we will still manage streams, but this prevents
    # failure to play on the same tick we stop a stream
    stream_poly.polyphony = 2 * weapon_sound_resource.polyphony
    stream = stream_poly

    # Silly, MUST call play() before requesting the playback object
    play()
    _player = get_stream_playback()

func play_sound() -> void:

    # No overlap sounds
    for id in _ids_no_overlap:
        _player.stop_stream(id)
    _ids_no_overlap.clear()

    if not weapon_sound_resource:
        return

    _play_resource(weapon_sound_resource.transient, false)
    _play_resource(weapon_sound_resource.tail, false)

    # 1 overlap
    while _ids_overlap.size() > 3:
        var id: int = _ids_overlap.get(0)
        _ids_overlap.remove_at(0)
        _player.stop_stream(id)

    _play_resource(weapon_sound_resource.kick_sub, true)
    _play_resource(weapon_sound_resource.body, true)
    _play_resource(weapon_sound_resource.mech, true)

func _play_resource(sound: SoundResource, overlap: bool) -> int:
    if not sound:
        return INVALID

    var s_stream: AudioStream = sound.get_stream()
    if not s_stream:
        return INVALID

    var offset: float = sound.get_offset_seconds()
    var volume: float = sound.get_volume()
    var pitch: float = sound.get_pitch()

    var id: int
    for i in range(weapon_sound_resource.polyphony):
        id = _player.play_stream(
                s_stream,
                offset,
                volume,
                pitch,
                AudioServer.PLAYBACK_TYPE_DEFAULT,
                bus
        )

        if id != INVALID:
            break

        # Kill oldest stream until play_stream gives a valid ID
        if overlap:
            if _ids_overlap.size() == 0:
                break
            id = _ids_overlap.get(0)
            _ids_overlap.remove_at(0)
        else:
            if _ids_no_overlap.size() == 0:
                break
            id = _ids_no_overlap.get(0)
            _ids_no_overlap.remove_at(0)
        _player.stop_stream(id)

    if id == INVALID:
        return INVALID

    #print(
            #"Played \"" + sound.resource_name + "\", "
            #+ "v: " + str(volume) + ", "
            #+ "p: " + str(pitch) + ", "
            #+ "o: " + str(offset)
    #)

    if overlap:
        _ids_overlap.append(id)
    else:
        _ids_no_overlap.append(id)

    return id
