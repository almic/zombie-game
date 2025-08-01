@tool
@icon("res://icon/weapon.svg")

## Manages a physical weapon that targets a RayCast3D hit point
class_name WeaponNode extends Node3D

@export var controller: Node3D

## Activated by weapons that use hitboxes
@export var hitbox: HitBox

@export var weapon_type: WeaponResource

## If the weapon should align itself with the target RayCast3D. You should
## disable this for melee weapons.
@export var do_targeting: bool = true
## Aim target for weapon
@export var target: RayCast3D
## Speed for weapon re-targeting
@export var target_update_speed: float = 15
## Frequency of target position checks in physics frames.
@export var target_update_rate: int = 3


# For moving weapon to face target
var _weapon_target_from: Quaternion
var _weapon_target_to: Quaternion
var _weapon_target_tick: int = 0
var _weapon_target_amount: float = 0

var _weapon_trigger: GUIDEAction

var _weapon_scene: WeaponScene

var _particle_system: ParticleSystem

var _weapon_audio_player: WeaponAudioPlayer


func _ready() -> void:
    _load_weapon_scene()
    _load_particle_system()

    _weapon_audio_player = WeaponAudioPlayer.new()
    _weapon_audio_player.weapon_sound_resource = weapon_type.sound_effect
    add_child(_weapon_audio_player)

func set_trigger(action: GUIDEAction) -> void:
    _weapon_trigger = action

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if weapon_type:
            if _weapon_scene:
                _weapon_scene.position = weapon_type.scene_offset
            if weapon_type.particle_test:
                _load_particle_system()
                trigger_particle(true)
                weapon_type.particle_test = false
            if weapon_type.sound_test:
                # re-apply the sound in case it was changed
                _weapon_audio_player.weapon_sound_resource = weapon_type.sound_effect
                trigger_sound()
                weapon_type.sound_test = false
        return

    if not do_targeting:
        return

    if _weapon_target_to.is_equal_approx(_weapon_scene.global_basis.get_rotation_quaternion()):
        return

    _weapon_target_amount += target_update_speed * delta
    _weapon_scene.global_basis = Basis(
        _weapon_target_from.slerp(_weapon_target_to, _weapon_target_amount)
    )

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    weapon_type.trigger_method.update(
        _weapon_trigger,
        self,
        delta
    )

    if not do_targeting:
        return

    _weapon_target_tick += 1
    if _weapon_target_tick < target_update_rate:
        return
    _weapon_target_tick = 0

    if target.is_colliding():
        # DrawLine3d.DrawLine(mesh.global_position, target.get_collision_point(), Color(0.2, 0.25, 0.8), 1)
        _weapon_target_to = Quaternion(
            Basis.looking_at(
                _weapon_scene.global_position.direction_to(
                    target.get_collision_point()
                ), target.basis.y
            )
        )
    else:
        # Aim forward
        _weapon_target_to = target.global_basis.get_rotation_quaternion()

    _weapon_target_from = _weapon_scene.global_basis.get_rotation_quaternion()
    _weapon_target_amount = 0

## Get the global weapon transform
func weapon_tranform() -> Transform3D:
    return _weapon_scene.global_transform

## Callback used by triggers to activate weapon effects
func play_weapon_effects() -> void:
    trigger_sound()
    trigger_particle()

    if _weapon_scene:
        _weapon_scene.on_fire()

## Trigger the weapon
func trigger_weapon(activate: bool = true) -> void:
    weapon_type.trigger_method._trigger(self, activate)

## Trigger the weapon sound
func trigger_sound(_activate: bool = true) -> void:
    _weapon_audio_player.play_sound()

## Trigger the particle effect
func trigger_particle(activate: bool = true) -> void:
    if not _particle_system:
        return

    _particle_system.emitting = activate

func _load_weapon_scene() -> void:
    if _weapon_scene:
        _weapon_scene.swap_hand.disconnect(on_swap_hand)
        remove_child(_weapon_scene)
        _weapon_scene.queue_free()
        _weapon_scene = null

    if not weapon_type.weapon_scene:
        return

    var weapon_scene = weapon_type.weapon_scene.instantiate()
    if weapon_scene is not WeaponScene:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" weapon scene \"" +
            str(weapon_type.weapon_scene.resource_name) +
            "\" root node is not a WeaponScene!"
        )
        return

    _weapon_scene = weapon_scene

    add_child(_weapon_scene)
    _weapon_scene.position = weapon_type.scene_offset
    _weapon_scene.swap_hand.connect(on_swap_hand)

func _load_particle_system() -> void:
    if _particle_system:
        remove_child(_particle_system)
        _particle_system.queue_free()
        _particle_system = null

    if not weapon_type.particle_system:
        return

    var particle_system = weapon_type.particle_system.instantiate()
    if particle_system is not ParticleSystem:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" particle system \"" +
            str(weapon_type.particle_system.resource_name) +
            "\" root node is not a ParticleSystem!"
        )
        return
    _particle_system = particle_system

    add_child(_particle_system)
    _particle_system.position = weapon_type.particle_offset

func on_swap_hand(time: float) -> void:
    if not controller:
        return

    if controller.has_method('swap_hand'):
        controller.swap_hand(time)
