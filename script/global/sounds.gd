## Tracks sound history of the world
class_name Sounds extends Object


static var _sound_log: Array[Dictionary] = []

const TRIM_RATE = 1.0
const LOG_MAX_TIME = 10.0
static var _last_trim_time: float = 0


static func trim() -> void:
    var time: float = GlobalWorld.get_game_time()
    if time - _last_trim_time < TRIM_RATE:
        return
    _last_trim_time = time

    if _sound_log.is_empty():
        return

    var first: int = -1
    for i in range(_sound_log.size()):
        var sound: Dictionary = _sound_log[i]
        if time - sound.time < LOG_MAX_TIME:
            first = i
            break

    if first == -1:
        _sound_log.clear()

    _sound_log = _sound_log.slice(first)


## Record a sound event with a given time, player, and loudness
static func add_sound(
        player: PositionalAudioPlayer,
        loudness: float
) -> void:

    var time: float = GlobalWorld.get_game_time()
    var stream: AudioStreamPlayer3D = player.player

    var sound: Dictionary = {
        time = time,
        source = player.source_node,
        location = player.global_position,
        groups = player.groups.duplicate(),
        loudness = linear_to_db(stream.volume_linear * db_to_linear(loudness)),
    }

    if stream.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED:
        sound.att_model = stream.attenuation_model
        sound.att_unit_size = stream.unit_size

    if stream.emission_angle_enabled:
        sound.emission_cos_theta = cos(deg_to_rad(stream.emission_angle_degrees))
        sound.emission_filter_db = stream.emission_angle_filter_attenuation_db
        sound.emission_direction = stream.global_basis.z.normalized()

    if stream.max_distance > 0.0:
        sound.max_distance = stream.max_distance

    _sound_log.append(sound)


## Get sounds from log with a computed loudness given a position and the sources
## attenuation parameters
static func get_sounds(
        seconds_in_past: float,
        location: Vector3,
        groups: Array[StringName],
        min_loudness: float,
        max_distance: float,
) -> Array[Dictionary]:

    # Some quick tests to avoid nonsense
    if is_zero_approx(seconds_in_past)      \
            or min_loudness > 1000.0        \
            or is_zero_approx(max_distance) \
            or groups.is_empty()            \
            or _sound_log.is_empty()        \
    :
        return []

    var time: float = GlobalWorld.get_game_time()
    var results: Array[Dictionary] = []
    var max_dist_squared: float = max_distance * max_distance

    for i in range(_sound_log.size() - 1, -1, -1):
        var sound: Dictionary = _sound_log[i]

        # NOTE: newest sounds at the end, so when we go out of range, we are done
        var time_diff: float = time - sound.time
        if time_diff > seconds_in_past:
            break

        var loudness: float = sound.loudness
        if loudness < min_loudness:
            continue

        var diff: Vector3 = sound.location - location
        var direction: Vector3 = Vector3.ZERO
        var sound_dist: float = -1.0
        var dist_squared: float = diff.length_squared()
        if dist_squared > max_dist_squared:
            continue

        var has_max_dist: bool = sound.has('max_distance')
        var has_attenuation: bool = sound.has('att_model')
        var has_emission: bool = sound.has('emission_cos_theta')

        if has_max_dist or has_attenuation or has_emission:
            var sound_max_dist: float = 0.0
            var sound_max_dist_squared: float = 0.0
            if has_max_dist:
                sound_max_dist = sound.max_distance
                sound_max_dist_squared = sound_max_dist * sound_max_dist
                if dist_squared > sound_max_dist_squared:
                    continue

            if (has_attenuation or has_emission) and dist_squared > 0.0:
                sound_dist = sqrt(dist_squared)
                var loudness_linear: float = db_to_linear(loudness)

                var markiplier: float = 1.0
                if has_attenuation:
                    markiplier = _get_gain_linear(sound, sound_dist)

                if sound_max_dist > 0.0:
                    markiplier = minf(
                            markiplier,
                            clampf(1.0 - (sound_dist / sound_max_dist), 0.0, 1.0)
                    )

                loudness_linear *= markiplier
                loudness = linear_to_db(loudness_linear)

                if has_emission:
                    direction = diff / sound_dist
                    var dot: float = direction.dot(sound.emission_direction)
                    if dot < sound.emission_cos_theta:
                        loudness += sound.emission_filter_db

                if loudness < min_loudness:
                    continue

        var in_group: bool = false
        for group in groups:
            if sound.groups.has(group):
                in_group = true
                break

        if not in_group:
            continue

        if sound_dist == -1.0:
            sound_dist = sqrt(dist_squared)

        if direction.is_zero_approx():
            direction = diff / sound_dist

        results.append({
            loudness = loudness,
            distance = sound_dist,
            direction = direction,
            source = sound.source,
            groups = sound.groups.duplicate(),
            age = time_diff,
        })

    return results

## Calculate a linear gain from a sound and distance. A result of 1.0 means the
## loudness does not change, a result of 0.0 means the sound is inaudible.
static func _get_gain_linear(sound: Dictionary, distance: float) -> float:
    var model: AudioStreamPlayer3D.AttenuationModel = sound.att_model

    const EPSILON = 0.00001
    var vol: float
    if model == AudioStreamPlayer3D.AttenuationModel.ATTENUATION_INVERSE_DISTANCE:
        vol = sound.att_unit_size / maxf(distance, EPSILON)
    elif model == AudioStreamPlayer3D.AttenuationModel.ATTENUATION_INVERSE_SQUARE_DISTANCE:
        vol = sound.att_unit_size / maxf(distance, EPSILON)
        vol *= vol
    elif model == AudioStreamPlayer3D.AttenuationModel.ATTENUATION_LOGARITHMIC:
        # TODO: update to match the final gain db for distance in the engine source
        vol = db_to_linear(-20.0 * log(maxf(distance, EPSILON) / sound.att_unit_size))
    else:
        vol = 1.0

    return minf(1.0, vol)

## Returns the base sound group names of a node. Sound groups start with the
## prefix 'sound_group:'. For example, a node with the group 'sound_group:grass'
## would return the array `['grass']`.
static func get_sound_groups(node: Node) -> Array[StringName]:
    if not node:
        return []

    var result: Array[StringName] = []
    for group in node.get_groups():
        if not group.begins_with(GlobalWorld.SOUND_GROUP_PREFIX):
            continue
        result.append(group.get_slice(GlobalWorld.SOUND_GROUP_PREFIX, 1))

    return result
