## Action requesting to navigate to some position
class_name BehaviorActionNavigate extends BehaviorAction


const NAME = &"navigate"

func name() -> StringName:
    return NAME

func can_complete() -> bool:
    return true


## Direction to travel
var direction: Vector3

## Distance to travel
var distance: float

## Game time when this event was created
var time: float

## Desired target distance from the point specified
var target_distance: float

## Set by the acting CharacterBase if the requested travel location is already reached
var _completed: bool = false
var _success: bool = false


@warning_ignore("shadowed_variable")
func _init(direction: Vector3, distance: float, target_distance: float = 1.0) -> void:
    self.direction = direction
    self.distance = distance
    self.target_distance = target_distance
    time = GlobalWorld.get_game_time()

func complete(success: bool = true) -> void:
    _completed = true
    _success = success

func is_complete() -> bool:
    return _completed

func is_success() -> bool:
    return _success

func is_failed() -> bool:
    return _completed and !_success

func get_global_position(parent: Node3D) -> Vector3:
    return parent.global_position + (direction * distance)
