@tool
@icon("res://icon/weapon.svg")

## Links the weapon's visual with the weapon's logical components.
## Also turns the weapon for targetting.
class_name WeaponNode extends Node3D


## When the weapon state is updated, such as shooting, reloading, unloading, etc.
signal weapon_updated()

## When the weapon fires a round
signal weapon_fired()

signal reload_complete()


@export var controller: CharacterBase

## Activated by weapons that use hitboxes
@export var hitbox: HitBox

@export var weapon_type: WeaponResource:
    set = load_weapon_type

@export var sound_bus: StringName = &"Weapon":
    set(value):
        sound_bus = value
        if _weapon_audio_player:
            _weapon_audio_player.bus = sound_bus

## Groups to assign the audio player to
@export var sound_groups: Array[StringName]


@export_group("Aiming", "aim")

## If the weapon should align itself with the target RayCast3D. You should
## disable this for melee weapons.
@export var aim_enabled: bool = true
## Aim target for weapon
@export var aim_target: RayCast3D
## If this aim target ticks at a reduced rate
@export var aim_target_reduced_rate: bool = true
## Time to aim weapons in seconds
@export_range(0.001, 2.0, 0.0001, 'or_greater', 'suffix:seconds')
var aim_duration: float = 0.2


## Ammo bank to use for weapons
var ammo_bank: Dictionary


const AIM_TICK_RATE: int = 12
const RECOIL_DURATION: float = 0.117
const RECOIL_ANGLE: float = deg_to_rad(180.0)
const RECOIL_SPLIT = 0.5
const RECOIL_ALT_SPLIT = 1.0 - RECOIL_SPLIT

var aim_transform: Transform3D
var alt_mode_transform: Transform3D
var sway_transform: Transform3D
var recoil_transform: Transform3D

# Recoil & aiming flags
var _is_aiming: bool = false
var _is_recoil_rising: bool = false

# Random component of recoil
var _recoil_kick: Interpolation = Interpolation.new()

# Vertical component of recoil
var _recoil_rise_amount: float = 0.0
var _recoil_rise_speed: float = 0.0

# Recoil recovery
var _recoil_recovery: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

# Aim offset for the weapon scene, applied after recoil
var _weapon_aim: Interpolation = Interpolation.new(aim_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
var _weapon_aim_target: Vector2
var _weapon_aim_next_target: bool
var _weapon_aim_ticks: int = AIM_TICK_RATE

## If the weapon has an alt fire mode
var _has_alt_mode: bool = false
var _alt_transform: Transform3D
var _alt_interp: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


var continue_reload: bool = false:
    set = set_continue_reload

var continue_unload: bool = false:
    set = set_continue_unload

var _weapon_scene: WeaponScene

var _particle_system: ParticleSystem

var _weapon_audio_player: PositionalAudioPlayer

var melee_excluded_hurtboxes: Array[RID]

var weapon_fire_queue: Array

var _melee_timer: float = 0.0
var _melee_transform: Variant = null


func _ready() -> void:
    _weapon_audio_player = PositionalAudioPlayer.new()
    _weapon_audio_player.source_node = self
    _weapon_audio_player.groups = sound_groups.duplicate()
    _weapon_audio_player.bus = sound_bus
    _weapon_audio_player.polyphony = 8

    if aim_target and aim_target_reduced_rate:
        aim_target.enabled = false

    _weapon_aim.current = Vector2.ZERO
    _weapon_aim.target = Vector2.ZERO
    _recoil_kick.current = Vector2.ZERO
    _recoil_kick.target = Vector2.ZERO
    _recoil_recovery.current = 0.0
    _recoil_recovery.target = 0.0

    weapon_fire_queue = []

    add_child(_weapon_audio_player)

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
                _weapon_audio_player.sound = weapon_type.sound_effect
                trigger_sound()
                weapon_type.sound_test = false
        return

    if _weapon_scene:
        if aim_enabled and aim_target:
            interpolate_aim(delta)
        interpolate_recoil(delta)

        var scene_transform = Transform3D.IDENTITY.translated(weapon_type.scene_offset)
        if _has_alt_mode:
            interpolate_alt_mode(delta)
            scene_transform *= alt_mode_transform
        scene_transform *= aim_transform
        scene_transform *= recoil_transform
        scene_transform *= sway_transform
        _weapon_scene.transform = scene_transform

    if _melee_timer > 0.0:
        _melee_timer = maxf(0.0, _melee_timer - delta)
        if _melee_timer == 0.0:
            _melee_transform = aim_target_transform()

#var last_fire_time: int = 0
#var last_fire_count: int = 0

func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return

    var played_effects: bool = false
    var from_node: Node3D = self
    if controller:
        from_node = controller

    var i: int = 0
    #var s: int = 0
    var size: int = weapon_fire_queue.size()
    while i < size:
        if not played_effects:
            played_effects = true
            trigger_sound()
            trigger_particle()

        if weapon_type.melee_only:
            weapon_type.fire_melee(
                    from_node,
                    weapon_fire_queue[i],
                    melee_excluded_hurtboxes
            )
            i += 1
            continue

        weapon_type.fire_projectiles(
                from_node,
                weapon_fire_queue[i],
                weapon_fire_queue[i + 1]
        )

        #s += 1
        i += 2

    weapon_fire_queue.clear()

    # NOTE: for debugging RPM of weapons
    #if s > 0:
        #if last_fire_count == 0:
            #last_fire_time = Time.get_ticks_usec()
        #else:
            #var t: int = Time.get_ticks_usec()
            #var rpm: float = last_fire_count * 60000000.0 / (t - last_fire_time)
            #last_fire_time = t
            #print(rpm)
        #last_fire_count = s

    if _melee_transform is Transform3D:
        on_weapon_melee(_melee_transform)
        _melee_transform = null

    if _weapon_scene:
        if aim_enabled and aim_target:
            update_aim_target()


func interpolate_aim(delta: float) -> void:
    if _weapon_aim_next_target:
        _weapon_aim.set_target_delta(_weapon_aim_target, _weapon_aim_target - _weapon_aim.current)
        _weapon_aim_next_target = false
    elif _weapon_aim.is_done:
        return

    _weapon_aim.update(delta)
    aim_transform = Transform3D.IDENTITY.rotated(Vector3.UP, _weapon_aim.current.x)
    aim_transform = aim_transform.rotated_local(Vector3.RIGHT, _weapon_aim.current.y)

func interpolate_alt_mode(delta: float) -> void:
    if weapon_type.alt_mode:
        if _alt_interp.target != 1.0:
            _alt_interp.set_target_delta(1.0, 1.0 - _alt_interp.current)
        elif _alt_interp.is_done:
            return
        var progress: float = _alt_interp.update(delta)
        if _alt_interp.is_done:
            alt_mode_transform = _alt_transform
            return
        alt_mode_transform = Transform3D.IDENTITY.interpolate_with(_alt_transform, progress)
    else:
        if _alt_interp.target != 0.0:
            _alt_interp.set_target_delta(0.0, -_alt_interp.current)
        elif _alt_interp.is_done:
            return
        var progress: float = _alt_interp.update(delta)
        if _alt_interp.is_done:
            alt_mode_transform = Transform3D.IDENTITY
            return
        alt_mode_transform = _alt_transform.interpolate_with(Transform3D.IDENTITY, 1.0 - progress)

func interpolate_recoil(delta: float) -> void:
    recoil_transform = Transform3D.IDENTITY
    var alt_recoil_transform = Transform3D.IDENTITY

    if _is_recoil_rising:
        # Reset recovery interpolation
        if not _recoil_recovery.is_done:
            _recoil_recovery.reset()

        var accel: float
        accel = weapon_type.recoil_vertical_acceleration * delta
        if _is_aiming and not is_zero_approx(weapon_type.recoil_aim_control):
            accel *= (1.0 - weapon_type.recoil_aim_control)
        _recoil_rise_speed += accel
        _recoil_rise_amount = minf(
                weapon_type.recoil_spread_max,
                _recoil_rise_amount + (_recoil_rise_speed * delta)
        )

        recoil_transform = recoil_transform.rotated_local(Vector3.RIGHT, _recoil_rise_amount * RECOIL_SPLIT)
        alt_recoil_transform = alt_recoil_transform.rotated_local(Vector3.RIGHT, _recoil_rise_amount * RECOIL_ALT_SPLIT)
    else:
        # Start rise reset, use rise speed as a signal value
        if not is_zero_approx(_recoil_rise_speed):
            _recoil_rise_speed = 0.0
            _recoil_recovery.current = _recoil_rise_amount * RECOIL_SPLIT
            _recoil_recovery.set_target_delta(0.0, -_recoil_recovery.current)

        # Recovery updates when not recoiling
        if not _recoil_recovery.is_done:
            _recoil_rise_amount = _recoil_recovery.update(delta)

            recoil_transform = recoil_transform.rotated_local(Vector3.RIGHT, _recoil_rise_amount * RECOIL_SPLIT)
            alt_recoil_transform = alt_recoil_transform.rotated_local(Vector3.RIGHT, _recoil_rise_amount * RECOIL_ALT_SPLIT)

    # Kick recoil updates the same either way
    if not _recoil_kick.is_done:
        var kick_amount: Vector2 = _recoil_kick.update(delta)

        recoil_transform = recoil_transform.rotated_local(Vector3.RIGHT, kick_amount.y * RECOIL_SPLIT)
        recoil_transform = recoil_transform.rotated_local(Vector3.UP, kick_amount.x * RECOIL_SPLIT)

        alt_recoil_transform = alt_recoil_transform.rotated_local(Vector3.RIGHT, kick_amount.y * RECOIL_ALT_SPLIT)
        alt_recoil_transform = alt_recoil_transform.rotated_local(Vector3.UP, kick_amount.x * RECOIL_ALT_SPLIT)

        # Start kick reset
        if _recoil_kick.is_done and not _recoil_kick.target == Vector2.ZERO:
            _recoil_kick.duration = weapon_type.recoil_recover_time
            _recoil_kick.easing = Tween.EASE_IN_OUT
            _recoil_kick.transition = Tween.TRANS_CUBIC
            _recoil_kick.set_target_delta(Vector2.ZERO, -_recoil_kick.current)

    # TODO: apply some small motion impulse effects to the camera when firing
    #       instead of just rotations. Maybe even some roll.

    controller.set_recoil_transform(alt_recoil_transform)

func update_aim_target() -> void:
    _weapon_aim_ticks += 1
    if _weapon_aim_ticks < AIM_TICK_RATE:
        return
    _weapon_aim_ticks = 0

    if aim_target_reduced_rate:
        aim_target.force_raycast_update()

    if not aim_target.is_colliding():
        if not _weapon_aim_target.is_zero_approx():
            _weapon_aim_target = Vector2.ZERO
            _weapon_aim_next_target = true
        return

    var from_transform: Transform3D = aim_target.global_transform
    #if _weapon_scene.projectile_marker and \
            #aim_target.get_collision_point()\
                      #.distance_squared_to(_weapon_scene.projectile_marker.global_position) >= 0.25:
    if false and _weapon_scene.projectile_marker:
        from_transform.origin = _weapon_scene.projectile_marker.global_position
    else:
        from_transform.origin = _weapon_scene.global_position

    var point: Vector3 = (from_transform.inverse() * aim_target.get_collision_point()).normalized()
    var target: Vector2 = Vector2(acos(point.x) - PI / 2, asin(point.y))

    if not target.is_equal_approx(_weapon_aim_target):
        _weapon_aim_target = target
        _weapon_aim_next_target = true

## Get the global weapon transform
func weapon_tranform() -> Transform3D:
    return _weapon_scene.global_transform

## Get the transform of the weapon projectile marker
func weapon_projectile_transform() -> Transform3D:
    if _weapon_scene and _weapon_scene.projectile_marker:
        return _weapon_scene.projectile_marker.global_transform
    return weapon_tranform()

func aim_target_transform() -> Transform3D:
    return aim_target.global_transform

## Set if the weapon is aiming. This reduces recoil power when aiming.
func set_aiming(value: bool) -> void:
    _is_aiming = value

## Toggle's the weapon's alt mode
func toggle_alt_mode() -> void:
    if weapon_type and _has_alt_mode:
        weapon_type.set_alt_mode(not weapon_type.alt_mode)
        _alt_interp.reset(_alt_interp.current)
        _alt_interp.duration = weapon_type.get_alt_switch_time()
        _weapon_scene.on_weapon_updated(weapon_type)

func set_continue_reload(value: bool) -> void:
    continue_reload = value

func set_continue_unload(value: bool) -> void:
    continue_unload = value

func set_melee_excluded_hurboxes(hurtboxes: Array[HurtBox]) -> void:
    melee_excluded_hurtboxes.assign(hurtboxes.map(func (h): return h.get_rid()))

## Switches ammo types, returns true if successful
func switch_ammo() -> bool:
    # There is no animation to switch ammo type, so just pass to weapon
    if not weapon_type:
        return false

    if not weapon_type.switch_ammo():
        return false

    emit_weapon_update()

    if not _weapon_scene:
        return true

    # NOTE: Mixed loading is always individual rounds, with no magazine
    #       so we must update the reload ammo when changing types
    if weapon_type.ammo_can_mix:
        if weapon_type.ammo_stock:
            _weapon_scene.set_reload_scene(weapon_type.ammo_stock.ammo.scene_round)
        else:
            _weapon_scene.set_reload_scene(null)

    return true

## Updates weapon trigger, returns 'true' if weapon has actuated and will soon fire
func update_trigger(triggered: bool, delta: float) -> bool:
    if weapon_type.melee_only:
        if triggered and weapon_type.can_melee():
            _weapon_scene.goto_fire()
            weapon_fire_queue.append(aim_target_transform())
            return true
        return false

    var mechanism: TriggerMechanism = weapon_type.trigger_mechanism
    var actuated: bool = false
    var emit_updated: bool = false

    # TODO: Fix recoil system, should be purely impulse driven and not boolean
    # NOTE: Turn off recoil rise when we stop triggering
    if not triggered:
        _is_recoil_rising = false

    mechanism.update_trigger(triggered)

    # NOTE: Special case for revolver, ensure weapon is charged when mechanism
    #       is going to trigger.
    if weapon_type is RevolverWeapon and weapon_type.alt_mode and mechanism.should_trigger():
        weapon_type.charge_weapon()

    var fire_played: bool = false

    var max_ticks: int = 20
    while max_ticks > 0:
        max_ticks -= 1

        var can_fire: bool = weapon_type.can_fire()
        mechanism.update_can_fire(can_fire)

        # NOTE: enforce a minimum of 1ms to pass for weapon ticks
        delta = minf(mechanism.tick(delta), delta - 0.01)

        # Consider a failed actuation if could not fire
        if mechanism.actuated and can_fire:
            actuated = true

        for action in mechanism.get_actions():
            if action == TriggerMechanism.Action.FIRE:
                _weapon_scene.goto_fire()
                fire_played = true

                var ammo: AmmoResource = weapon_type.get_ammo_to_fire()
                if ammo:
                    weapon_fire_queue.append(ammo)
                    weapon_fire_queue.append(weapon_projectile_transform())

                if on_weapon_fire():
                    emit_updated = true

                weapon_fired.emit()

                continue

            if action == TriggerMechanism.Action.EJECT:
                on_weapon_round_ejected()
                continue

            if action == TriggerMechanism.Action.CHARGE:
                on_weapon_charged()
                continue

        if delta <= 0.0:
            break

    if emit_updated:
        emit_weapon_update()

    # For double-action mechanisms, immediately start the fire animation
    if actuated and (not fire_played) and mechanism is DoubleActionMechanism:
        _weapon_scene.goto_fire()

    return actuated

## Test if the weapon could be aiming right now
func can_aim() -> bool:
    if not weapon_type.aim_enabled:
        return false

    return _weapon_scene.can_aim()

## The weapon should charge, returns 'true' if the weapon will soon charge
func charge() -> bool:
    if not weapon_type.can_charge():
        return false

    return _weapon_scene.goto_charge()

## The weapon should do a melee, returns 'true' if the weapon will soon melee
func melee() -> bool:
    if not weapon_type.can_melee():
        return false

    if _weapon_scene.goto_melee():
        _melee_timer = weapon_type.melee_delay / 1000.0
        return true
    return false

## The weapon should reload
func reload() -> bool:
    if not weapon_type.can_reload():
        return false

    return _weapon_scene.goto_reload()

## The weapon should unload
func unload() -> bool:
    if not weapon_type.can_unload():
        return false

    return _weapon_scene.goto_unload()

func has_ammo_stock() -> bool:
    return not weapon_type.ammo_stock.is_empty()

## Trigger the weapon sound
func trigger_sound(_activate: bool = true) -> void:
    _weapon_audio_player.play()

## Trigger the particle effect
func trigger_particle(activate: bool = true) -> void:
    if not _particle_system:
        return

    _particle_system.emitting = activate

func load_weapon_type(type: WeaponResource) -> void:
    if weapon_type:
        if _has_alt_mode and not weapon_type.is_alt_mode_persistent():
            weapon_type.alt_mode = false

    weapon_type = type

    # Reset weapon related values
    continue_reload = false
    continue_unload = false
    _is_recoil_rising = false
    _has_alt_mode = false
    _alt_transform = Transform3D.IDENTITY
    alt_mode_transform = Transform3D.IDENTITY

    _alt_interp.reset(0.0)
    _weapon_aim.reset(Vector2.ZERO)
    _recoil_kick.reset(Vector2.ZERO)
    _recoil_recovery.reset(0.0)

    _weapon_aim_ticks = AIM_TICK_RATE
    _recoil_rise_speed = 0.0
    _recoil_rise_amount = 0.0

    weapon_fire_queue.clear()
    _melee_timer = 0.0
    _melee_transform = null

    _load_weapon_scene()
    _load_particle_system()

    if not weapon_type:
        return

    weapon_type.ammo_bank = ammo_bank
    _has_alt_mode = weapon_type.has_alt_mode()
    if _has_alt_mode:
        _alt_transform = weapon_type.get_alt_transform()

    _recoil_recovery.duration = weapon_type.recoil_recover_time

    if _weapon_scene:
        if weapon_type.ammo_can_mix:
            if weapon_type.ammo_stock:
                _weapon_scene.set_reload_scene(weapon_type.ammo_stock.ammo.scene_round)
            else:
                _weapon_scene.set_reload_scene(null)
            _weapon_scene.set_magazine_scene(null)
        else:
            _weapon_scene.set_magazine_scene(weapon_type.scene_magazine)
            _weapon_scene.set_reload_scene(weapon_type.scene_magazine)
        _weapon_scene.on_weapon_updated(weapon_type)

    _weapon_audio_player.sound = weapon_type.sound_effect

func _load_weapon_scene() -> void:
    if _weapon_scene:
        _weapon_scene.charged.disconnect(on_weapon_charged)
        _weapon_scene.uncharged.disconnect(on_weapon_uncharged)
        _weapon_scene.reload_loop.disconnect(on_weapon_reload_loop)
        _weapon_scene.unload_loop.disconnect(on_weapon_unload_loop)
        _weapon_scene.round_loaded.disconnect(on_weapon_round_loaded)
        _weapon_scene.round_unloaded.disconnect(on_weapon_round_unloaded)
        _weapon_scene.magazine_loaded.disconnect(on_weapon_magazine_loaded)
        _weapon_scene.magazine_unloaded.disconnect(on_weapon_magazine_unloaded)

        if _weapon_scene is RevolverWeaponScene:
            _weapon_scene.cylinder_rotated.disconnect(on_cylinder_rotated)

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

    # NOTE: The animation tree is not enabled by default
    _weapon_scene.animation_tree.active = true

    # NOTE: Special case for revolver scene and weapon
    if _weapon_scene is RevolverWeaponScene:
        _weapon_scene.cylinder_rotated.connect(on_cylinder_rotated)

    _weapon_scene.global_transform = global_transform.translated(weapon_type.scene_offset)
    _weapon_scene.charged.connect(on_weapon_charged)
    _weapon_scene.uncharged.connect(on_weapon_uncharged)
    _weapon_scene.reload_loop.connect(on_weapon_reload_loop)
    _weapon_scene.unload_loop.connect(on_weapon_unload_loop)
    _weapon_scene.round_loaded.connect(on_weapon_round_loaded)
    _weapon_scene.round_unloaded.connect(on_weapon_round_unloaded)
    _weapon_scene.magazine_loaded.connect(on_weapon_magazine_loaded)
    _weapon_scene.magazine_unloaded.connect(on_weapon_magazine_unloaded)

func _load_particle_system() -> void:
    if _particle_system and _particle_system.get_parent() == self:
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

func emit_weapon_update() -> void:
    weapon_updated.emit()
    _weapon_scene.on_weapon_updated(weapon_type)

func on_cylinder_rotated(steps: int) -> void:
    if weapon_type is RevolverWeapon:
        weapon_type.rotate_cylinder(steps)
        _weapon_scene.on_weapon_updated(weapon_type)

## Returns true if the weapon state changed, used to consolidate weapon firing updates
func on_weapon_fire() -> bool:
    if not weapon_type:
        return false

    # NOTE: Dev only, should be removed later
    if weapon_type.melee_only:
        print_debug('on_weapon_fire() must not be called for melee-only weapons!')
        return false

    # TODO: recoil system change to impulses
    # Turn on recoil rise when firing, before fire_round as it may become empty
    if weapon_type.recoil_enabled:
        _is_recoil_rising = true

    var updated: bool = weapon_type.fire_round()
    # TODO: change recoil system to be impulse based. The result of this method
    #       should have no impact on recoil!

    # TODO: recoil system change to impulses
    # NOTE: Always apply recoil kick
    if weapon_type.recoil_enabled:
        # TODO: Probably make it sway back and forth instead
        var bias: float = weapon_type.recoil_spread_bias
        var distance: float = randf() * (2.0 - abs(bias)) - (1.0 - abs(bias))
        if bias < 0.0:
            distance = -distance

        if distance < 0.0:
            distance = -sqrt(-distance)
            distance *= deg_to_rad(weapon_type.recoil_random_range / 60.0)
            distance -= deg_to_rad(weapon_type.recoil_kick / 60.0)
        else:
            distance = sqrt(distance)
            distance *= deg_to_rad(weapon_type.recoil_random_range / 60.0)
            distance += deg_to_rad(weapon_type.recoil_kick / 60.0)

        var angle: float = 2.0 * (randf() - 0.5) * weapon_type.recoil_spread_angle
        if _is_aiming and not is_zero_approx(weapon_type.recoil_aim_control):
            distance *= (1.0 - weapon_type.recoil_aim_control)
            angle *= (1.0 - weapon_type.recoil_aim_control)
        angle += weapon_type.recoil_spread_axis_angle

        var change: Vector2 = Vector2(-cos(angle) * distance, sin(angle) * distance)
        var max_spread: float = weapon_type.recoil_spread_max

        var target: Vector2 = _recoil_kick.current

        # If we pass our max spread, ensure the kick pulls us back
        if not is_zero_approx(max_spread):
            var total: Vector2 = Vector2(target.x, target.y + _recoil_rise_amount)
            if abs(total.x) > max_spread:
                if signf(total.x) == signf(change.x):
                    change.x *= -1.0

            if abs(total.y) > max_spread:
                if signf(total.y) == signf(change.y):
                    change.y *= -1.0

        target += change

        _recoil_kick.duration = RECOIL_DURATION
        _recoil_kick.easing = Tween.EASE_OUT
        _recoil_kick.transition = Tween.TRANS_SPRING
        _recoil_kick.set_target_delta(target, target - _recoil_kick.current)

    return updated

func on_weapon_melee(melee_transform: Transform3D) -> void:
    if not weapon_type:
        return

    if not Engine.is_in_physics_frame():
        print_debug('on_weapon_melee() must only be called in the physics frame!')
        return

    var from_node: Node3D = self
    if controller:
        from_node = controller

    weapon_type.fire_melee(from_node, melee_transform, melee_excluded_hurtboxes)

func on_weapon_charged() -> void:
    if not weapon_type or not weapon_type.can_charge():
        return

    weapon_type.charge_weapon()
    emit_weapon_update()

func on_weapon_uncharged() -> void:
    if not weapon_type:
        return

    # NOTE: method does not exist, this is ONLY called by RevolverScene after it
    #       has set the revolver hammer to the uncocked state.
    # weapon_type.uncharge_weapon()
    emit_weapon_update()

func on_weapon_reload_loop() -> void:
    if not continue_reload:
        reload_complete.emit()
        return

    if not weapon_type.can_reload() or not _weapon_scene.goto_reload_continue():
        reload_complete.emit()
        continue_reload = false

func on_weapon_unload_loop() -> void:
    if continue_unload:
        _weapon_scene.goto_unload_continue()

func on_weapon_round_loaded() -> void:
    if not weapon_type:
        return

    weapon_type.load_rounds()
    emit_weapon_update()

func on_weapon_round_ejected() -> void:
    if not weapon_type or not weapon_type.can_eject():
        return

    var round_dict: Dictionary
    if weapon_type.ammo_expend_enabled:
        round_dict = weapon_type.get_chamber_round()

    if weapon_type.eject_round():
        emit_weapon_update()

    if not round_dict:
        return

    _weapon_scene.eject_round(
        round_dict,
        controller.velocity,
        weapon_type.ammo_expend_direction,
        weapon_type.ammo_expend_direction_range,
        weapon_type.ammo_expend_force,
        weapon_type.ammo_expend_force_range,
    )

func on_weapon_round_unloaded() -> void:
    # NOTE: keeping this for naming, in the event a weapon is made that
    #       does something else, but these are fundamentally the same
    #       operation in all currently planned weapons.
    on_weapon_round_ejected()

func on_weapon_magazine_loaded() -> void:
    # NOTE: for all currently planned weapons, these are fundamentally
    #       the same operation, so we just call into this method.
    on_weapon_round_loaded()

    reload_complete.emit()

    # Magazines do not loop, this means it has finished
    continue_reload = false

func on_weapon_magazine_unloaded() -> void:
    if not weapon_type:
        return

    weapon_type.unload_rounds()
    emit_weapon_update()
