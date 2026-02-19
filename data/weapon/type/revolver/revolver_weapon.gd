@tool
@icon("res://icon/weapon.svg")

class_name RevolverWeapon extends WeaponResource


## Additional offset when fanning the hammer, on top of the scene offset
@export var fan_offset: Vector3 = Vector3.ZERO

## Time to switch into fan the hammer mode
@export var fan_into_time: float = 0.35

## Time to switch out of fan the hammer mode
@export var fan_out_time: float = 0.65


## Holds ammo expend state, 0 for used, 1 for unused
var _cylinder_ammo_state: PackedByteArray = []

## Position of the cylinder, from 0 to reserve size.
var _cylinder_position: int = 0

## If the hammer is cocked
var hammer_cocked: bool = false


func _init() -> void:
    rotate_cylinder.call_deferred(0)


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

## For the revolver, ejects the current cylinder round only.
## Returns true if a chambered round was ejected
func eject_round() -> bool:
    # NOTE: For the revolver, all spent rounds are ejected before removing
    #       live rounds, so this should always replenish stock on a non-empty port

    # Empty port
    var type: int = _mixed_reserve[_cylinder_position]
    if not type:
        return false

    _mixed_reserve[_cylinder_position] = 0

    if _cylinder_ammo_state[_cylinder_position]:
        # Recover round to ammo stock
        var stock: Dictionary = ammo_bank.get(type)
        if stock:
            stock.amount += 1
        _cylinder_ammo_state[_cylinder_position] = 0
        return true

    # NOTE: For debugging, should be removed
    push_error("Revolver tried to eject a dead round! This is a mistake! Investigate!")
    return true

## For the revolver, we can eject if the cylinder is on a round
func can_eject() -> bool:
    return _mixed_reserve[_cylinder_position] > 0

## You can always pull the trigger for the revolver
func can_fire() -> bool:
    return true

func can_charge() -> bool:
    return not hammer_cocked

## For the revolver, you can unload if there are any rounds
func can_unload() -> bool:
    for t in _mixed_reserve:
        if t != 0:
            return true
    return false

## Fan the hammer mode
func has_alt_mode() -> bool:
    return true

## Fan the hammer mode
func get_alt_transform() -> Transform3D:
    return Transform3D.IDENTITY.translated(fan_offset)

## Fan the hammer mode
func get_alt_switch_time() -> float:
    if alt_mode:
        return fan_into_time
    return fan_out_time

## If the round in position is live
func is_round_live() -> bool:
    return _cylinder_ammo_state[_cylinder_position] != 0

## For the revolver, charging cocks the hammer and rotates clockwise 1 place
func charge_weapon() -> void:
    if hammer_cocked:
        return
    hammer_cocked = true
    if trigger_mechanism is DoubleActionMechanism:
        trigger_mechanism.primed = true
    rotate_cylinder(1)

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

    var pos: int
    for i in range(count):
        # NOTE: load in the same direction as reloads, which is negative
        pos = wrapi(_cylinder_position - i, 0, ammo_reserve_size)
        _mixed_reserve.set(pos, type)
        _cylinder_ammo_state.set(pos, 1)

    # NOTE: This is for debugging, should be removed later
    if _mixed_reserve.size() > ammo_reserve_size:
        push_error('Revolver is over loaded! This is a mistake! Investigate!')

## For the revolver, ejects all spent rounds and leaves live rounds.
func unload_rounds() -> void:
    for i in range(0, ammo_reserve_size):
        if _cylinder_ammo_state[i]:
            continue
        _mixed_reserve.set(i, 0)

func get_ammo_to_fire() -> AmmoResource:
    if not is_round_live():
        return null

    var ammo_cache: Dictionary = get_supported_ammunition()
    return ammo_cache.get(_mixed_reserve[_cylinder_position])

func fire_round() -> bool:
    var updated_ammo: bool = false

    if alt_mode:
        # In fan-the-hammer mode, ensure the weapon is always charged
        charge_weapon()

    if is_round_live():
        _cylinder_ammo_state[_cylinder_position] = 0
        updated_ammo = true

    if hammer_cocked:
        hammer_cocked = false
        updated_ammo = true
        if trigger_mechanism is DoubleActionMechanism:
            trigger_mechanism.primed = false

    return updated_ammo
