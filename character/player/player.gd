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

## Fire may be buffered
var _fire_can_buffer: bool = true

## Timer for doing a full reload.
## Tap to full reload, hold for controlled reload.
var _weapon_reload_time: int

## Buffered input
var _last_input: GUIDEAction
var _last_input_timer: float = 0.0
const LAST_INPUT_TIME = 0.2

var _next_input: GUIDEAction
var _next_input_timer: float = 0.0
const GENERIC_INPUT_BUFFER_TIME = 0.8
const FIRE_INPUT_BUFFER_TIME = 0.13


func _ready() -> void:
    super._ready()

    weapons = weapons.duplicate()

    if Engine.is_editor_hint():
        return

    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon_node.ammo_bank = ammo_bank
    weapon_node.ammo_updated.connect(update_ammo)
    weapon_node.reload_complete.connect(on_reload_complete)

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

    if _next_input_timer > 0.0:
        _next_input_timer -= delta
        if _next_input_timer < 0.0001:
            _next_input = null
            _next_input_timer = 0.0

    if _last_input_timer > 0.0:
        if _last_input.is_completed():
            _last_input_timer = 0.0
            _last_input = null
        else:
            _last_input_timer -= delta
            if _last_input_timer < 0.0001:
                _last_input = null
                _last_input_timer = 0.0

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

    var triggered: bool = fire_primary.is_triggered()
    if triggered:
        update_last_input(fire_primary)
    else:
        _fire_can_buffer = true

    var action: WeaponNode.Action = weapon_node.update_trigger(triggered, delta)

    if action == WeaponNode.Action.OKAY:
        _fire_can_buffer = false
    else:
        if triggered:
            if _fire_can_buffer:
                # Use the longer buffer for reloading
                if weapon_node.continue_reload:
                    update_input_buffer(fire_primary)
                else:
                    update_input_buffer(fire_primary, FIRE_INPUT_BUFFER_TIME)
        elif is_input_buffered(fire_primary):
            # NOTE: If the action was blocked, keep trying anyway
            #       because we may be waiting to charge/ reload
            action = weapon_node.update_trigger(true, 0.0)
            if action == WeaponNode.Action.OKAY:
                clear_input_buffer()

    # NOTE: do this after so we can change buffer times if we are reloading
    if triggered:
        weapon_node.continue_reload = false

    if melee.is_triggered():
        weapon_node.continue_reload = false
        update_last_input(melee)
        if _melee_ready or weapon_node.melee():
            # If a melee ever activates, clear the buffer
            if _next_input:
                clear_input_buffer()
            _melee_ready = false
    else:
        _melee_ready = true

    if charge.is_triggered():
        weapon_node.continue_reload = false
        update_last_input(charge)

        # NOTE: Even if the action is blocked, buffer anyway because we
        #       may be waiting to load a round
        action = weapon_node.charge()
        if action != WeaponNode.Action.OKAY:
            update_input_buffer(charge)
    elif is_input_buffered(charge):
        # NOTE: If the action was blocked, keep trying anyway
        #       because we way be waiting to reload
        action = weapon_node.charge()
        if action == WeaponNode.Action.OKAY:
            clear_input_buffer()
    # NOTE: We may have a fire buffered, but we have failed to shoot, so try
    #       charging the weapon in case we were waiting for that
    elif is_input_buffered(fire_primary):
        action = weapon_node.charge()
        if action == WeaponNode.Action.OKAY:
            # Requeue the primary fire action as buffer is too short normally
            update_input_buffer(fire_primary)

    if reload.is_triggered():
        var do_reload: bool = false
        if _weapon_reload_time == 0:
            # Cancel a full reload if we trigger while continue is on
            if weapon_node.continue_reload:
                weapon_node.continue_reload = false
                _weapon_reload_time = -1
            else:
                weapon_node.continue_reload = true
                _weapon_reload_time = Time.get_ticks_msec()
                do_reload = true

        update_last_input(reload)

        if do_reload:
            # NOTE: Even if the action is blocked, buffer anyway because we
            #       may be waiting to cycle a round from reserve
            action = weapon_node.reload()
            if action != WeaponNode.Action.OKAY:
                update_input_buffer(reload)
    else:
        if _weapon_reload_time > 0:
            var elapsed: int = Time.get_ticks_msec() - _weapon_reload_time
            if elapsed > 500:
                weapon_node.continue_reload = false
            _weapon_reload_time = 0
        elif _weapon_reload_time == -1:
            _weapon_reload_time = 0

        if is_input_buffered(reload):
            action = weapon_node.reload()
            if action == WeaponNode.Action.OKAY:
                clear_input_buffer()

    if unload.is_triggered():
        weapon_node.continue_reload = false
        weapon_node.continue_unload = true
        weapon_node.unload()
    else:
        weapon_node.continue_unload = false

func on_reload_complete() -> void:
    # If a reload ended and we wanted to continue, queue a charge
    if weapon_node.continue_reload:
        update_input_buffer(charge)
    # Don't buffer a reload off a reload
    elif _next_input == reload:
        clear_input_buffer()

func on_hurt(_from: Node3D, _part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    get_tree().call_group('hud', 'update_health', life.health / life.max_health)

func on_death() -> void:
    print('Gah! I died!')

    get_tree().call_group('world', 'on_player_death')

func is_input_buffered(action: GUIDEAction) -> bool:
    if _next_input_timer < 0.0001:
        return false

    return action == _next_input

func clear_input_buffer() -> void:
    _next_input = null
    _next_input_timer = 0.0

func update_input_buffer(action: GUIDEAction, time: float = GENERIC_INPUT_BUFFER_TIME) -> void:
    if action == _last_input:
        # If we set the last input this frame, allow to buffer
        if is_equal_approx(_last_input_timer, LAST_INPUT_TIME):
            pass
        elif _last_input_timer > 0.0:
            return

    if _next_input == action:
        if _next_input_timer < 0.5:
            _next_input_timer = time
        return

    _next_input = action
    _next_input_timer = time

func update_last_input(action: GUIDEAction) -> void:
    if action == _last_input:
        if _last_input_timer < 0.0001:
            _last_input_timer = LAST_INPUT_TIME
        return

    _last_input = action
    _last_input_timer = LAST_INPUT_TIME

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
