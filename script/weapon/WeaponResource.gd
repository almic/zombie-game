@tool
@icon("res://icon/weapon.svg")

## Defines a weapon type that can be used in the world
class_name WeaponResource extends PickupResource

## Weapon name in UI elements
@export var name: String

@export var weapon_scene: PackedScene

@export_group("Scene", "scene")
@export var scene_offset: Vector3

## The particle to use when firing. The root node MUST be a ParticleSystem, or
## no particles will be emitted. This is an optimization to avoid instancing
## scenes each time particles should be emitted, and instead toggle the
## particle system directly.
@export var particle_system: PackedScene

@export_group("Particle System", "particle")
@export var particle_offset: Vector3
## In Editor only, trigger the particle system for visualization
@export var particle_test: bool

@export_range(0, 9, 1)
var slot: int = 0

## Damage to deal on hit
@export_range(-50.0, 50.0, 0.01, 'or_greater', 'or_less', 'suffix:hp')
var damage: float

## How this weapon is triggered
@export var trigger_method: TriggerResource

## Sound effect for this weapon
@export var sound_effect: WeaponAudioResource

@export_group("Sound", "sound")
## Toggle this to listen to the sound effect in-engine
@export var sound_test: bool = false

@export_group("Hit Detection", "")
## Maximum hit detection range
@export var max_range: float
## Hit collision mask
@export_flags_3d_physics var hit_mask: int = 8
