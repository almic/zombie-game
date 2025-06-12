class_name SpawnPoint
extends Marker3D

var _delay: float = 1.0
var _until_ready: float = 0.0

var can_spawn: bool = true


func _ready() -> void:
    add_to_group('zombie_spawn')


func _process(delta: float) -> void:
    if can_spawn:
        return

    _until_ready -= delta

    if _until_ready <= 0:
        can_spawn = true


func use() -> void:
    can_spawn = false
    _until_ready = _delay
