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
@export var weapon_next: GUIDEAction
@export var weapon_previous: GUIDEAction
@export var reload: GUIDEAction
@export var switch_ammo: GUIDEAction


var score: int = 0:
    set = set_score


var weapons: Dictionary = {}
var weapon_index: int = 0

var ammo_bank: Dictionary = {}


func _ready() -> void:
    super._ready()

    weapons = weapons.duplicate()

    if Engine.is_editor_hint():
        return

    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon_node.set_trigger(fire_primary)
    weapon_node.set_reload(reload)
    weapon_node.set_ammo_switch(switch_ammo)
    weapon_node.set_ammo_bank(ammo_bank)

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

    var move_length: float = move.value_axis_3d.length()

    if is_zero_approx(move_length):
        movement_direction = Vector3.ZERO
    else:
        movement_direction = basis * move.value_axis_3d.normalized()

    if weapon_node._weapon_scene:
        weapon_node._weapon_scene.set_walking(!movement_direction.is_zero_approx())


    if jump.is_triggered() or jump.is_ongoing():
        do_jump()


    var next_weapon_dir: int = 0
    if weapon_next.is_triggered():
        next_weapon_dir += 1
    if weapon_previous.is_triggered():
        next_weapon_dir -= 1

    if next_weapon_dir != 0:
        var max_loop: int = 10
        var next_slot: int = weapon_index + next_weapon_dir
        var found: bool = false

        while next_slot != weapon_index and max_loop > 0:
            max_loop -= 1

            if next_slot < 1:
                next_slot = 10
            elif next_slot > 10:
                next_slot = 1

            if weapons.has(next_slot):
                found = true
                break

            next_slot += next_weapon_dir

        if found:
            select_weapon(next_slot)


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    # NOTE: Only process input in _process(), so we do not
    # miss inputs shorter than a physics frame.

    update_movement(delta)


func on_hurt(_from: Node3D, _part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    get_tree().call_group('hud', 'update_health', life.health / life.max_health)


func on_death() -> void:
    print('Gah! I died!')

    get_tree().call_group('world', 'on_player_death')

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
    if not weapon_node.weapon_type:
        return

    if weapon_node.weapon_type.trigger_mechanism.is_melee:
        get_tree().call_group('hud', 'update_ammo', '-', '-')
        return

    var load_amount: int = weapon_node.weapon_type.get_reserve_total()
    if weapon_node.weapon_type.is_chambered():
        load_amount += 1

    var stock: int = 0
    if weapon_node._ammo_stock:
        stock = weapon_node._ammo_stock.amount

    get_tree().call_group('hud', 'update_ammo', load_amount, stock)

func swap_hand(_time: float = 0.0) -> void:
    print('player swaps hand!')

func pickup_item(item: Pickup) -> void:
    if item.item_type is WeaponResource:
        var weapon: WeaponResource = item.item_type as WeaponResource
        if weapons.has(weapon.slot):
            print('Already have slot ' + str(weapon.slot))
            return

        weapons[weapon.slot] = weapon
        print('Picked up ' + str(weapon.name) + '!')
        item.queue_free()

        if weapon_index == 0:
            select_weapon(weapon.slot)

        # Weapon comes with ammo, preload it with first ammo type
        if item.item_count > 0:
            var ammo_type: int = weapon.get_default_ammo_type()
            weapon.load_rounds(ammo_type, item.item_count)
            update_ammo()

    elif item.item_type is AmmoResource:
        var ammo: AmmoResource = item.item_type as AmmoResource
        if not ammo_bank.has(ammo.ammo_type):
            ammo_bank.set(ammo.ammo_type, {
                'amount': 0,
                'ammo': ammo
            })
        ammo_bank.get(ammo.ammo_type).amount += item.item_count

        # If holding a weapon with no ammo stock, get next ammo
        if weapon_index and not weapon_node._ammo_stock.get('amount', 0):
            weapon_node.switch_ammo()

        update_ammo()

        item.queue_free()

func connect_hurtboxes() -> void:
    hurtbox.enable()
    life.connect_hurtbox(hurtbox)
