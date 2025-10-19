# HACK: Tool is needed to hide export values
@tool
## A special sound resource that picks a random sound from a set
class_name SoundResourceChoice extends SoundResource


## The weighted choices. Use a weight of zero to disable a choice. The probability
## of a sound is its weight over the sum of all weights. For example, to have
## two sounds with a 1/3 and 2/3 probability, you would assign them the weight
## of the numerators (1 & 2).
@export_custom(
    PROPERTY_HINT_DICTIONARY_TYPE,
    # (
    #     "%d/%d:%s;%d/%d:%s" % [
    #         TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "SoundResource",
    #         TYPE_INT, PROPERTY_HINT_RANGE, "0,100,1,or_greater"
    #     ]
    # )
    "24/17:SoundResource;2/1:0,100,1,or_greater"
)
var choices: Dictionary[SoundResource, int]

## Anti-repeat count, prevents the same sound from playing within this number of
## calls to 'pick_sound()'. Set to zero to disable this feature. If this value
## is greater than the number of available choices, the oldest played sound will
## be picked. This will respect sounds disabled with a weight value of zero.
@export_range(0, 5, 1, 'or_greater')
var anti_repeat_count: int = 3:
    set(value):
        if anti_repeat_count != value:
            anti_repeat_count = value
            _repeat_list = []


var _sum: int = -1
var _sorted_sounds: Array[SoundResource]
var _repeat_list: Array[SoundResource]
var _repeat_list_idx: int = 0


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


func pick_sound() -> SoundResource:
    if choices.is_empty():
        return null

    if _sum == -1:
        _compute_sum()

    var size: int = _sorted_sounds.size()
    if size == 1:
        return _sorted_sounds[0]

    # TODO: _cached is for dev only, remove later
    var _cached: int = randi_range(1, _sum)
    var counter: int = _cached
    var last: SoundResource
    for i in range(size):
        var sound = _sorted_sounds[i]
        counter -= choices.get(sound)
        if counter <= 0:
            if anti_repeat_count == 0:
                return sound

            # Iterate and check repeat list
            if not _repeat_list:
                _repeat_list = []
                _repeat_list_idx = 0
                _repeat_list.resize(anti_repeat_count)

            if not _repeat_list.has(sound):
                _repeat_list[_repeat_list_idx] = sound
                _repeat_list_idx = posmod(_repeat_list_idx + 1, anti_repeat_count)
                return sound

            # Find next unused sound
            var start: int = i
            i = posmod(i + 1, size)
            while i != start:
                sound = _sorted_sounds[i]
                # Respect zero weight sounds
                if choices.get(sound) != 0 and not _repeat_list.has(sound):
                    _repeat_list[_repeat_list_idx] = sound
                    _repeat_list_idx = posmod(_repeat_list_idx + 1, anti_repeat_count)
                    return sound
                i = posmod(i + 1, size)

            # All sounds have been used, return oldest and re-add it
            sound = _repeat_list[_repeat_list_idx]
            start = _repeat_list_idx
            i = posmod(start + 1, anti_repeat_count)
            # Get next non-null sound from repeat list
            # NOTE: this no longer respects zero weight sounds, but that sounds
            #       like a crazy thing to worry about now so I am ignoring it
            while sound == null and i != start:
                sound = _repeat_list[i]
                i = posmod(i + 1, anti_repeat_count)

            _repeat_list[_repeat_list_idx] = sound
            _repeat_list_idx = posmod(_repeat_list_idx + 1, anti_repeat_count)

            # TODO: for dev only, remove later
            # TODO: if we respect weight counts from the repeat list, this should
            #       no longer be an error. Maybe a warning though?
            if sound == null:
                push_error('SoundResourceChoice failed to pick a backup sound from anti-repeat list! Investigate!')

            return sound

        last = sound

    push_error('SoundResourceChoice failed to locate chosen ticket #' + str(_cached) + '! Investigate!')
    return last


func _compute_sum() -> void:
    _sum = 0
    _sorted_sounds = []
    var size: int = choices.size()
    _sorted_sounds.resize(size)

    # Collect key values pairs in an array
    var to_sort: Array = []
    to_sort.resize(size)
    var i: int = 0
    for sound in choices:
        if sound == null:
            size -= 1
            _sorted_sounds.resize(size)
            to_sort.resize(size)
            continue

        var val: int = choices.get(sound)
        _sum += val
        to_sort[i] = [sound, val]
        i += 1

    to_sort.sort_custom(func (a, b) -> bool: return a[1] > b[1])

    i = 0
    for pair in to_sort:
        _sorted_sounds[i] = pair[0]
        i += 1
