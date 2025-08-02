class_name LifeResource extends Resource


signal died()
signal hurt(from: Node3D, part: HurtBox, damage: float, hit: Dictionary)

@export var max_health: float = 100.0
@export var health: float = 100.0

var is_alive: bool = true

var _hurtboxes: Dictionary = {}
var _hitboxes: PackedInt64Array = []
var _groups: Array[StringName] = []

var _last_hitbox_frame: int = -1

func add_group_exception(group: StringName) -> void:
    if _groups.has(group):
        return
    _groups.append(group)

func add_hitbox_exception(hit_box: HitBox) -> void:
    var id: int = hit_box.get_rid().get_id()
    if _hitboxes.has(id):
        return
    _hitboxes.append(id)

func connect_hurtbox(hurt_box: HurtBox, multiplier: float = 1.0) -> void:
    _hurtboxes.set(hurt_box.get_rid(), multiplier)
    hurt_box.on_hit.connect(_on_hit)

func check_health(emit_died: bool = true) -> void:
    if health > 0.0001:
        return

    if is_alive:
        is_alive = false
        if emit_died:
            died.emit()

func _on_hit(from: Node3D, part: HurtBox, hit: Dictionary, damage: float) -> void:
    if not is_alive:
        return

    var is_hitbox: bool = hit.has('hitbox')
    if is_hitbox:
        if _hitboxes.has(hit.hitbox):
            return

        var frame: int = Engine.get_physics_frames()
        if _last_hitbox_frame == frame:
            return
        _last_hitbox_frame = frame

    var part_id: RID = part.get_rid()
    if not _hurtboxes.has(part_id):
        return

    if from:
        for group in from.get_groups():
            if _groups.has(group):
                return

    if not is_hitbox:
        damage *= _hurtboxes.get(part_id, 1.0)
    health -= damage

    check_health(false)

    hurt.emit(from, part, damage, hit)

    if not is_alive:
        died.emit()
