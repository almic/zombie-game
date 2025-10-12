class_name BehaviorMemoryInterest extends BehaviorMemory


const NAME = &"interest"

func name() -> StringName:
    return NAME


func can_decay() -> bool:
    return true

func decay(seconds: int) -> void:
    for node_name in interesting_nodes.keys():
        decay_node(node_name, seconds)


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var interesting_nodes: Dictionary[StringName, PackedByteArray]

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var total_interest: int = 0


var _max_interest: int
var _inv_decay_rates: PackedFloat32Array


func get_interest() -> int:
    return min(_max_interest, total_interest)

## Set the decay rate array. Rates are clamped to 65536 seconds maximum, as the
## stored rate timers are u16 + u8 fractional seconds
func assign_decay_rates(rates: PackedFloat32Array) -> void:
    _inv_decay_rates = rates.duplicate()
    for i in range(_inv_decay_rates.size()):
        _inv_decay_rates[i] = clampf(_inv_decay_rates[i], 0.0, 65536.0)

## Set the maximum reportable interest value. Clamped to the range [0, 255]
func assign_max_interest(max_interest: int) -> void:
    _max_interest = clampi(max_interest, 0, 255)


func decay_node(node_name: StringName, seconds: int) -> void:
    # NOTE: do not write 'as PackedByteArray' or it will make a copy!
    var node: PackedByteArray = interesting_nodes.get(node_name)
    if not node:
        return

    var interest: int = node_get_interest(node)
    var rate: float = node_get_decay_rate(node)
    var decay_timer: float = node_get_decay_timer(node)

    decay_timer += seconds
    while decay_timer >= rate:
        decay_timer -= rate
        interest -= 1
        total_interest -= 1

    node_set_interest(node, interest)
    node_set_decay_timer(node, decay_timer)


const d_INTEREST = 0
const d_INTEREST_LEN = 1
const d_DECAYIDX = d_INTEREST + d_INTEREST_LEN
const d_DECAYIDX_LEN = 1
const d_DECAYTIMER = d_DECAYIDX + d_DECAYIDX_LEN
const d_DECAYTIMER_LEN = 3
const d_REFRESH = d_DECAYTIMER + d_DECAYTIMER_LEN
const e_REFRESH_LEN = 3


func node_get_interest(node: PackedByteArray) -> int:
    return node.decode_u8(d_INTEREST)

func node_set_interest(node: PackedByteArray, interest: int) -> void:
    node.encode_u8(d_INTEREST, interest)

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
