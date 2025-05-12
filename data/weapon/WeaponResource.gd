class_name WeaponResource extends Resource

@export var mesh: Mesh
@export var offset: Vector3

@export var damage: float
@export var max_range: float

## Weapon cycle time, minimum time between consecutive fires
@export var cycle_time: float
## If the weapon fires continuously while held, or if the trigger must
## be released.
@export var automatic: bool

@export_flags_3d_physics var raycast_mask: int = 8
