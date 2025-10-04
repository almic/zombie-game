## Action requesting to navigate to some position
class_name BehaviorActionNavigate extends BehaviorAction

var direction: Vector3
var distance: float

@warning_ignore("shadowed_variable")
func _init(direction: Vector3, distance: float) -> void:
    self.direction = direction
    self.distance = distance

func get_global_position(parent: Node3D) -> Vector3:
    return parent.global_position + (direction * distance)
