
## Describes an ammo type
class_name AmmoResource extends PickupResource

## Unique type ID. Weapons support ammo by type IDs.
@export_range(1, 10, 1, 'or_greater')
var ammo_type: int = 1

## Damage per projectile.
@export_range(-50.0, 50.0, 0.1, 'or_greater', 'or_less', 'suffix:hp')
var damage: float = 0.0

## Impulse power per projectile.
@export_range(0.0, 50.0, 0.01, 'or_greater', 'or_less', 'suffix:N')
var impulse_power: float = 10.0

## Number of projectiles
@export_range(1, 12, 1, 'or_greater')
var projectiles: int = 1
