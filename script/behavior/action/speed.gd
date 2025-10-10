class_name BehaviorActionSpeed extends BehaviorAction


const NAME = &"speed"

func name() -> StringName:
    return NAME


## Speed to move at
var speed: float


@warning_ignore("shadowed_variable")
func _init(speed: float) -> void:
    self.speed = speed
