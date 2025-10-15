class_name BehaviorActionAttack extends BehaviorAction


const NAME = &"attack"

func name() -> StringName:
    return NAME

func can_complete() -> bool:
    return true


## Node to attack
var target: Node3D

## If the attack is a melee attack
var is_melee: bool


@warning_ignore("shadowed_variable")
func _init(target: Node3D, is_melee: bool = false) -> void:
    self.target = target
    self.is_melee = is_melee
