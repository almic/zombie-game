class_name BehaviorActionTurn extends BehaviorAction


const NAME = &"turn"

func name() -> StringName:
    return NAME

func can_complete() -> bool:
    return true


## Turn rotation to apply from the current direction
var turn: float


@warning_ignore("shadowed_variable")
func _init(turn: float) -> void:
    self.turn = turn
