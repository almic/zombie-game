@tool
@icon("res://icon/weapon.svg")

## Defines a weapon type that can be used in the world
class_name WeaponResource extends PickupResource


## Weapon name in UI elements
@export var name: String

## The unique slot of the weapon
@export_range(1, 10, 1)
var slot: int = 1

## Melee damage of the weapon
@export_range(-50.0, 50.0, 0.1, 'or_greater', 'or_less', 'suffix:hp')
var melee_damage: float = 0.0

## Impact force for melee
@export_range(0.0, 50.0, 0.01, 'or_greater', 'or_less', 'suffix:N')
var melee_impact: float = 0.0


@export_group("Mechanism")

## How this weapon is triggered
@export var trigger_mechanism: TriggerMechanism

## The weapon can chamber a round, such that the effective ammo
## capacity is reserve + 1
@export var can_chamber: bool = false

## If the weapon automatically chambers the next round when fired
@export var chamber_on_fire: bool = false


@export_group("Ballistics", "projectile")

## Spread, or inaccuracy, of the weapon
@export_range(0.0, 10.0, 0.001, 'or_greater', 'radians_as_degrees')
var projectile_spread: float = PI / 36

## Clustering of projectiles within the spread. 0.0 means a totally
## random spread, 1.0 means the projectiles cluster towards the middle.
@export_range(0.0, 1.0, 0.001)
var projectile_clustering: float = 0.5

## Maximum hit detection range
@export var projectile_range: float

## Hit collision mask
@export_flags_3d_physics var projectile_hit_mask: int = 8


@export_group("Ammunition", "ammo")

## Reserve capacity for ammo
@export_range(1, 100, 1, 'or_greater')
var ammo_reserve_size: int = 10

## If the weapon supports mixing ammo loads
@export var ammo_can_mix: bool = false

## When mixing ammo, what order is ammo used? For example, a player loads
## ammo A, then ammo B. When this is true, B is used before A.
@export var ammo_reversed_use: bool = false

## Supported ammunition types, only used to compare IDs.
@export var ammo_supported: Array[AmmoResource]


@export_group("Scene", "")
@export var scene: PackedScene
@export var scene_offset: Vector3


@export_group("Particle System", "particle")
## The particle to use when firing
@export var particle_scene: PackedScene
## Offset of the scene relative to the barrel
@export var particle_offset: Vector3
## In Editor only, trigger the particle system for visualization
@export var particle_test: bool


@export_group("Sound", "sound")
## Sound effect for this weapon
@export var sound_effect: WeaponAudioResource

## Toggle this to listen to the sound effect in-engine
@export var sound_test: bool = false


# Cached map of supported ammo IDs to ammo resource
var _ammo_cache: Dictionary
var _is_ammo_cached: bool = false


var _simple_reserve_total: int = 0
var _simple_reserve_type: int = 0

var _chambered_round_type: int = 0

var _mixed_reserve: PackedInt32Array = []


func get_supported_ammunition() -> Dictionary:
    if not _is_ammo_cached:
        _ammo_cache = {}
        for ammo in ammo_supported:
            _ammo_cache.set(ammo.ammo_type, ammo)
        _is_ammo_cached = true

    return _ammo_cache


func get_reserve_total() -> int:
    if ammo_can_mix:
        return _mixed_reserve.size()
    else:
        return _simple_reserve_total

func get_reserve_type() -> int:
    return _simple_reserve_type

func get_default_ammo_type() -> int:
    if ammo_supported.size() < 1:
        return 0
    return ammo_supported.front().ammo_type

func is_chambered() -> bool:
    return _chambered_round_type > 0


func charge_weapon() -> bool:
    if not can_chamber or _chambered_round_type != 0:
        return false

    if not ammo_can_mix:
        if _simple_reserve_total < 1:
            return false

        _simple_reserve_total -= 1
        _chambered_round_type = _simple_reserve_type

        return true

    var size: int = _mixed_reserve.size()
    if size < 1:
        return false

    if ammo_reversed_use:
        _chambered_round_type = _mixed_reserve[size - 1]
        _mixed_reserve.resize(size - 1)
    else:
        _chambered_round_type = _mixed_reserve[0]
        _mixed_reserve.remove_at(0)

    return true


func load_rounds(type: int, count: int) -> void:
    if count < 1:
        return

    if ammo_can_mix:
        var size: int = _mixed_reserve.size()
        var new_size: int = size + count

        _mixed_reserve.resize(new_size)

        for i in range(size, new_size):
            _mixed_reserve[i] = type

        return

    if type != _simple_reserve_type:
        _simple_reserve_type = type
        _simple_reserve_total = count
    else:
        _simple_reserve_total += count


## Fires the next loaded projectile, updates ammo reserves
func fire_projectiles(base: WeaponNode) -> void:
    var ammo_cache: Dictionary = get_supported_ammunition()
    var ammo: AmmoResource

    if can_chamber and is_chambered():
        ammo = ammo_cache.get(_chambered_round_type)
        _chambered_round_type = 0
    else:
        if not ammo_can_mix:
            if _simple_reserve_total < 1:
                push_error("Firing weapon with no reserve! WeaponNode should not allow this!")
                return
            ammo = ammo_cache.get(_simple_reserve_type)
            _simple_reserve_total -= 1
        else:
            var size: int = _mixed_reserve.size()
            if size < 1:
                push_error("Firing weapon with no mixed reserve! WeaponNode should not allow this!")
                return

            if ammo_reversed_use:
                ammo = ammo_cache.get(_mixed_reserve[size - 1])
                _mixed_reserve.resize(size - 1)
            else:
                ammo = ammo_cache.get(_mixed_reserve[0])
                _mixed_reserve.remove_at(0)

    if not ammo:
        push_error("Firing weapon got no ammo to fire! Investigate!")
        return

    if chamber_on_fire:
        charge_weapon()

    var space: PhysicsDirectSpaceState3D = base.get_world_3d().direct_space_state
    var transform: Transform3D = base.weapon_projectile_transform()
    var from: Vector3 = transform.origin
    var forward: Vector3 = transform.basis.z
    var right: Vector3 = transform.basis.x

    #var max_y: float = 0.0
    #var avg_y: float = 0.0
    #var total_hits: int = 0

    var projectile_forward: Vector3
    for i in range(ammo.projectiles):
        projectile_forward = forward

        # Random scatter, pick 2 angles, add them to the forward, normalize
        if projectile_spread > 0.0:
            var spread: float = randf_range(0.0, 1.0)
            if projectile_clustering < 1.0:
                spread = lerp(sqrt(spread), spread, projectile_clustering)
            spread *= projectile_spread

            projectile_forward = projectile_forward.rotated(right, spread)
            projectile_forward = projectile_forward.rotated(forward, randf_range(0.0, TAU))

        var to: Vector3 = from - projectile_forward * projectile_range
        var query := PhysicsRayQueryParameters3D.create(from, to, projectile_hit_mask)

        query.collide_with_areas = true
        query.collide_with_bodies = true

        var hit := space.intersect_ray(query)
        if hit:
            to = hit.position
            #var y_diff: float = abs(from.y - to.y)
            #avg_y += y_diff
            #if y_diff > max_y:
                #max_y = y_diff

        #DrawLine3d.DrawLine(from, to, Color(0.9, 0.15, 0.15, 0.2), 5)

        if not hit:
            continue

        if hit.collider is HurtBox:
            #total_hits += 1
            var from_node: Node3D = base
            if base.controller:
                from_node = base.controller
            hit.power = ammo.impulse_power
            hit.from = from
            # NOTE: i do not understand why this is different than the impulse direction...
            hit.direction = -projectile_forward
            hit.collider.do_hit(from_node, hit, ammo.damage)


    #print('max y: ' + str(max_y))
    #print('avg y: ' + str(avg_y / bullets))
    #print('hits: ' + str(total_hits))
