## Action requesting to navigate to some position
class_name BehaviorActionNavigate extends BehaviorAction


## Emitted by the acting CharacterBase when the navigation finishes
@warning_ignore("unused_signal")
signal on_complete()


## Direction to travel
var direction: Vector3

## Distance to travel
var distance: float

## Desired target distance from the point specified
var target_distance: float = 1.0

## Set by the acting CharacterBase if the requested travel location is already reached
var completed: bool = false


@warning_ignore("shadowed_variable")
func _init(direction: Vector3, distance: float) -> void:
    self.direction = direction
    self.distance = distance

func get_global_position(parent: Node3D) -> Vector3:
    return parent.global_position + (direction * distance)
