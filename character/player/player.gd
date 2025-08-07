@tool

class_name Player extends CharacterBase

@onready var camera_target: Node3D = %CameraTarget
@onready var camera_3d: Camera3D = %Camera3D
@onready var hurtbox: HurtBox = %Hurtbox
@onready var weapon_node: WeaponNode = %WeaponNode
@onready var aim_target: RayCast3D = %AimTarget


@export_group("Combat")
@export var life: LifeResource
@export var right_hand: bool = true

@export_group("Movement")
@export var look_speed: float = 0.55

@export_group("Controls")
@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction
@export var fire_primary: GUIDEAction
@export var aim: GUIDEAction
@export var flashlight: GUIDEAction
@export var charge: GUIDEAction
@export var melee: GUIDEAction
@export var weapon_next: GUIDEAction
@export var weapon_previous: GUIDEAction
@export var reload: GUIDEAction
@export var unload: GUIDEAction
@export var switch_ammo: GUIDEAction


var score: int = 0:
    set = set_score


var weapons: Dictionary = {}
var weapon_index: int = 0

var ammo_bank: Dictionary = {}

## Melee can be activated
var _melee_ready: bool = true

## Timer for doing a full reload.
## Tap to full reload, hold for controlled reload.
var _weapon_reload_time: int

func _ready() -> void:
    super._ready()

    weapons = weapons.duplicate()

    if Engine.is_editor_hint():
        return

    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon_node.ammo_bank = ammo_bank
    weapon_node.ammo_updated.connect(update_ammo)

    connect_hurtboxes()
    life.died.connect(on_death)
    life.hurt.connect(on_hurt)
    life.check_health()

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        camera_3d.global_transform = camera_target.global_transform
        return

    rotation_degrees.y -= look.value_axis_2d.x * look_speed
    camera_3d.rotation.y = rotation.y
    camera_3d.rotation_degrees.x = clampf(
        camera_3d.rotation_degrees.x - look.value_axis_2d.y * look_speed,
        -89, 89
    )

    var move_length: float = move.value_axis_3d.length()

    if is_zero_approx(move_length):
        movement_direction = Vector3.ZERO
    else:
        movement_direction = basis * move.value_axis_3d.normalized()

    if jump.is_triggered() or jump.is_ongoing():
        do_jump()

    update_weapon_node(delta)


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    # NOTE: Only process input in _process(), so we do not
    # miss inputs shorter than a physics frame.

    update_movement(delta)

func update_weapon_node(delta: float) -> void:
    if not weapon_index:
        return

    update_weapon_switch()

    weapon_node.set_walking(!movement_direction.is_zero_approx())

    if switch_ammo.is_triggered():
        weapon_node.switch_ammo()

    var cancel_reloads: bool = false
    var triggered: bool = fire_primary.is_triggered()
    weapon_node.update_trigger(triggered, delta)

    if triggered:
        cancel_reloads = true

    if melee.is_triggered():
        cancel_reloads = true
        if _melee_ready and weapon_node.melee():
            _melee_ready = false
    else:
        _melee_ready = true

    if charge.is_triggered():
        cancel_reloads = true
        weapon_node.charge()

    if reload.is_triggered():
        if _weapon_reload_time == 0:
            _weapon_reload_time = Time.get_ticks_msec()

        weapon_node.continue_reload = true
        weapon_node.reload()
    else:
        weapon_node.continue_reload = false
        var elapsed: int = Time.get_ticks_msec() - _weapon_reload_time
        if elapsed < 500:
            weapon_node.full_reload = true
        _weapon_reload_time = 0

    if unload.is_triggered():
        weapon_node.continue_unload = true
        weapon_node.unload()
    else:
        weapon_node.continue_unload = false

    if cancel_reloads:
        weapon_node.continue_reload = false
        weapon_node.full_reload = false


func on_hurt(_from: Node3D, _part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    get_tree().call_group('hud', 'update_health', life.health / life.max_health)


func on_death() -> void:
    print('Gah! I died!')

    get_tree().call_group('world', 'on_player_death')

func update_weapon_switch() -> void:
    var next_weapon_dir: int = 0
    if weapon_next.is_triggered():
        next_weapon_dir += 1
    if weapon_previous.is_triggered():
        next_weapon_dir -= 1

    if next_weapon_dir == 0:
        return

    var max_loop: int = 10
    var next_slot: int = weapon_index + next_weapon_dir

    while next_slot != weapon_index and max_loop > 0:
        max_loop -= 1

        if next_slot < 1:
            next_slot = 10
        elif next_slot > 10:
            next_slot = 1

        if weapons.has(next_slot):
            select_weapon(next_slot)
            return

        next_slot += next_weapon_dir

func select_weapon(slot: int) -> void:
    if not weapons.has(slot):
        push_warning('Cannot select weapon ' + str(slot) + '!')
        return

    if weapon_index == slot:
        return

    weapon_index = slot
    weapon_node.weapon_type = weapons[slot]
    update_ammo()

func set_score(value: int) -> void:
    if score == value:
        return

    score = value

    get_tree().call_group('hud', 'update_score', score)

func update_ammo() -> void:
    get_tree().call_group('hud', 'update_weapon_ammo', weapon_node.weapon_type)


func pickup_item(item: Pickup) -> void:
    if item.item_type is WeaponResource:
        var weapon: WeaponResource = item.item_type as WeaponResource
        if weapons.has(weapon.slot):
            print('Already have slot ' + str(weapon.slot))

            # Add loaded ammo to bank
            if item.item_count > 0:
                add_ammo(weapon.get_default_ammo(), item.item_count)

            return

        weapons[weapon.slot] = weapon
        print('Picked up ' + str(weapon.name) + '!')
        item.queue_free()

        if weapon_index == 0:
            select_weapon(weapon.slot)

        # Weapon comes with ammo, preload it with first ammo type
        if item.item_count > 0:
            add_ammo(weapon.get_default_ammo(), item.item_count)
            weapon.load_rounds()
            update_ammo()

    elif item.item_type is AmmoResource:
        var ammo: AmmoResource = item.item_type as AmmoResource

        add_ammo(ammo, item.item_count)

        # If holding a weapon with no ammo stock, get next ammo
        if weapon_index and not weapon_node.has_ammo_stock():
            weapon_node.switch_ammo()

        update_ammo()

        item.queue_free()

func add_ammo(ammo: AmmoResource, amount: int) -> void:
    if not ammo_bank.has(ammo.type):
        ammo_bank.set(ammo.type, {
            'amount': 0,
            'ammo': ammo
        })
    ammo_bank.get(ammo.type).amount += amount

func connect_hurtboxes() -> void:
    hurtbox.enable()
    life.connect_hurtbox(hurtbox)

    weapon_node.set_melee_excluded_hurboxes([hurtbox])
