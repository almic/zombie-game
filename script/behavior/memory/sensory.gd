## Stores sensory-related memories, sight, sound, feel, etc.
class_name BehaviorMemorySensory extends BehaviorMemory


const NAME = &"sensory"

func name() -> StringName:
    return NAME

func can_decay() -> bool:
    return event_count > 0

enum Type {
    SIGHT = 1,
    SOUND = 2,
    SMELL = 3,

    MAX
}

enum Flag {
    ## A response to this event has been started
    RESPONSE_STARTED  = 1 << 0,
    ## A response to this event has completed
    RESPONSE_COMPLETE = 1 << 1,

    ## Flags will be overwritten when calling 'overwrite_event' or using tracking
    OVERWRITE_FLAGS   = 1 << 5,

    ## This event uses game_time tracking
    TRACKING_TIMED    = 1 << 6,
    ## This event is an original for a given tracking ID
    TRACKING_ORIGINAL = 1 << 7    # MAX
}


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var sensory_logs: Dictionary[Type, PackedByteArray]

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var event_idxs: Dictionary[Type, PackedInt32Array]:
    set(value):
        event_idxs = value
        event_idxs_sorted = event_idxs.duplicate(true)
        for type in event_idxs_sorted:
            event_idxs_sorted.get(type).sort()

## This is just a mirror of event_idxs which maintains sorted order
var event_idxs_sorted: Dictionary[Type, PackedInt32Array]

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var event_count: int = 0


## Return the number of events in memory
func count(type: Type = Type.MAX) -> int:
    if type == Type.MAX:
        return event_count
    return event_idxs.get(type, []).size()

## Retrieve events of a certain type. Returns indexes which must be passed to decoding methods to
## obtain sensory information.
func get_events(type: Type) -> PackedInt32Array:
    if event_idxs.has(type):
        return event_idxs.get(type).duplicate()
    return PackedInt32Array()

## Removes sensory memories that have expired
func decay(delta: float) -> void:
    for type in event_idxs_sorted:
        var i: int = 0
        var events: PackedInt32Array = event_idxs_sorted.get(type)
        var size: int = events.size()
        var event: int
        while i < size:
            event = events[i]
            if event_decay(type, event, delta):
                size -= 1
                continue
            i += 1


## If the provided time is equivalent to the gametime that would be saved to an
## event right now.
static func is_event_gametime(time: float) -> float:
    var seconds: int = floori(time)
    var frac: int = int((time - seconds) * 256.0)
    var test_time: float = float(seconds) + (float(frac) / 256.0)

    var game_time: float = GlobalWorld.get_game_time()
    seconds = floori(game_time)
    frac = int((game_time - seconds) * 256.0)
    game_time = float(seconds) + (float(frac) / 256.0)

    return is_equal_approx(game_time, test_time)

## AGGAOGEHAOEDATHOTDEIT>FHUIGI
func _get_events_reference(type: Type) -> PackedByteArray:
    # NOTE: DO NOT WRITE "as PackedByteArray" OR IT WILL MAKE A COPY!!!!!!!
    return sensory_logs.get_or_add(type, PackedByteArray())


const e_SIZE = 0
const e_SIZE_LEN = 2
const e_TYPE = e_SIZE + e_SIZE_LEN
const e_TYPE_LEN = 1
const e_TRACKINGID = e_TYPE + e_TYPE_LEN
const e_TRACKINGID_LEN = 8
const e_FLAG = e_TRACKINGID + e_TRACKINGID_LEN
const e_FLAG_LEN = 1
const e_EXPIRE = e_FLAG + e_FLAG_LEN
const e_EXPIRE_LEN = 3
const e_DATA = e_EXPIRE + e_EXPIRE_LEN
const e_DATA_LEN = 1
const e_HEADERLENGTH = e_DATA + e_DATA_LEN
const e_DATA_ARRAY = e_HEADERLENGTH


## Start a sensory event
func start_event(type: Type) -> PackedByteArray:
    var bytes: PackedByteArray = []

    bytes.resize(e_HEADERLENGTH)

    event_set_size(bytes, bytes.size())
    event_set_type(bytes, type)
    event_set_tracking(bytes, 0)
    event_set_flag(bytes, 0)
    event_set_expire(bytes, 1.0)
    event_set_data_count(bytes, 0)

    return bytes

## Write the event to memory
func finish_event(event: PackedByteArray) -> void:
    var size: int = event_get_size(event)
    var type: Type = event_get_type(event)

    # TODO: check tracking IDs
    var tracking: int = event_get_tracking(event)
    if tracking:
        const TRACKING_TIME = 10

        var track_time: bool = event_get_flag(event) & Flag.TRACKING_TIMED
        var game_time: int = GlobalWorld.game_time
        var events: PackedInt32Array = get_events(type)
        var found: int = -1
        var mark_original: bool = true

        for ev in events:
            var other_id: int = get_event_tracking(type, ev)
            if tracking != other_id:

                # If we are doing time checks, we may be able to stop early if
                # we reach a very old event.
                if track_time:
                    @warning_ignore("confusable_local_declaration")
                    var other_time: float = get_event_game_time(type, ev)
                    if other_time == -1:
                        continue

                    @warning_ignore("confusable_local_declaration")
                    var delta_time: float = game_time - other_time
                    # Will definitely be original, can stop looking now
                    if delta_time > TRACKING_TIME * 2:
                        mark_original = true
                        break

                continue

            # If we find a matching ID, this probably won't be original
            mark_original = false

            var flags: int = get_event_flag(type, ev)
            var other_tracks_time: bool = flags & Flag.TRACKING_TIMED
            if other_tracks_time != track_time:
                # Mismatched time tracking flag, must insert
                push_warning('Saving event with time tracking, found other without time tracking. This is a mistake!')
                if track_time:
                    mark_original = true
                break

            if not track_time:
                # Matched ID, no time or original stuff, just write here
                found = ev
                break

            if flags & Flag.TRACKING_ORIGINAL:
                # Found an original, we MUST insert this new event
                break

            var other_time: float = get_event_game_time(type, ev)
            if other_time == -1:
                # No timing data, this is likely a mistake and we should insert instead
                push_warning('Saving event with time tracking, found other missing time data. This is a mistake!')
                mark_original = true
                break

            var delta_time: float = game_time - other_time
            if delta_time < TRACKING_TIME:
                # Within tracking time, write here
                found = ev
                break

            # Also, this SHOULD be marked original if the next event is too old
            if delta_time > TRACKING_TIME * 2:
                mark_original = true

            # Found an old event with same ID, we should insert now
            break

        if found != -1:
            overwrite_event(type, found, event)

            # Update time dependent indexes to maintain time order
            var time_indexes: PackedInt32Array = event_idxs.get(type)
            var event_id: int = time_indexes.find(found)
            if event_id == -1:
                push_error('Found event does not exist in event indexes! Huh??')
                return

            # Do not need to move, already at the front
            if event_id == 0:
                return

            # Move all previous events back
            for i in range(event_id, 0, -1):
                time_indexes[i] = time_indexes[i - 1]

            time_indexes[0] = found
            return

        if mark_original:
            event_set_flag(event, event_get_flag(event) | Flag.TRACKING_ORIGINAL)


    # add event to front of log
    var old_log: PackedByteArray = _get_events_reference(type)
    event.append_array(old_log)
    old_log.clear() # can clear this now

    # update indexes
    var indexes: PackedInt32Array = event_idxs.get_or_add(type, PackedInt32Array())
    var sorted_indexes: PackedInt32Array = event_idxs_sorted.get_or_add(type, PackedInt32Array())
    var idx_len: int = indexes.size()
    indexes.resize(idx_len + 1)
    sorted_indexes.resize(idx_len + 1)
    for i in range(idx_len, 0, -1): # NOTE: up to the second element only
        indexes[i] = indexes[i - 1] + size
        sorted_indexes[i] = sorted_indexes[i - 1] + size
    indexes[0] = 0
    sorted_indexes[0] = 0

    sensory_logs.set(type, event)
    event_count += 1

## Overwrites data from 'src' into 'dest'. Data elements must be the same size
## and in the same order, otherwise the write will be partial and undefined
## behavior may happen.
func overwrite_event(type: Type, dest: int, src: PackedByteArray) -> void:
    # TODO: decide if events with dynamically sized data can overwrite that data
    #       as long as the overall length is the same, or the length of that
    #       dynamic data is the same. Or, just deny overwriting dynamic data at
    #       all and just skip over it, allowing it to be empty/ zero length from
    #       the source, or whatever it stores is ignored and not considered when
    #       overwriting (allowing diff lengths as long as no new data elements/
    #       order is changed).

    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return

    var src_size: int = event_get_size(src)
    var dest_size: int = get_event_size(type, dest)

    # Check sizes
    # NOTE: for development, should be removed.
    if src_size != dest_size:
        push_error('Cannot overwrite sensory event with mismatched sizes! Investigate!')
        return

    var src_data_count: int = event_get_data_count(src)
    var dest_data_count: int = get_event_data_count(type, dest)

    # Check data count
    # NOTE: for development, should be removed.
    if src_data_count != dest_data_count:
        push_error('Cannot overwrite sensory event with mismatched data counts! Investigate!')
        return

    # Check for flag overwrite
    var src_flags: int = event_get_flag(src)
    if not (src_flags & Flag.OVERWRITE_FLAGS):
        event_set_flag(src, get_event_flag(type, dest))

    # Copy header
    for i in range(e_HEADERLENGTH):
        events[dest + i] = src[i]

    # Copy data elements
    var i: int = 0
    var data_index: int = 0
    var data_size: int
    var time_tracking: bool = src_flags & Flag.TRACKING_TIMED
    var skipped_first_gametime: bool = false
    while i < src_size and data_index < src_data_count:
        var src_type: int = src.decode_u8(e_DATA_ARRAY + i)
        var dest_type: int = events.decode_u8(dest + e_DATA_ARRAY + i)

        # Check data type
        if src_type != dest_type:
            push_error('Failed to overwrite sensory event, mismatching data types! Investigate!')
            break

        var fixed_size: bool = false
        if src_type == d_NODEPATH:
            data_size = src.decode_u16(e_DATA_ARRAY + i + 1) + 2
            var dest_data_size: int = events.decode_u16(dest + e_DATA_ARRAY + i + 1) + 2
            if data_size != dest_data_size:
                push_error('Failed to overwrite sensory event, dynamically sized nodepath data have different lengths! What to do here?')
                break
        elif src_type == d_GROUPS:
            data_size = src.decode_u8(e_DATA_ARRAY + i + 1) + 1
            var dest_data_size: int = events.decode_u8(dest + e_DATA_ARRAY + i + 1) + 1
            if data_size != dest_data_size:
                push_error('Failed to overwrite sensory event, dynamically sized group data have different lengths! What to do here?')
                break
        else:
            data_size = d_STRIDES.get(src_type)
            fixed_size = true

        # Time tracking will NOT overwrite the FIRST 'gametime' data
        if time_tracking and src_type == d_GAMETIME and not skipped_first_gametime:
            skipped_first_gametime = true
        elif fixed_size:
            # Copy fixed size data
            events.copy_range(dest + e_DATA_ARRAY + i + 1, src, e_DATA_ARRAY + i + 1, data_size)

        i += data_size + 1
        data_index += 1

    pass


## Decay the timer of an event by some number of seconds. If the event timer reaches
## zero, it is removed from the event log, and `true` is returned. When this removes
## an event, you should retrieve event ids again.
func event_decay(type: Type, event: int, seconds: float) -> bool:
    var event_log: PackedByteArray = _get_events_reference(type)
    var time: float = get_event_expire(type, event)
    time -= seconds

    if time > 0:
        set_event_expire(type, event, time)
        return false

    # print('Deleting memory type ' + str(type) + ' at ' + str(event))

    var sorted_indexes: PackedInt32Array = event_idxs_sorted.get(type)
    var indexes: PackedInt32Array = event_idxs.get(type)

    var sorted_event_id: int = sorted_indexes.bsearch(event, false) - 1
    var event_id: int = indexes.find(event)

    var size: int = event_log.decode_u16(event + e_SIZE)
    var log_size: int = event_log.size()

    # Move later events forward
    var dest: int = event
    var src: int = event + size
    var c: int = log_size - src
    event_log.move_range(dest, src, c)

    # trim log
    event_log.resize(log_size - size)

    # erase index
    indexes.remove_at(event_id)
    sorted_indexes.remove_at(sorted_event_id)

    # update indexes
    for i in range(sorted_event_id, sorted_indexes.size()):
        sorted_indexes[i] -= size

    for i in range(indexes.size()):
        var ev: int = indexes[i]
        if ev > event:
            indexes[i] = ev - size

    event_count -= 1

    return true


## Get the data count of this event
func event_get_data_count(event: PackedByteArray) -> int:
    return event.decode_u8(e_DATA)

## Set the data count of this event. DO NOT USE! You WILL break something!
func event_set_data_count(event: PackedByteArray, data_count: int) -> void:
    event.encode_u8(e_DATA, data_count)

## Get the expire delay of this event
func event_get_expire(event: PackedByteArray) -> float:
    var whole: int = event.decode_u16(e_EXPIRE)
    var frac: int = event.decode_u8(e_EXPIRE + 2)

    return float(whole) + (float(frac) / 256.0)

## Set the expire delay of this event. The event will be removed after this many
## seconds. Can be incremented later to increase the life of the event.
func event_set_expire(event: PackedByteArray, seconds: float) -> void:
    var whole: int = int(seconds)
    var frac: int = int((seconds - float(whole)) * 256.0)
    event.encode_u16(e_EXPIRE, whole)
    event.encode_u8(e_EXPIRE + 2, frac)

## Get the flags of this event
func event_get_flag(event: PackedByteArray) -> int:
    return event.decode_u8(e_FLAG)

## Set the flags of this event
func event_set_flag(event: PackedByteArray, flag: int) -> void:
    event.encode_u8(e_FLAG, flag)

## Get the size of this event. Events store their size manually, improving processing large lists
## of events without having to parse the event itself.
func event_get_size(event: PackedByteArray) -> int:
    return event.decode_u16(e_SIZE)

## Set the size value of this event. DO NOT USE! You WILL break something!
func event_set_size(event: PackedByteArray, size: int) -> void:
    event.encode_u16(e_SIZE, size)

## Get the tracking ID of this event
func event_get_tracking(event: PackedByteArray) -> int:
    return event.decode_s64(e_TRACKINGID)

## Set the tracking ID of this event
func event_set_tracking(event: PackedByteArray, id: int) -> void:
    event.encode_s64(e_TRACKINGID, id)

## Set the tracking ID of this event from a node. Uses a SHA1 hash of the node path.
func event_set_tracking_node(event: PackedByteArray, node: Node) -> void:
    var id: int = node.get_path().get_concatenated_names().sha1_buffer().decode_u64(0)
    event_set_tracking(event, id)

## Get the type of this event.
func event_get_type(event: PackedByteArray) -> Type:
    return event.decode_u8(e_TYPE) as Type

## Set the type of this event. DO NOT USE! You WILL break something!
func event_set_type(event: PackedByteArray, type: Type) -> void:
    event.encode_u8(e_TYPE, type)


# ########################################
#            Event Log Methods           #
# ########################################


## Get an event's data count value. Returns -1 if the event is not found
func get_event_data_count(type: Type, event: int) -> int:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1

    return events.decode_u8(event + e_DATA)

## Get an event's expire time. Returns -1 if the event is not found
func get_event_expire(type: Type, event: int) -> float:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1.0

    var whole: int = events.decode_u16(event + e_EXPIRE)
    var frac: int = events.decode_u8(event + e_EXPIRE + 2)

    return float(whole) + (float(frac) / 256.0)

## Set an event's expire time
func set_event_expire(type: Type, event: int, expire: float) -> bool:
    var events := _get_events_reference(type)
    if not events:
        return false

    var whole: int = int(expire)
    var frac: int = int((expire - float(whole)) * 256.0)
    events.encode_u16(event + e_EXPIRE, clampi(whole, 0, 65535))
    events.encode_u8(event + e_EXPIRE + 2, clampi(frac, 0, 255))
    return true

## Get an event's flag value. Returns -1 if the event is not found
func get_event_flag(type: Type, event: int) -> int:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1

    return events.decode_u8(event + e_FLAG)

## Set an event's flag value.
func set_event_flag(type: Type, event: int, flag: int) -> bool:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return false

    events.encode_u8(event + e_FLAG, flag)
    return true

## Get an event's size value. Returns -1 if the event is not found
func get_event_size(type: Type, event: int) -> int:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1

    return events.decode_u16(event + e_SIZE)

## Get an event's tracking value. Returns 0 if the event is not found.
## NOTE: The reason to return zero is because that is the 'no tracking' value,
## and -1 is a possible valid tracking ID.
func get_event_tracking(type: Type, event: int) -> int:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return 0

    return events.decode_s64(event + e_TRACKINGID)


## Unsigned int 32 + uint8 for fractional seconds
const d_GAMETIME = 1
const d_GAMETIME_SIZE = 5

## Half precision float for in-game time of day
const d_TIMEOFDAY = 2
const d_TIMEOFDAY_SIZE = 2

## String containing a node path, dynamic size
const d_NODEPATH = 3

## Array of groups, stored by unique global ID
const d_GROUPS = 4

## Two vector 3s, first is a position, second is a direction
const d_LOCATION = 16
const d_LOCATION_SIZE = ((4) * 3) * 2

## Travel vector, Vector4 with XYZ direction and W distance
const d_TRAVEL = 17
const d_TRAVEL_SIZE = (4) * 4

## Forward vector, Vector3
const d_FORWARD = 18
const d_FORWARD_SIZE = (4) * 3

## Strides for data elements
const d_STRIDES = {
    d_GAMETIME: d_GAMETIME_SIZE,
    d_TIMEOFDAY: d_TIMEOFDAY_SIZE,
    d_LOCATION: d_LOCATION_SIZE,
    d_TRAVEL: d_TRAVEL_SIZE,
    d_FORWARD: d_FORWARD_SIZE
}


## Internal. Returns the offset of the given data type from `event` in the events
## array, or -1 if the event has fewer than `which` data type elements.
func _get_event_data_offset(events: PackedByteArray, event: int, search: int, which: int) -> int:
    var data_count: int = events.decode_u8(event + e_DATA)

    if which > data_count:
        return -1

    var size: int = events.decode_u16(event + e_SIZE)

    var offset: int = event + e_DATA_ARRAY
    var i: int = 0
    var data_index: int = 0
    var data_type: int
    while i < size and data_index < data_count:
        data_type = events.decode_u8(offset + i)
        if data_type == search:
            which -= 1
            if which == 0:
                return offset + i + 1
        if data_type == d_NODEPATH:
            i += 2 + events.decode_u16(offset + i + 1)
        elif data_type == d_GROUPS:
            i += 1 + events.decode_u8(offset + i + 1)
        else:
            i += d_STRIDES[data_type]
        i += 1
        data_index += 1

    return -1

## Get game time data from an event. Returns -1 if event lacks game time data,
## or `which` is greater than the number of game time data stored.
func get_event_game_time(type: Type, event: int, which: int = 1) -> float:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1

    var offset: int = _get_event_data_offset(events, event, d_GAMETIME, which)
    if offset < 0:
        return -1

    var seconds: int = events.decode_u32(offset); offset += 4
    var frac: int = events.decode_u8(offset)

    return float(seconds) + (float(frac) / 256.0)

## Get time of day data from an event. Returns -1 if event lacks time of day data,
## or `which` is greater than the number of time of day data stored.
func get_event_time_of_day(type: Type, event: int, which: int = 1) -> float:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return -1

    var offset: int = _get_event_data_offset(events, event, d_TIMEOFDAY, which)
    if offset < 0:
        return -1

    return events.decode_half(offset)

## Get node path data from an event. Returns the empty node path if event lacks
## node path data, or `which` is greater than the number of node path data stored.
func get_event_node_path(type: Type, event: int, which: int = 1) -> NodePath:
    return NodePath(get_event_node_path_string(type, event, which))

## Get node path data as a StringName from an event. Returns the empty StringName
## if the event lacks node path data, or `which` is greater than the number of
## node path data stored.
func get_event_node_path_string(type: Type, event: int, which: int = 1) -> StringName:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return &""

    var offset: int = _get_event_data_offset(events, event, d_NODEPATH, which)
    if offset < 0:
        return &""

    var size: int = events.decode_u16(offset); offset += 2
    var bytes: PackedByteArray
    bytes.resize(size)

    for i in range(size):
        bytes[i] = events[offset + i]

    return bytes.get_string_from_utf8()

## Get the groups from an event. Groups are stored by their unique global ID.
## Returns an array with -1 as the only element if the event lacks group data,
## or `which` is greater than the number of group data stored. The reason to not
## return an empty array instead is because an empty array is valid, while negative
## elements are invalid.
func get_event_groups(type: Type, event: int, which: int = 1) -> PackedInt32Array:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return [-1]

    var offset: int = _get_event_data_offset(events, event, d_GROUPS, which)
    if offset < 0:
        return [-1]

    var size: int = events.decode_u8(offset); offset += 1
    var ids: PackedInt32Array
    ids.resize(size)

    for i in range(size):
        ids[i] = events.decode_u8(offset + i)

    return ids


## Get location data from an event. Returns empty array if event lacks location
## data, or `which` is greater than the number of location data stored.
func get_event_location(type: Type, event: int, which: int = 1) -> PackedVector3Array:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return []

    var offset: int = _get_event_data_offset(events, event, d_LOCATION, which)
    if offset < 0:
        return []

    # position
    var p: Vector3
    p.x = events.decode_float(offset); offset += 4
    p.y = events.decode_float(offset); offset += 4
    p.z = events.decode_float(offset); offset += 4

    # direction
    var d: Vector3
    d.x = events.decode_float(offset); offset += 4
    d.y = events.decode_float(offset); offset += 4
    d.z = events.decode_float(offset)

    return [p, d]

## Get travel data from an event, an array containing a Vector3 `direction` and
## a float `distance`. Returns an empty array if event lacks location data, or
## `which` is greater than the number of location data stored.
func get_event_travel(type: Type, event: int, which: int = 1) -> Array[Variant]:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return []

    var offset: int = _get_event_data_offset(events, event, d_TRAVEL, which)
    if offset < 0:
        return []

    # direction
    var d: Vector3
    d.x = events.decode_float(offset); offset += 4
    d.y = events.decode_float(offset); offset += 4
    d.z = events.decode_float(offset); offset += 4

    # distance
    var s: float = events.decode_float(offset)

    return [d, s]

## Get forward vector data from an event. Returns Vector3.ZERO if event lacks
## forward data, or `which` is greater than the number of forward data stored.
func get_event_forward(type: Type, event: int, which: int = 1) -> Vector3:
    var events: PackedByteArray = _get_events_reference(type)
    if not events:
        return Vector3.ZERO

    var offset: int = _get_event_data_offset(events, event, d_FORWARD, which)
    if offset < 0:
        return Vector3.ZERO

    var f: Vector3
    f.x = events.decode_float(offset); offset += 4
    f.y = events.decode_float(offset); offset += 4
    f.z = events.decode_float(offset)

    return f


## Internal. Updates the event to prepare it for a new data element. Returns the
## offset to be used for writing the data.
func _event_add_data(event: PackedByteArray, type: int, size: int) -> int:
    var old_size: int = event_get_size(event)
    var data_count: int = event_get_data_count(event)
    var new_size: int = old_size + size + 1
    event.resize(new_size)
    event_set_size(event, new_size)
    event_set_data_count(event, data_count + 1)
    event.encode_u8(old_size, type)

    return old_size + 1


## Add the current game time data
func event_add_game_time(event: PackedByteArray) -> void:
    var offset: int = _event_add_data(event, d_GAMETIME, d_GAMETIME_SIZE)

    event.encode_u32(offset, GlobalWorld.game_time); offset += 4
    event.encode_u8(offset, int(GlobalWorld.game_time_frac * 256.0))

## Add the current world local hour time
func event_add_time_of_day(event: PackedByteArray) -> void:
    var offset: int = _event_add_data(event, d_TIMEOFDAY, d_TIMEOFDAY_SIZE)

    var day: DynamicDay = GlobalWorld.get_day_time()
    var time: float
    if day:
        time = day.local_hour
    else:
        time = -1

    event.encode_half(offset, time)

## Add node path data
func event_add_node_path(event: PackedByteArray, node_path: NodePath) -> void:
    var path_str: StringName = node_path.get_concatenated_names()
    if node_path.is_absolute():
        path_str = '/' + path_str

    var bytes: PackedByteArray = path_str.to_utf8_buffer()
    var size: int = bytes.size()

    var offset: int = _event_add_data(event, d_NODEPATH, size + 2)

    event.encode_u16(offset, size); offset += 2

    for i in range(size):
        event[offset + i] = bytes[i]

## Add an array of group names. Groups must be global groups.
func event_add_groups(event: PackedByteArray, groups: Array[StringName]) -> void:
    var size: int = groups.size()
    var ids: PackedInt32Array = []
    for group in groups:
        var group_id: int = GlobalWorld.Groups.get_group_id(group)
        if group_id == -1:
            push_error('Cannot add non-global group "' + group + '" to sensory memory')
            continue
        ids.append(group_id)

    var offset: int = _event_add_data(event, d_GROUPS, 1 + ids.size())

    event.encode_u8(offset, ids.size()); offset += 1
    for id in ids:
        event.encode_u8(offset, id); offset += 1

## Add location data. Contains a position and direction
func event_add_location(event: PackedByteArray, position: Vector3, direction: Vector3) -> void:
    var offset: int = _event_add_data(event, d_LOCATION, d_LOCATION_SIZE)

    # position
    event.encode_float(offset, position.x); offset += 4
    event.encode_float(offset, position.y); offset += 4
    event.encode_float(offset, position.z); offset += 4

    # direction
    event.encode_float(offset, direction.x); offset += 4
    event.encode_float(offset, direction.y); offset += 4
    event.encode_float(offset, direction.z)

## Add travel data, containing a Vector3 direction and float distance
func event_add_travel(event: PackedByteArray, direction: Vector3, distance: float) -> void:
    var offset: int = _event_add_data(event, d_TRAVEL, d_TRAVEL_SIZE)

    event.encode_float(offset, direction.x); offset += 4
    event.encode_float(offset, direction.y); offset += 4
    event.encode_float(offset, direction.z); offset += 4
    event.encode_float(offset, distance)

## Add forward vector, a Vector3 direction
func event_add_forward(event: PackedByteArray, forward: Vector3) -> void:
    var offset: int = _event_add_data(event, d_FORWARD, d_FORWARD_SIZE)

    event.encode_float(offset, forward.x); offset += 4
    event.encode_float(offset, forward.y); offset += 4
    event.encode_float(offset, forward.z)
