class_name BehaviorActionAttack extends BehaviorAction


## Node to attack
var target: Node3D


@warning_ignore("shadowed_variable")
func _init(target: Node3D) -> void:
    self.target = target
