
## Describes an ammo type
class_name AmmoResource extends PickupResource

## Unique type ID. Weapons support ammo by type IDs.
@export_range(1, 10, 1, 'or_greater')
var type: int = 1

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


@export_group("Display", "")

## Texture displayed for stock selection and in weapon reserves
@export var ui_texture: Texture2D

## Alternate texture for UI. Only used for revolver weapon.
@export var alt_ui_texture: Texture2D

## Height of the icon in stock selection.
## Weapons manage their own icon sizes.
@export_range(1.0, 100.0, 1.0, 'or_greater')
var stock_height: int = 50

## Rotation of texture in stock selection.
## Weapons manage their own reserve icon sizes.
@export_range(-180.0, 180.0, 0.001, 'radians_as_degrees')
var stock_rotation: float = 0.0

## Pivot location for rotation in stock selection.
## Weapons manage their own reserve icon rotation.
@export var stock_pivot: Vector2 = Vector2(0.5, 0.5)

## Scene used for a fresh round
@export var scene_round: PackedScene

## Scene used for an expended (used) round
@export var scene_round_expended: PackedScene

## Scene used for an fresh, unloading round
@export var scene_round_unloaded: PackedScene
