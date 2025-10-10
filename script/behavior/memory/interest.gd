class_name BehaviorMemoryInterest extends BehaviorMemory


const NAME = &"sensory"

func name() -> StringName:
    return NAME

func can_decay() -> bool:
    return true


var interest: int = 0

var decay_rate: float = 1.0:
    set(value):
        decay_rate = maxf(value, 0.01)
        _inv_decay_rate = 1.0 / value
var _inv_decay_rate: float = INF

var decay_timer: float = 0.0


func _init() -> void:
    decay_rate = decay_rate

func decay(seconds: int) -> void:
    decay_timer += seconds
    while decay_timer > _inv_decay_rate:
        decay_timer -= _inv_decay_rate
        interest -= 1
