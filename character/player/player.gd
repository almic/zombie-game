@tool

class_name Player extends CharacterBase

@onready var camera_target: Node3D = %CameraTarget
@onready var camera_3d: Camera3D = %Camera3D
@onready var hurtbox: HurtBox = %Hurtbox
@onready var weapon: WeaponNode = %WeaponNode
@onready var aim_target: RayCast3D = %AimTarget


@export_group("Combat")
@export var life: LifeResource

@export_group("Movement")
@export var look_speed: float = 0.55

@export_group("Controls")
@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction
@export var fire_primary: GUIDEAction


var score: int = 0:
    set = set_score


func _ready() -> void:
    super._ready()

    if Engine.is_editor_hint():
        return

    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon.set_trigger(fire_primary)

    connect_hurtboxes()
    life.died.connect(on_death)
    life.hurt.connect(on_hurt)
    life.check_health()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        camera_3d.global_transform = camera_target.global_transform
        return

    rotation_degrees.y -= look.value_axis_2d.x * look_speed
    camera_3d.rotation.y = rotation.y
    camera_3d.rotation_degrees.x = clampf(
        camera_3d.rotation_degrees.x - look.value_axis_2d.y * look_speed,
        -89, 89
    )

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    var move_length: float = move.value_axis_3d.length()

    if is_zero_approx(move_length):
        movement_direction = Vector3.ZERO
    else:
        movement_direction = basis * move.value_axis_3d.normalized()

    if jump.is_triggered() or jump.is_ongoing():
        do_jump()

    update_movement(delta)

func on_hurt(_from: Node3D, _part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    get_tree().call_group('hud', 'update_health', life.health / life.max_health)


func on_death() -> void:
    print('Gah! I died!')

    get_tree().call_group('world', 'on_player_death')


func set_score(value: int) -> void:
    if score == value:
        return

    score = value

    get_tree().call_group('hud', 'update_score', score)

func connect_hurtboxes() -> void:
    hurtbox.enable()
    life.connect_hurtbox(hurtbox)
