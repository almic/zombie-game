class_name BehaviorMemoryInterest extends BehaviorMemory


const NAME = &"interest"

func name() -> StringName:
    return NAME


func can_decay() -> bool:
    return _start_decay or _total_interest > 0 or _longest_timer > 0

func decay(seconds: float) -> void:
    _longest_timer = 0
    _total_interest = 0
    _start_decay = false
    for node_name in interesting_nodes.keys():
        var results := decay_node(node_name, seconds)
        var interest: float = results[0]
        var time_left: float = results[1]
        if time_left > _longest_timer:
            _longest_timer = time_left
        _total_interest += interest


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var interesting_nodes: Dictionary[StringName, PackedByteArray]

var _total_interest: float = 0
var _max_interest: int
var _inv_decay_rates: PackedFloat32Array
var _longest_timer: float = 0
var _start_decay: bool = false


func get_interest() -> int:
    # NOTE: do not round interest, otherwise we get thresholds meeting early, or
    #       in error if the highest we get is 19.5 for something that uses 20.
    return mini(_max_interest, int(_total_interest))

## Set the decay rate array. Rates are clamped to 65536 seconds maximum, as the
## stored rate timers are u16 + u8 fractional seconds
func assign_decay_rates(rates: PackedFloat32Array) -> void:
    _inv_decay_rates = rates.duplicate()
    for i in range(_inv_decay_rates.size()):
        _inv_decay_rates[i] = clampf(_inv_decay_rates[i], 0.0, 65536.0)

## Set the maximum reportable interest value. Clamped to the range [0, 255]
func assign_max_interest(max_interest: int) -> void:
    _max_interest = clampi(max_interest, 0, 255)

## Call so that decay runs on the next tick, otherwise interest changes may fail
## to decay at all.
func start_decay() -> void:
    _start_decay = true

## Decays a node interest and refresh timer according to the decay rate.
## Returns the interest and refresh timer value, used by the decay memory method
## to track total interest and the longest timer.
func decay_node(node_name: StringName, seconds: float) -> PackedFloat32Array:
    # NOTE: do not write 'as PackedByteArray' or it will make a copy!
    var node: PackedByteArray = interesting_nodes.get(node_name)
    if not node:
        return [0.0, 0.0]

    var interest: float = node_get_interest(node)
    var refresh_timer: float = node_get_refresh_time(node)

    # Nothing to do
    if interest == 0.0 and refresh_timer == 0.0:
        return [0.0, 0.0]

    if interest > 0.0:
        var change: int = 0
        var rate: float = node_get_decay_rate(node)
        var decay_timer: float = node_get_decay_timer(node)

        decay_timer += seconds
        while decay_timer >= rate:
            decay_timer -= rate
            if change < interest:
                change += 1

        if change > 0:
            interest -= change
            node_set_interest(node, interest)

        node_set_decay_timer(node, decay_timer)
    else:
        # Decay refresh when interest is zero
        refresh_timer -= seconds
        if refresh_timer <= 0.0:
            refresh_timer = 0.0

            # NOTE: reset decay timer to prevent early decay in the future
            node_set_decay_timer(node, 0.0)

        node_set_refresh_time(node, refresh_timer)

    return [interest, refresh_timer]


const d_INTEREST = 0
const d_INTEREST_LEN = 2
const d_DECAYIDX = d_INTEREST + d_INTEREST_LEN
const d_DECAYIDX_LEN = 1
const d_DECAYTIMER = d_DECAYIDX + d_DECAYIDX_LEN
const d_DECAYTIMER_LEN = 3
const d_REFRESH = d_DECAYTIMER + d_DECAYTIMER_LEN
const d_REFRESH_LEN = 3

const d_LENGTH = d_REFRESH + d_REFRESH_LEN


func get_node(node_name: StringName) -> PackedByteArray:
    if interesting_nodes.has(node_name):
        return interesting_nodes.get(node_name)

    var data := PackedByteArray()
    data.resize(d_LENGTH)
    data.fill(0)

    interesting_nodes.set(node_name, data)
    return data

func node_get_interest(node: PackedByteArray) -> float:
    var whole: int = node.decode_u8(d_INTEREST)
    var frac: float = float(node.decode_u8(d_INTEREST + 1)) / 256.0
    return float(whole) + frac

func node_set_interest(node: PackedByteArray, interest: float) -> void:
    # NOTE: round the fractional parts, because we will be adding and subtracting
    #       and it may happen to result in a value like 9.9999999999999997, which
    #       should obviously just be rounded to 10.
    var whole: int = int(interest)
    var frac: int = roundi((interest - whole) * 256.0)

    if whole > 255:
        frac = 255
    elif frac > 255 and whole < 255:
        whole += 1
        frac = 0

    node.encode_u8(d_INTEREST, clampi(whole, 0, 255))
    node.encode_u8(d_INTEREST + 1, clampi(frac, 0, 255))

func node_get_decay_rate(node: PackedByteArray) -> float:
    var idx: int = node.decode_u8(d_DECAYIDX)
    return _inv_decay_rates[idx]

func node_set_decay_rate_id(node: PackedByteArray, id: int) -> void:
    node.encode_u8(d_DECAYIDX, id)

func node_get_decay_timer(node: PackedByteArray) -> float:
    var seconds: int = node.decode_u16(d_DECAYTIMER)
    var frac: float = float(node.decode_u8(d_DECAYTIMER + 2)) / 256.0
    return float(seconds) + frac

func node_set_decay_timer(node: PackedByteArray, decay_time: float) -> void:
    var seconds: int = int(decay_time)
    var frac: int = int((decay_time - seconds) * 256.0)

    node.encode_u16(d_DECAYTIMER, seconds)
    node.encode_u8(d_DECAYTIMER + 2, frac)

func node_get_refresh_time(node: PackedByteArray) -> float:
    var seconds: int = node.decode_u16(d_REFRESH)
    var frac: float = float(node.decode_u8(d_REFRESH + 2)) / 256.0
    return float(seconds) + frac

func node_set_refresh_time(node: PackedByteArray, refresh_time: float) -> void:
    var seconds: int = int(refresh_time)
    var frac: int = int((refresh_time - seconds) * 256.0)

    node.encode_u16(d_REFRESH, seconds)
    node.encode_u8(d_REFRESH + 2, frac)
