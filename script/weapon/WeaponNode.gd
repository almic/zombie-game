@tool
@icon("res://icon/weapon.svg")

## Manages a physical weapon that targets a RayCast3D hit point
class_name WeaponNode extends Node3D

@export var controller: Node3D

## Activated by weapons that use hitboxes
@export var hitbox: HitBox

@export var weapon_type: WeaponResource:
    set = load_weapon_type

## If the weapon should align itself with the target RayCast3D. You should
## disable this for melee weapons.
@export var do_targeting: bool = true
## Aim target for weapon
@export var target: RayCast3D
## Speed for weapon re-targeting
@export var target_update_speed: float = 15
## Frequency of target position checks in physics frames.
@export var target_update_rate: int = 3

## Ammo bank to use for weapons
var _ammo_bank: Dictionary
var _ammo_stock: Dictionary

# For moving weapon to face target
var _weapon_target_from: Quaternion
var _weapon_target_to: Quaternion
var _weapon_target_tick: int = 0
var _weapon_target_amount: float = 0

var _weapon_trigger: GUIDEAction
var _weapon_melee: GUIDEAction
var _weapon_reload: GUIDEAction
var _weapon_ammo_switch: GUIDEAction

var _weapon_charge_to_fire: bool = false
var _weapon_round_chambered: int = 0

const WEAPON_TRIGGER_BUFFER: float = 0.5
const WEAPON_CHARGE_BUFFER: float = 1.0
const WEAPON_MELEE_BUFFER: float = 0.4
const WEAPON_RELOAD_BUFFER: float = 0.9

# Fire buffering, to shoot when not ready
var _weapon_trigger_buffered: float = 0
# This is needed in case the weapon is empty, so it doesn't look
# like we can charge-to-fire. If the weapon charges in this time,
# make it a charge-to-fire.
var _weapon_charge_buffered: float = 0
# Melee buffering, when animations cannot immediately stop
var _weapon_melee_buffered: float = 0
# This is needed in case the reserve is full, but a shot was fired
# and a charge may provide room to reload
var _weapon_reload_buffered: float = 0

var _weapon_melee_ready: bool = true

var _weapon_reload_time: int
var _weapon_reload_full_reload: bool = false

var _weapon_scene: WeaponScene

var _particle_system: ParticleSystem

var _weapon_audio_player: WeaponAudioPlayer


func _ready() -> void:
    _weapon_audio_player = WeaponAudioPlayer.new()
    add_child(_weapon_audio_player)


func set_ammo_bank(ammo: Dictionary) -> void:
    _ammo_bank = ammo

func set_ammo_switch(action: GUIDEAction) -> void:
    _weapon_ammo_switch = action

func set_trigger(action: GUIDEAction) -> void:
    _weapon_trigger = action

func set_melee(action: GUIDEAction) -> void:
    _weapon_melee = action

func set_reload(action: GUIDEAction) -> void:
    _weapon_reload = action

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if weapon_type:
            if _weapon_scene:
                _weapon_scene.position = weapon_type.scene_offset
            if weapon_type.particle_test:
                _load_particle_system()
                trigger_particle(true)
                weapon_type.particle_test = false
            if weapon_type.sound_test:
                # re-apply the sound in case it was changed
                _weapon_audio_player.weapon_sound_resource = weapon_type.sound_effect
                trigger_sound()
                weapon_type.sound_test = false
        return

    if weapon_type:
        weapon_type.trigger_mechanism.update_input(_weapon_trigger)

        if _weapon_ammo_switch.is_triggered():
            switch_ammo()

        update_reload(delta)
        update_melee(delta)

    if not do_targeting or not _weapon_scene:
        return

    if _weapon_target_to.is_equal_approx(_weapon_scene.global_basis.get_rotation_quaternion()):
        return

    _weapon_target_amount += target_update_speed * delta
    _weapon_scene.global_basis = Basis(
        _weapon_target_from.slerp(_weapon_target_to, _weapon_target_amount)
    )

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    update_trigger(delta)

    if not do_targeting or not _weapon_scene:
        return

    _weapon_target_tick += 1
    if _weapon_target_tick < target_update_rate:
        return
    _weapon_target_tick = 0

    if target.is_colliding():
        # DrawLine3d.DrawLine(mesh.global_position, target.get_collision_point(), Color(0.2, 0.25, 0.8), 1)
        _weapon_target_to = Quaternion(
            Basis.looking_at(
                _weapon_scene.global_position.direction_to(
                    target.get_collision_point()
                ), target.basis.y
            )
        )
    else:
        # Aim forward
        _weapon_target_to = target.global_basis.get_rotation_quaternion()

    _weapon_target_from = _weapon_scene.global_basis.get_rotation_quaternion()
    _weapon_target_amount = 0

## Get the global weapon transform
func weapon_tranform() -> Transform3D:
    return _weapon_scene.global_transform

## Get the transform of the weapon projectile marker
func weapon_projectile_transform() -> Transform3D:
    if _weapon_scene and _weapon_scene.projectile_marker:
        return _weapon_scene.projectile_marker.global_transform
    return weapon_tranform()

## Switches ammo types
func switch_ammo() -> void:
    var last_type: int
    if _ammo_stock:
        last_type = _ammo_stock.ammo.ammo_type

    _ammo_stock = _get_next_ammo()

    if _ammo_stock and last_type == _ammo_stock.ammo.ammo_type:
        return

    _update_controller_ammo()

    if not _weapon_scene or not _ammo_stock:
        return

    # Put the reload mesh on the weapon
    var ammo_type: AmmoResource = _ammo_stock.ammo
    if _weapon_scene.reload_marker and ammo_type.scene_round:
        # Expect only one child max, so just remove and break
        for child in _weapon_scene.reload_marker.get_children():
            _weapon_scene.reload_marker.remove_child(child)
            break

        var round_node: Node3D = ammo_type.scene_round.instantiate()
        _weapon_scene.reload_marker.add_child(round_node)

## Triggers the firing of a weapon
func update_trigger(delta: float) -> void:
    if not weapon_type:
        return

    if _weapon_charge_buffered > 0.0:
        _weapon_charge_buffered -= delta

    var fired: bool = weapon_type.trigger_mechanism.tick(delta)

    if _weapon_trigger_buffered > 0.0:
        _weapon_trigger_buffered -= delta
    elif not fired:
        return

    if weapon_type.melee_is_primary:
        _weapon_scene.goto_fire()
        return

    if weapon_type.can_chamber:
        if weapon_type.is_chambered():
            if not _weapon_scene.anim_locked:
                _weapon_scene.goto_fire()
            elif fired:
                _weapon_trigger_buffered = WEAPON_TRIGGER_BUFFER
                print('not ready to fire!')
        elif weapon_type.get_reserve_total() > 0:
            print('charging to shoot!!!!!!')
            _weapon_scene.goto_charge()
            _weapon_charge_to_fire = true
        else:
            _weapon_charge_buffered = WEAPON_CHARGE_BUFFER
            print('click! no reserve!')

        return

    if weapon_type.get_reserve_total() > 0:
        if not _weapon_scene.anim_locked:
            _weapon_scene.goto_fire()
        elif fired:
            _weapon_trigger_buffered = WEAPON_TRIGGER_BUFFER
            print('not ready to fire!')
        return

    print('click! no reserve!')

func update_melee(delta: float) -> void:

    if _weapon_melee_buffered > 0.0:
        _weapon_melee_buffered -= delta

    if _weapon_melee.is_triggered():
        if _weapon_melee_ready:
            _weapon_melee_buffered = WEAPON_MELEE_BUFFER
            _weapon_melee_ready = false
    else:
        _weapon_melee_ready = true

    if _weapon_melee_buffered > 0.0:
        if weapon_type.melee_is_primary:
            _weapon_scene.goto_fire()
        else:
            _weapon_scene.goto_melee()

## Handles reloading logic
func update_reload(delta: float) -> void:
    if _weapon_reload_buffered > 0.0:
        _weapon_reload_buffered -= delta

    # If we try to fire, cancel reloads
    if _weapon_trigger.is_triggered() or _weapon_melee.is_triggered():
        _weapon_reload_full_reload = false
        _weapon_reload_buffered = 0.0
        return

    if not _weapon_reload.is_triggered():
        if _weapon_reload_time == 0:
            return

        var elapsed: int = Time.get_ticks_msec() - _weapon_reload_time
        if elapsed < 500:
            _weapon_reload_full_reload = true

        _weapon_reload_time = 0
        return

    # Holding down reload, just let things happen
    if _weapon_reload_time > 0:
        return

    if not weapon_type or not _ammo_bank:
        return

    var reserve_total: int = weapon_type.get_reserve_total()
    if reserve_total >= weapon_type.ammo_reserve_size:
        _weapon_reload_buffered = WEAPON_RELOAD_BUFFER
        print('Fully loaded!')
        return

    if not _ammo_stock:
        print('No supported ammo in stock!')
        return

    if _ammo_stock.amount < 1:
        print('Stock is empty!')
        return

    _weapon_scene.goto_reload()

    _weapon_charge_to_fire = false
    _weapon_reload_time = Time.get_ticks_msec()

## Trigger the weapon
func trigger_weapon(_activate: bool = true) -> void:
    _weapon_scene.goto_fire()

## Trigger the weapon sound
func trigger_sound(_activate: bool = true) -> void:
    _weapon_audio_player.play_sound()

## Trigger the particle effect
func trigger_particle(activate: bool = true) -> void:
    if not _particle_system:
        return

    _particle_system.emitting = activate

func load_weapon_type(type: WeaponResource) -> void:
    weapon_type = type

    _ammo_stock = {}

    _weapon_trigger_buffered = 0

    _weapon_reload_full_reload = false
    _weapon_reload_time = 0

    _load_weapon_scene()
    _load_particle_system()

    if not weapon_type:
        return

    _weapon_audio_player.weapon_sound_resource = weapon_type.sound_effect
    switch_ammo()

func _load_weapon_scene() -> void:
    if _weapon_scene:
        _weapon_scene.fired.disconnect(on_weapon_fire)
        _weapon_scene.melee.disconnect(on_weapon_melee)
        _weapon_scene.swap_hand.disconnect(on_weapon_swap_hand)
        _weapon_scene.charged.disconnect(on_weapon_charged)
        _weapon_scene.reload_loop.disconnect(on_weapon_reload_loop)
        _weapon_scene.round_ejected.disconnect(on_weapon_round_ejected)
        _weapon_scene.round_loaded.disconnect(on_weapon_round_loaded)

        remove_child(_weapon_scene)
        _weapon_scene.queue_free()
        _weapon_scene = null

    if not weapon_type or not weapon_type.scene:
        return

    var weapon_scene = weapon_type.scene.instantiate()
    if weapon_scene is not WeaponScene:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" weapon scene \"" +
            str(weapon_type.scene.resource_name) +
            "\" root node is not a WeaponScene!"
        )
        return

    _weapon_scene = weapon_scene

    add_child(_weapon_scene)
    _weapon_scene.position = weapon_type.scene_offset
    _weapon_scene.fired.connect(on_weapon_fire)
    _weapon_scene.melee.connect(on_weapon_melee)
    _weapon_scene.swap_hand.connect(on_weapon_swap_hand)
    _weapon_scene.charged.connect(on_weapon_charged)
    _weapon_scene.reload_loop.connect(on_weapon_reload_loop)
    _weapon_scene.round_ejected.connect(on_weapon_round_ejected)
    _weapon_scene.round_loaded.connect(on_weapon_round_loaded)
    _weapon_scene.goto_ready()

func _load_particle_system() -> void:
    if _particle_system:
        remove_child(_particle_system)
        _particle_system.queue_free()
        _particle_system = null

    if not weapon_type or not weapon_type.particle_scene:
        return

    var particle_system = weapon_type.particle_scene.instantiate()
    if particle_system is not ParticleSystem:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" particle system \"" +
            str(weapon_type.particle_scene.resource_name) +
            "\" root node is not a ParticleSystem!"
        )
        return
    _particle_system = particle_system

    if _weapon_scene.particle_marker:
        _weapon_scene.particle_marker.add_child(_particle_system)
    else:
        add_child(_particle_system)
    _particle_system.position = weapon_type.particle_offset

func _get_next_ammo() -> Dictionary:
    if not weapon_type:
        return {}

    var supported: Dictionary = weapon_type.get_supported_ammunition()

    var ids: Array[int]
    ids.assign(_ammo_bank.keys())
    ids.filter(func (t): return supported.has(t))

    var size: int = ids.size()
    if size == 0:
        return {}
    elif size == 1:
        return _ammo_bank.get(ids[0])

    ids.sort()

    var next_index: int = -1
    var first_index: int = size
    if _ammo_stock:
        next_index = ids.find(_ammo_stock.ammo.ammo_type)
        if next_index != -1:
            first_index = next_index
    next_index += 1

    var max_loop: int = size
    var type: int

    while next_index != first_index and max_loop > 0:
        max_loop -= 1

        if next_index >= size:
            next_index = 0

        type = ids[next_index]

        if _ammo_bank.has(type):
            return _ammo_bank.get(type)

        next_index += 1

    return {}

func get_controller_aim_transform() -> Transform3D:
    if not controller or not controller.has_method('get_aim_transform'):
        return Transform3D.IDENTITY
    return controller.get_aim_transform()

func _update_controller_ammo() -> void:
    if not controller or not controller.has_method('update_ammo'):
        return

    controller.update_ammo()

func on_weapon_fire() -> void:
    if not weapon_type:
        return

    _weapon_trigger_buffered = 0.0

    if not Engine.is_in_physics_frame():
        get_tree().physics_frame.connect(on_weapon_fire, Object.CONNECT_ONE_SHOT)
        return

    trigger_sound()
    trigger_particle()

    weapon_type.trigger_mechanism.start_cycle()

    if weapon_type.melee_is_primary:
        _weapon_melee_ready = true
        _weapon_melee_buffered = 0.0
        weapon_type.fire_melee(self)
    else:
        weapon_type.fire_projectiles(self)
        _update_controller_ammo()


func on_weapon_melee() -> void:
    if not weapon_type:
        return

    _weapon_melee_buffered = 0.0

    if not Engine.is_in_physics_frame():
        get_tree().physics_frame.connect(on_weapon_melee, Object.CONNECT_ONE_SHOT)
        return

    weapon_type.fire_melee(self)

func on_weapon_swap_hand(time: float) -> void:
    if not controller:
        return

    if controller.has_method('swap_hand'):
        controller.swap_hand(time)

func on_weapon_charged() -> void:
    if not weapon_type:
        return

    _weapon_round_chambered = weapon_type.charge_weapon()

    if _weapon_round_chambered:
        if _weapon_charge_to_fire:
            _weapon_scene.goto_fire()
        elif _weapon_reload_buffered > 0.0:
            _weapon_scene.goto_reload()
            _weapon_reload_buffered = 0.0
        _update_controller_ammo()

    _weapon_charge_to_fire = false

func on_weapon_reload_loop() -> void:
    if _weapon_reload_full_reload or _weapon_reload.is_triggered():
        if _ammo_stock.amount > 0 and not weapon_type.is_reserve_full():
            _weapon_scene.goto_reload_continue()
            return

    _weapon_reload_full_reload = false

    if weapon_type.can_chamber and not weapon_type.is_chambered():
        _weapon_scene.goto_charge()
        if _weapon_charge_buffered > 0.0:
            _weapon_charge_to_fire = true
            _weapon_charge_buffered = 0.0

func on_weapon_round_ejected() -> void:
    if not _weapon_round_chambered:
        return

    if not weapon_type or not weapon_type.ammo_expend_enabled:
        return

    if not _weapon_scene or not _weapon_scene.eject_marker:
        return

    var ammo_type: AmmoResource = weapon_type.get_supported_ammunition().get(_weapon_round_chambered)
    if not ammo_type or not ammo_type.scene_expended:
        return

    var round_node: Node3D = ammo_type.scene_expended.instantiate()

    var eject_location: Vector3 = _weapon_scene.eject_marker.global_position
    var eject_rotation: Basis = _weapon_scene.eject_marker.global_basis

    get_tree().current_scene.add_child(round_node)
    get_tree().create_timer(10.0, false, true).timeout.connect(round_node.queue_free)

    round_node.global_position = eject_location
    round_node.global_basis = eject_rotation

    _weapon_round_chambered = 0

    # If not a physics body, we are done (weird?)
    var round_body: RigidBody3D = round_node as RigidBody3D
    if not round_body:
        return

    if controller.has_method('get_velocity'):
        round_body.linear_velocity = controller.get_velocity()

    var eject_basis: Basis = _weapon_scene.mesh.basis
    eject_basis = Basis.looking_at(
            -weapon_type.ammo_expend_direction,
            eject_basis.z.cross(weapon_type.ammo_expend_direction)
    )
    eject_basis *= _weapon_scene.global_basis

    var forward: Vector3 = eject_basis.z
    var force: float = weapon_type.ammo_expend_force

    # Randomize direction
    if weapon_type.ammo_expend_direction_range > 0.0:
        var right: Vector3 = eject_basis.x
        var spread: float = sqrt(randf_range(0.0, 1.0))
        spread *= weapon_type.ammo_expend_direction_range
        forward = forward.rotated(right, spread)
        forward = forward.rotated(eject_basis.z, randf_range(0.0, TAU))

    # Randomize force
    if weapon_type.ammo_expend_force_range > 0.0:
        force += randf_range(0, weapon_type.ammo_expend_force_range) * 2 - weapon_type.ammo_expend_force_range

    var impulse_point: Vector3 = round_node.global_basis.z * 0.08

    round_body.apply_impulse(forward * force, impulse_point)

func on_weapon_round_loaded() -> void:
    if not weapon_type:
        return

    var reserve_total: int = weapon_type.get_reserve_total()
    var ammo_type: int = _ammo_stock.ammo.ammo_type

    if weapon_type.ammo_can_mix:
        _ammo_stock.amount -= 1
        weapon_type.load_rounds(ammo_type, 1)
    else:
        var reserve_type: int = weapon_type.get_reserve_type()
        if reserve_type > 0 and ammo_type != reserve_type:
            _ammo_bank.set(ammo_type, _ammo_bank.get(ammo_type, 0) + reserve_total)
        var amount: int = mini(_ammo_stock.amount, weapon_type.ammo_reserve_size - reserve_total)
        _ammo_stock.amount -= amount
        weapon_type.load_rounds(ammo_type, amount)

    _update_controller_ammo()

    print('reserve: ' + str(weapon_type.get_reserve_total()))
    print('chambered: ' + str(weapon_type.is_chambered()))
