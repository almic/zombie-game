## Simple Area3D extension that detects HurtBoxes and signals them.
## HitBoxes monitor for collision with HurtBoxes, they are not detectable.
## HitBoxes only hit once per HurtBox per activation, they must be enabled and
## disabled to apply hits.
class_name HitBox extends Area3D

## Passed to HurtBoxes that collide
@export var hitbox_owner: NodePath:
    set(value):
        hitbox_owner = value
        if is_node_ready():
            _node_owner = get_node(hitbox_owner)
var _node_owner: Node3D

## Passed to HurtBoxes that collide. Be aware that owners may override this value!
@export var damage: float

## Signal a hurtbox only once per activation
var _cached_hurtboxes: PackedInt64Array = []


func _ready() -> void:
    monitorable = false
    monitoring = false
    area_entered.connect(_on_hurtbox)
    _node_owner = get_node(hitbox_owner)

    _cached_hurtboxes = _cached_hurtboxes.duplicate()

func is_enabled() -> bool:
    return monitoring

func enable() -> void:
    monitoring = true

    # TODO: this never does anything as the list isn't updated yet
    # Check for any overlapping hurtboxes
    for area in get_overlapping_areas():
        if area is HurtBox:
            _on_hurtbox(area)

func disable() -> void:
    monitoring = false
    _cached_hurtboxes.clear()

func _on_hurtbox(hurtbox: HurtBox) -> void:
    var id: int = hurtbox.get_rid().get_id()
    if _cached_hurtboxes.has(id):
        return

    _cached_hurtboxes.append(id)
    hurtbox.do_hit(_node_owner, {
        'position': hurtbox.global_position,
        'from': _node_owner.global_position,
        'hitbox': self.get_rid().get_id()
    }, damage)
