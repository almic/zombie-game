@tool
@icon("res://icon/weapon.svg")

class_name RevolverWeapon extends WeaponResource


## Holds ammo expend state, 0 for used, 1 for unused
var _cylinder_ammo_state: PackedByteArray = []

## Position of the cylinder, from 0 to reserve size
var _cylinder_position: int = 0

## If the hammer is cocked
var _hammer_cocked: bool = false





## Rotates the cylinder by a given number of places. Positive is clockwise,
## negative is counter-clockwise.
func rotate_cylinder(places: int = 1) -> void:
    _cylinder_position = wrapi(_cylinder_position + places, 0, ammo_reserve_size)

func get_reserve_total() -> int:
    return _cylinder_ammo_state.count(1)

func set_ammo_reserve_size(value: int) -> void:
    ammo_reserve_size = value
    _mixed_reserve.resize(ammo_reserve_size)
    _cylinder_ammo_state.resize(ammo_reserve_size)

## For the revolver, we can eject if the cylinder is on a round
func can_eject() -> bool:
    return _mixed_reserve[_cylinder_position] > 0

## For the revolver, you can always pull the trigger
func can_fire() -> bool:
    return true

func can_charge() -> bool:
    return not _hammer_cocked

## For the revolver, you can always unload
func can_unload() -> bool:
    return true

## For the revolver, charging is just cocking the hammer
func charge_weapon() -> void:
    _hammer_cocked = true

## Loading a round places it into the current position. This clobbers whatever
## is at that position, so be sure it is empty!
func load_rounds(count: int = 1, type: int = 0) -> void:
    var stock: Dictionary
    if type == 0:
        stock = ammo_stock
        type = stock.ammo.type
    else:
        stock = ammo_bank.get(type)

    # NOTE: This is for debugging, should be removed later
    if count < 1:
        push_error('Revolver cannot load! This is a mistake! Investigate!')
        return

    ammo_stock.amount -= count

    # NOTE: This is for debugging, should be removed later
    if ammo_stock.amount < 0:
        push_error('Revolver used more ammo than in stock! This is a mistake! Investigate!')

    # NOTE: This is for debugging, should be removed later
    if not get_supported_ammunition().has(type):
        push_error('Weapon is loading an unsupported type! This is a mistake! Investigate!')

    _mixed_reserve.set(_cylinder_position, type)
    _cylinder_ammo_state.set(_cylinder_position, 1)

    # NOTE: This is for debugging, should be removed later
    if _mixed_reserve.size() > ammo_reserve_size:
        push_error('Revolver is over loaded! This is a mistake! Investigate!')

## For the revolver, ejects all spent rounds and leaves live rounds.
func unload_rounds() -> void:
    for i in range(0, ammo_reserve_size):
        if _cylinder_ammo_state[i]:
            continue
        _mixed_reserve.set(i, 0)

func fire_projectiles(base: WeaponNode) -> bool:
    var updated_ammo: bool = false
    var ammo_cache: Dictionary = get_supported_ammunition()
    var type: int = _mixed_reserve[_cylinder_position]
    var ammo: AmmoResource = ammo_cache.get(type)

    if not ammo:
        push_error("Firing weapon got no ammo to fire! Investigate!")
        return updated_ammo

    # NOTE: For debugging only, should be removed
    if not _cylinder_ammo_state[_cylinder_position]:
        push_error("Revolver is firing a dead round! Investigate!")

    var node: Node3D = base
    if base.controller:
        node = base.controller

    _do_projectile_raycast(node, ammo, base.weapon_projectile_transform())

    _cylinder_ammo_state[_cylinder_position] = 0

    # If we are empty, signal
    if get_reserve_total() < 1:
        out_of_ammo.emit()

    return updated_ammo
