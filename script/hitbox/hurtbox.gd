## Simple Area3D extension that adds a signal for being hit.
## HurtBoxes are only monitorable, they do not themselves detect collision.
class_name HurtBox extends Area3D

## Called by attackers when damage should be taken
signal on_hit(from: Node3D, to: HurtBox, damage: float)

func _ready() -> void:
    monitoring = false # does not monitor hits
    monitorable = false

func enable() -> void:
    monitorable = true

func disable() -> void:
    monitorable = false

## Signal that a hit should be recieved
func do_hit(from: Node3D, damage: float):
    on_hit.emit(from, self, damage)
