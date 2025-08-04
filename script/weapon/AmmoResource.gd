
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

## Spread, or inaccuracy, of the weapon
@export_range(0.0, 10.0, 0.001, 'or_greater', 'radians_as_degrees')
var projectile_spread: float = PI / 36

## Clustering of projectiles within the spread. 0.0 means a totally
## random spread, 1.0 means the projectiles cluster towards the middle.
@export_range(0.0, 1.0, 0.001)
var projectile_clustering: float = 0.5
