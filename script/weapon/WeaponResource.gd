@tool
@icon("res://icon/weapon.svg")

## Defines a weapon type that can be used in the world
class_name WeaponResource extends PickupResource


## Weapon name in UI elements
@export var name: String

## The unique slot of the weapon
@export_range(1, 10, 1)
var slot: int = 1


@export_group("Melee", "melee")

## This is a melee only weapon
@export var melee_only: bool = false

## Delay between melee input and actual collision test.
@export_range(0.1, 500.0, 0.1, 'or_greater', 'suffix:ms')
var melee_delay: float = 200.0

## Melee damage of the weapon
@export_range(-50.0, 50.0, 0.1, 'or_greater', 'or_less', 'suffix:hp')
var melee_damage: float = 0.0

## Impact force for melee
@export_range(0.0, 50.0, 0.01, 'or_greater', 'or_less', 'suffix:N')
var melee_impact: float = 0.0

## Range of the melee
@export_range(0.0, 10.0, 0.01, 'or_greater', 'suffix:m')
var melee_range: float = 2.0

@export_flags_3d_physics
var melee_collision: int = 8


@export_group("Mechanism")

## How this weapon is triggered
@export var trigger_mechanism: TriggerMechanism

## The weapon can chamber a round, such that the effective ammo
## capacity is reserve + 1
@export var can_chamber: bool = false


@export_group("Ballistics", "projectile")

## How much of an effect ammo type spread has in this weapon.
## This only matters if the ammo type already has spread.
@export_range(0.0, 1.0, 0.001)
var projectile_inaccuracy: float = 0.0

## Maximum hit detection range
@export var projectile_range: float = 100.0

## Hit collision mask
@export_flags_3d_physics var projectile_hit_mask: int = 8


@export_group("Aiming", "aim")

## If aiming is possible with the weapon
@export var aim_enabled: bool = false

## Offset from the central aiming position, which is just to match the camera's
## vertical and horizontal position.
@export var aim_offset: Vector3 = Vector3.ZERO

## Roll of the camera during aiming. Be VERY subtle with this value. IMMERSION.
@export_range(0.0, 10.0, 0.001, 'or_greater', 'radians_as_degrees')
var aim_camera_roll: float = 0.0

## FOV of the camera while aiming
@export_range(25.0, 75.0, 0.0001, 'or_less', 'or_greater', 'suffix:°')
var aim_camera_fov: float = 50.0

## Additional look speed scaling. Normally, the speed is scaled by the ratio of
## the Aim FOV / Camera FOV, decreasing this can further decrease look speed.
## This is used mainly by the bolt action rifle, as the scoepe provides a higher
## magnification than the aiming FOV.
@export_range(0.001, 1.0, 0.0001)
var aim_camera_look_speed_scale: float = 1.0

## How much to reduce recoil by when aiming, if recoil is enabled
@export_range(0.0, 1.0, 0.0001)
var aim_recoil_control: float:
    set(value):
        _recoil_aim_control = value
    get():
        return _recoil_aim_control


@export_group("Ammunition", "ammo")

## Reserve capacity for ammo
@export_range(1, 100, 1, 'or_greater')
var ammo_reserve_size: int = 10:
    set = set_ammo_reserve_size

## If the weapon supports mixing ammo loads
@export var ammo_can_mix: bool = false

## When mixing ammo, what order is ammo used? For example, a player loads
## ammo A, then ammo B. When this is true, B is used before A.
@export var ammo_reversed_use: bool = false

## Supported ammunition types, only used to compare IDs.
@export var ammo_supported: Array[AmmoResource]


@export_subgroup("Expended Ammo", "ammo_expend")

## If ammo expends from the weapon when fired
@export var ammo_expend_enabled: bool = false

## The direction of expended ammo, relative to the Eject Marker on
## the Weapon Scene.
@export var ammo_expend_direction: Vector3 = Vector3.RIGHT:
    set(value):
        ammo_expend_direction = value.normalized()

## Deviation angle for expended direction.
@export_range(0.0, 10.0, 0.001, 'or_greater', 'radians_as_degrees')
var ammo_expend_direction_range: float = 0.0

## The force applied to rounds when expended. Take care of large
## values for light rounds.
@export_range(0.0, 1.0, 0.001, 'or_greater', 'suffix:N')
var ammo_expend_force: float = 0.0

## Deviation range of force for expended rounds.
@export_range(0.0, 0.5, 0.001, 'or_greater', 'suffix:N')
var ammo_expend_force_range: float = 0.0


@export_group("Recoil", "recoil")

## If recoil is enabled
@export var recoil_enabled: bool = false

## Time to recover from recoil, in seconds
@export_range(0.001, 1.0, 0.0001, 'or_greater', 'suffix:s')
var recoil_recover_time: float = 0.25

## Vertical recoil acceleration per shot in degrees per second^2
@export_range(0.0, 20.0, 0.001, 'or_greater', 'radians_as_degrees', 'suffix:°/s²')
var recoil_vertical_acceleration: float = 0.0

## Maximum recoil distance in degrees. This is applied as a hard-stop on vertical
## rise, but as an eased function on kick. True max angle is 50% over this value.
@export_range(0.0, 20.0, 0.001, 'or_greater', 'radians_as_degrees')
var recoil_spread_max: float = 0.0

## Angular distance of random recoil, in arc minutes
@export_range(0.0, 120.0, 0.1, 'or_greater', 'suffix:′')
var recoil_kick: float = 0.0

## Minimum recoil power, in arc minutes.
@export_range(0.0, 100.0, 0.1, 'or_greater', 'suffix:′')
var recoil_random_range: float = 0.0

## Axis of random recoil, the following parameters operate from this line.
@export_range(-90.0, 90.0, 0.0001, 'radians_as_degrees')
var recoil_spread_axis_angle: float = 0.0

## Left-Right bias of random recoil, -1.0 is left-only recoil, 1.0 is right-only
## recoil, 0.0 is equally left and right recoil
@export_range(-1.0, 1.0, 0.0001)
var recoil_spread_bias: float = 0.0

## Angular spread from the baseline recoil direction in the positive and negative direction
@export_range(0.0, 90.0, 0.001, 'or_greater', 'radians_as_degrees')
var recoil_spread_angle: float = 0.0

## How much to reduce recoil by when aiming, if aiming is enabled
@export_range(0.0, 1.0, 0.0001)
var recoil_aim_control: float:
    set(value):
        _recoil_aim_control = value
    get():
        return _recoil_aim_control
var _recoil_aim_control: float = 0.0

@export_group("Display", "")
## If the weapon displays a crosshair when held
@export var crosshair_enabled: bool = true
@export var ui_texture: Texture2D
@export var scene: PackedScene
@export var scene_offset: Vector3
@export var scene_magazine: PackedScene
@export var scene_ui: PackedScene

@export_subgroup("Debug", "debug")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var debug_enabled: bool = false

@export_range(0.01, 1.0, 0.01, "or_greater")
var debug_sphere_radius: float = 0.05

@export_range(0.01, 10.0, 0.01, "or_greater")
var debug_time_to_live: float = 5.0

@export var debug_use_color: bool = false
const DEBUG_HIT_COLOR = Color(0.2, 0.8, 0.2, 0.6)
const DEBUG_MISS_COLOR = Color(0.8, 0.12, 0.2, 0.5)
@export var debug_sphere_color: Color = Color(0.0, 0.646, 0.752, 0.45)
@export var debug_hit_color: Color = DEBUG_HIT_COLOR
@export var debug_miss_color: Color = DEBUG_MISS_COLOR


@export_group("Particle System", "particle")
## The particle to use when firing
@export var particle_scene: PackedScene
## Offset of the scene relative to the barrel
@export var particle_offset: Vector3
## In Editor only, trigger the particle system for visualization
@export var particle_test: bool


@export_group("Sound", "sound")
## Sound effect for this weapon
@export var sound_effect: SoundResourceWeapon

## Toggle this to listen to the sound effect in-engine
@export var sound_test: bool = false


## Ammo bank to use for the weapon
var ammo_bank: Dictionary:
    set = set_ammo_bank

## Current ammo stock used for actions
var ammo_stock: Dictionary

## Alternate fire mode for weapon
var alt_mode: bool = false


# Cached map of supported ammo IDs to ammo resource
var _ammo_cache: Dictionary
var _is_ammo_cached: bool = false


var _simple_reserve_total: int = 0
var _simple_reserve_type: int = 0

var _chambered_round_type: int = 0
var _chambered_round_live: bool = false

var _mixed_reserve: PackedInt32Array = []


func switch_ammo() -> bool:
    var last_type: int
    if ammo_stock:
        last_type = ammo_stock.ammo.type

    var next_ammo_stock: Dictionary = get_next_ammo()

    if ammo_stock and last_type == next_ammo_stock.ammo.type:
        return false

    ammo_stock = next_ammo_stock
    return true

## Eject the chambered round. Returns true if a chambered round was ejected.
func eject_round() -> bool:
    if _chambered_round_live:
        # Recover round to ammo stock
        var stock: Dictionary = ammo_bank.get(_chambered_round_type)
        if stock:
            stock.amount += 1

    var ejected: bool = _chambered_round_type > 0

    _chambered_round_type = 0
    _chambered_round_live = false

    return ejected

func get_next_ammo() -> Dictionary:
    var supported: Dictionary = get_supported_ammunition()

    var ids: Array[int]
    ids.assign(ammo_bank.keys().filter(func (t): return supported.has(t)))

    var size: int = ids.size()
    if size == 0:
        return {}
    elif size == 1:
        return ammo_bank.get(ids[0])

    ids.sort()

    var next_index: int = -1
    var first_index: int = size
    if ammo_stock:
        next_index = ids.find(ammo_stock.ammo.type)
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

        if ammo_bank.has(type):
            return ammo_bank.get(type)

        next_index += 1

    return {}

func get_supported_ammunition() -> Dictionary:
    if not _is_ammo_cached:
        _ammo_cache = {}
        for ammo in ammo_supported:
            _ammo_cache.set(ammo.type, ammo)
        _is_ammo_cached = true

    return _ammo_cache

func get_mixed_reserve() -> PackedInt32Array:
    return _mixed_reserve

func get_reserve_total() -> int:
    if ammo_can_mix:
        return _mixed_reserve.size()
    else:
        return _simple_reserve_total

func get_reserve_type() -> int:
    return _simple_reserve_type

func get_default_ammo() -> AmmoResource:
    return ammo_supported[0]

func get_chamber_round() -> Dictionary:
    var ammo: AmmoResource = null
    if _chambered_round_type != 0:
        # NOTE: If you get a null error here, the problem is that ammo_bank
        #       is missing the ammo type chambered in this weapon. Go ensure
        #       ammo bank is being updated with the ammo contained in the gun!
        ammo = ammo_bank.get(_chambered_round_type).ammo
    return {
        'is_live': _chambered_round_live,
        'ammo': ammo
    }

func set_ammo_bank(value: Dictionary) -> void:
    if not value.has('owner'):
        push_error('Cannot assign an ammo bank without an RID!')
        return

    if ammo_bank.get('owner') == value.get('owner'):
        return

    ammo_bank = value

    # NOTE: we must set ammo_stock to empty because get_next_ammo() will
    #       read from it, so we avoid weird behavior with this.
    ammo_stock = {}
    ammo_stock = get_next_ammo()

func set_ammo_reserve_size(value: int) -> void:
    ammo_reserve_size = value

func set_alt_mode(value: bool) -> void:
    alt_mode = value

func is_chambered() -> bool:
    return _chambered_round_type > 0

func is_chambered_live() -> bool:
    return _chambered_round_live

func is_reserve_full() -> bool:
    return not get_reserve_total() < ammo_reserve_size

func can_eject() -> bool:
    return is_chambered()

func can_fire() -> bool:
    if melee_only:
        return false

    if can_chamber:
        if is_chambered():
            return _chambered_round_live
        else:
            return false

    return get_reserve_total() > 0

func can_melee() -> bool:
    # NOTE: for now, all weapons can melee
    return true

func can_charge() -> bool:
    if can_chamber and is_chambered():
        return not _chambered_round_live

    if not ammo_can_mix:
        return _simple_reserve_total > 0

    return _mixed_reserve.size() > 0

func can_reload() -> bool:
    if get_reserve_total() >= ammo_reserve_size:
        return false

    if not ammo_stock:
        return false

    if ammo_stock.amount < 1:
        return false

    return true

func can_unload() -> bool:
    # NOTE: weapon unloading should always emit a signal to eject any
    #       chambered round as part of the animation.
    return is_chambered() or get_reserve_total() > 0

## If the weapon has alternate fire behavior. Should return a consistent value.
func has_alt_mode() -> bool:
    return false

## If the weapon's alternate fire mode is persistent when switching out the weapon.
## Should return a consistent value.
func is_alt_mode_persistent() -> bool:
    return false

## If the weapon needs an alt mode transform, return it here. This transform is
## applied after scene offset, and interpolated when switching modes. Should
## return a consistent value.
func get_alt_transform() -> Transform3D:
    return Transform3D.IDENTITY

## Return the amount of time it should take to interpolate into/ out of alternate
## transform. This should return the time it will take to switch to the current
## value of alt_mode.
func get_alt_switch_time() -> float:
    return 0.0

## Charges the weapon; puts one in the chamber
func charge_weapon() -> void:
    # NOTE: This is for debugging, should be removed later
    if not can_chamber:
        push_error('Weapon cannot be chambered! This is a mistake! Investigate!')

    if _chambered_round_type != 0:
        push_error('Weapon has a chambered round, you must eject first! Investigate!')

    if not ammo_can_mix:
        _simple_reserve_total -= 1

        # NOTE: This is for debugging, should be removed later
        if _simple_reserve_total < 0:
            push_error('Weapon created negative ammo! This is a mistake! Investigate!')

        _chambered_round_type = _simple_reserve_type
        _chambered_round_live = true

        return

    var size: int = _mixed_reserve.size()
    if size < 1:
        push_error('Weapon tried to charge with no mixed reserve! This is a mistake! Investigate!')
        return

    if ammo_reversed_use:
        _chambered_round_type = _mixed_reserve[size - 1]
        _mixed_reserve.resize(size - 1)
    else:
        _chambered_round_type = _mixed_reserve[0]
        _mixed_reserve.remove_at(0)

    _chambered_round_live = true

## Replenish reserve ammo from ammo stock, handles mixed and magazine loads
func load_rounds(count: int = -1, type: int = 0) -> void:
    var reserve_total: int = get_reserve_total()

    var stock: Dictionary
    if type == 0:
        stock = ammo_stock
        type = stock.ammo.type
    else:
        stock = ammo_bank.get(type)

    if count == -1:
        if ammo_can_mix:
            count = 1
        else:
            count = mini(ammo_stock.amount, ammo_reserve_size - reserve_total)

    # NOTE: This is for debugging, should be removed later
    if count < 1:
        push_error('Weapon cannot load! This is a mistake! Investigate!')
        return

    ammo_stock.amount -= count

    # NOTE: This is for debugging, should be removed later
    if ammo_stock.amount < 0:
        push_error('Weapon used more ammo than in stock! This is a mistake! Investigate!')

    if ammo_can_mix:
        var size: int = _mixed_reserve.size()
        var new_size: int = size + count

        _mixed_reserve.resize(new_size)

        # NOTE: This is for debugging, should be removed later
        if not get_supported_ammunition().has(type):
            push_error('Weapon is loading an unsupported type! This is a mistake! Investigate!')

        for i in range(size, new_size):
            _mixed_reserve[i] = type

        # NOTE: This is for debugging, should be removed later
        if new_size > ammo_reserve_size:
            push_error('Weapon is over loaded! This is a mistake! Investigate!')

        return

    # NOTE: This is for debugging, should be removed later
    if _simple_reserve_type != 0 and type != _simple_reserve_type:
        push_error('Weapon is simple loading a different type! This is a mistake! Investigate!')

    _simple_reserve_type = type
    _simple_reserve_total += count

    # NOTE: This is for debugging, should be removed later
    if _simple_reserve_total > ammo_reserve_size:
        push_error('Weapon is over loaded! This is a mistake! Investigate!')

## Removes all reserve ammo back to ammo stock, handles mixed and magazine loads
func unload_rounds() -> void:
    if ammo_can_mix:
        for type in _mixed_reserve:
            ammo_bank.get(type).amount += 1
        return

    if _simple_reserve_type == 0:
        return

    if not ammo_bank.has(_simple_reserve_type):
        var supported: Dictionary = get_supported_ammunition()

        # NOTE: For debugging, should be removed
        if not supported.has(_simple_reserve_type):
            push_error('Trying to unload a weapon that holds unsupported ammo! This mistake! Investigate!')

        ammo_bank.set(_simple_reserve_type, {
                'amount': 0,
                'ammo': supported.get(_simple_reserve_type)
        })

    ammo_bank.get(_simple_reserve_type).amount += _simple_reserve_total
    _simple_reserve_total = 0
    _simple_reserve_type = 0

## Get the next ammo resource to be fired. Returns 'null' if nothing can be fired.
func get_ammo_to_fire() -> AmmoResource:
    var ammo_cache: Dictionary = get_supported_ammunition()

    if is_chambered():
        if not _chambered_round_live:
            return null
        return ammo_cache.get(_chambered_round_type)

    if not ammo_can_mix:
        push_error("Non-chambered, non-mixed reserve weapon type! This is a mistake! Investigate!")
        return null

    var size: int = _mixed_reserve.size()
    if size < 1:
        push_error("Weapon has no mixed reserve! Investigate!")
        return null

    if ammo_reversed_use:
        return ammo_cache.get(_mixed_reserve[size - 1])
    return ammo_cache.get(_mixed_reserve[0])

## Updates chambered round to be fired, returns true if ammo state changed
func fire_round() -> bool:
    var updated_ammo: bool = false

    if is_chambered():
        if _chambered_round_live:
            _chambered_round_live = false
            updated_ammo = true
    else:
        if not ammo_can_mix:
            push_error("Firing a simple reserve, non-chambered weapon! This is a mistake! Investigate!")
            return false

        var size: int = _mixed_reserve.size()
        if size > 0:
            if ammo_reversed_use:
                _mixed_reserve.resize(size - 1)
            else:
                _mixed_reserve.remove_at(0)
            updated_ammo = true

    return updated_ammo

## Fires projectile with given properties
func fire_projectiles(node: Node3D, ammo: AmmoResource, transform: Transform3D) -> void:
    var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
    var from: Vector3 = transform.origin
    var forward: Vector3 = transform.basis.z
    var right: Vector3 = transform.basis.x

    var projectile_forward: Vector3
    for i in range(ammo.projectiles):
        projectile_forward = forward

        # Random scatter, pick 2 angles, add them to the forward, normalize
        if projectile_inaccuracy > 0.0 and ammo.projectile_spread > 0.0:
            var spread: float = randf_range(0.0, 1.0)
            if ammo.projectile_clustering < 1.0:
                spread = lerp(sqrt(spread), spread, ammo.projectile_clustering)
            spread *= ammo.projectile_spread * projectile_inaccuracy

            projectile_forward = projectile_forward.rotated(right, spread)
            projectile_forward = projectile_forward.rotated(forward, randf_range(0.0, TAU))

        var to: Vector3 = from - projectile_forward * projectile_range
        var query := PhysicsRayQueryParameters3D.create(from, to, projectile_hit_mask)

        query.collide_with_areas = true
        query.collide_with_bodies = true

        var hit := space.intersect_ray(query)
        if hit:
            to = hit.position

            if debug_enabled:
                var color: Color = DEBUG_HIT_COLOR
                if debug_use_color:
                    color = debug_hit_color
                DrawLine3d.DrawLine(from, to, color, debug_time_to_live)

        if not hit:
            if debug_enabled:
                var color: Color = DEBUG_MISS_COLOR
                if debug_use_color:
                    color = debug_miss_color
                DrawLine3d.DrawLine(from, to, color, debug_time_to_live)
            continue

        if debug_enabled:
            if debug_use_color:
                DebugSphere.create(node, hit.position, debug_time_to_live, debug_sphere_radius)
            else:
                DebugSphere.create_color(node, hit.position, debug_time_to_live, debug_sphere_radius, debug_sphere_color)

        if hit.collider is HurtBox:
            hit.power = ammo.impulse_power
            hit.from = from
            # NOTE: i do not understand why this is different than the impulse direction...
            hit.direction = -projectile_forward
            hit.collider.do_hit(node, hit, ammo.damage)

## Fires melee raycast with given properties
func fire_melee(node: Node3D, transform: Transform3D, melee_excluded_hurtboxes: Array[RID]) -> void:
    var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state

    var from: Vector3 = transform.origin
    var forward: Vector3 = transform.basis.z
    var to: Vector3 = from - forward * melee_range
    var query := PhysicsRayQueryParameters3D.create(
            from,
            to,
            melee_collision
    )

    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.exclude = melee_excluded_hurtboxes

    var hit := space.intersect_ray(query)

    if not hit:
        return

    if hit.collider is HurtBox:
        #total_hits += 1
        hit.power = melee_impact
        hit.from = from
        # NOTE: i do not understand why this is different than the impulse direction...
        hit.direction = -forward
        hit.collider.do_hit(node, hit, melee_damage)
