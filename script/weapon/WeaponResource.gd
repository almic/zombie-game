@tool
@icon("res://icon/weapon.svg")

## Defines a weapon type that can be used in the world
class_name WeaponResource extends Resource

@export var mesh: Mesh
@export var mesh_offset: Vector3

## The particle to use when firing. The root node MUST be a ParticleSystem, or
## no particles will be emitted. This is an optimization to avoid instancing
## scenes each time particles should be emitted, and instead toggle the
## particle system directly.
@export var particle_system: PackedScene
@export var particle_offset: Vector3
## In Editor only, trigger the particle system for visualization
@export var particle_test: bool

## Damage to deal on hit
@export var damage: float
## Maximum hit detection range
@export var max_range: float
## Hit collision mask
@export_flags_3d_physics var hit_mask: int = 8

## How this weapon is triggered
@export var trigger_method: TriggerResource
