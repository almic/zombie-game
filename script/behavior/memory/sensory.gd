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

enum Response {
    STARTED = 1,
    COMPLETE = 2
}


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var sensory_logs: Dictionary[Type, PackedByteArray]

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var event_idxs: Dictionary[Type, PackedInt32Array]

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
func decay(delta: int) -> void:
    for type in event_idxs.keys():
        for event in event_idxs[type]:
            event_decay(type, event, delta)


const e_SIZE = 0
const e_SIZE_LEN = 2
const e_TYPE = e_SIZE + e_SIZE_LEN
const e_TYPE_LEN = 1
const e_RESPONSE = e_TYPE + e_TYPE_LEN
const e_RESPONSE_LEN = 1
const e_EXPIRE = e_RESPONSE + e_RESPONSE_LEN
const e_EXPIRE_LEN = 2
const e_DATA = e_EXPIRE + e_EXPIRE_LEN
const e_DATA_LEN = 1
const e_DATA_ARRAY = e_DATA + e_DATA_LEN


## Start a sensory event
func start_event(type: Type) -> PackedByteArray:
    var bytes: PackedByteArray = []

    var header_size: int = (
              e_TYPE_LEN
            + e_RESPONSE_LEN
            + e_EXPIRE_LEN
            + e_DATA_LEN
    )

    bytes.resize(e_SIZE_LEN + header_size)

    bytes.encode_u16(e_SIZE, bytes.size())
    bytes.encode_u8(e_TYPE, type)
    bytes.encode_u8(e_RESPONSE, 0)
    bytes.encode_u16(e_EXPIRE, 1)
    bytes.encode_u8(e_DATA, 0)

    return bytes

## Write the event to memory
func finish_event(event: PackedByteArray) -> void:
    # add event to front of log
    var size: int = event.decode_u16(e_SIZE)
    var type: Type = event.decode_u8(e_TYPE) as Type
    var old_log: PackedByteArray = sensory_logs.get(type, PackedByteArray())
    event.append_array(old_log)
    old_log.clear() # can clear this now

    # update indexes
    var indexes: PackedInt32Array = event_idxs.get_or_add(type, PackedInt32Array())
    var idx_len: int = indexes.size()
    indexes.resize(idx_len + 1)
    for i in range(idx_len - 1, 0, -1): # NOTE: up to the second element only
        indexes[i] = indexes[i - 1] + size
    indexes[0] = 0

    sensory_logs.set(type, event)
    event_count += 1

# Decay the timer of an event by some number of seconds. If the event timer reaches
# zero, it is removed from the event log.
func event_decay(type: Type, event: int, seconds: int) -> void:
    var event_log: PackedByteArray = sensory_logs.get(type)
    var time: int = event_log.decode_u16(event + e_EXPIRE)
    time -= seconds

    if time > 0:
        event_log.encode_u16(event + e_EXPIRE, time)
        return

    var indexes: PackedInt32Array = event_idxs.get(type)
    var event_id: int = indexes.bsearch(event, false) - 1
    var size: int = event_log.decode_u16(event + e_SIZE)
    var log_size: int = event_log.size()

    # Move later events forward
    for i in range(event + size, log_size - 1):
        event_log[i - size] = event_log[i]

    # trim log
    event_log.resize(log_size - size)

    # erase index
    indexes.remove_at(event_id)

    event_count -= 1

## Set the expire delay of this event
func event_set_expire(event: PackedByteArray, seconds: int) -> void:
    event.encode_u16(e_EXPIRE, seconds)

## Get an event's response value. Returns -1 if the event is not found
func get_event_response(type: Type, event: int) -> int:
    var events: PackedByteArray = sensory_logs.get(type)
    if not events:
        return -1

    return events.decode_u8(event + e_RESPONSE)

## Set an event's response value.
func set_event_response(type: Type, event: int, response: int) -> bool:
    var events: PackedByteArray = sensory_logs.get(type)
    if not events:
        return false

    events.encode_u8(event + e_RESPONSE, response)
    return true


## Unsigned int 32
const d_GAMETIME = 1
const d_GAMETIME_SIZE = 4

## Half precision float for in-game time of day
const d_TIMEOFDAY = 2
const d_TIMEOFDAY_SIZE = 2

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

    var i: int = event + e_DATA_ARRAY
    var data_index: int = 0
    var data_type: int
    while i < size and data_index < data_count:
        data_type = events.decode_u8(i)
        if data_type == search:
            which -= 1
            if which == 0:
                return i + 1
        i += d_STRIDES[data_type] + 1
        data_index += 1

    return -1

## Get game time data from an event. Returns -1 if event lacks game time data,
## or `which` is greater than the number of game time data stored.
func get_event_game_time(type: Type, event: int, which: int = 1) -> int:
    var events: PackedByteArray = sensory_logs.get(type)
    if not events:
        return -1

    var offset: int = _get_event_data_offset(events, event, d_GAMETIME, which)
    if offset < 0:
        return -1

    return events.decode_u32(offset)

## Get time of day data from an event. Returns -1 if event lacks time of day data,
## or `which` is greater than the number of time of day data stored.
func get_event_time_of_day(type: Type, event: int, which: int = 1) -> float:
    var events: PackedByteArray = sensory_logs.get(type)
    if not events:
        return -1

    var offset: int = _get_event_data_offset(events, event, d_TIMEOFDAY, which)
    if offset < 0:
        return -1

    return events.decode_half(offset)

## Get location data from an event. Returns empty array if event lacks location
## data, or `which` is greater than the number of location data stored.
func get_event_location(type: Type, event: int, which: int = 1) -> PackedVector3Array:
    var events: PackedByteArray = sensory_logs.get(type)
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

## Get travel data from an event. Returns an empty array if event lacks location
## data, or `which` is greater than the number of location data stored.
func get_event_travel(type: Type, event: int, which: int = 1) -> Array[Variant]:
    var events: PackedByteArray = sensory_logs.get(type)
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
    var events: PackedByteArray = sensory_logs.get(type)
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
    var old_size: int = event.decode_u16(e_SIZE)
    var data_count: int = event.decode_u8(e_DATA)
    var new_size: int = old_size + size + 1
    event.resize(new_size)
    event.encode_u16(e_SIZE, new_size)
    event.encode_u8(e_DATA, data_count + 1)
    event.encode_u8(old_size, type)

    return old_size + 1


## Add the current game time data
func event_add_game_time(event: PackedByteArray) -> void:
    var offset: int = _event_add_data(event, d_GAMETIME, d_GAMETIME_SIZE)

    event.encode_u32(offset, GlobalWorld.game_time)

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

## Add travel data, containing a direction and
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
