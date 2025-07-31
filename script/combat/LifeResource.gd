class_name LifeResource extends Resource


signal died()

@export var health: float = 100.0

var is_alive: bool = true

var _hurtboxes: Dictionary = {}

func connect_hurtbox(hurt_box: HurtBox, multiplier: float = 1.0) -> void:
    _hurtboxes.set(hurt_box.get_rid(), multiplier)
    hurt_box.on_hit.connect(_on_hit)

func check_health() -> void:
    if health > 0.0001:
        return

    if is_alive:
        is_alive = false
        died.emit()

func _on_hit(_from: Node3D, part: HurtBox, _hit: Dictionary, damage: float) -> void:
    if not is_alive:
        return

    var part_id: RID = part.get_rid()
    if not _hurtboxes.has(part_id):
        return

    health -= damage * _hurtboxes.get(part_id, 1.0)

    check_health()
