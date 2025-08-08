@tool
@icon("res://icon/weapon.svg")

## Links the weapon's visual with the weapon's logical components.
## Also turns the weapon for targetting.
class_name WeaponNode extends Node3D


## Result of trying to perform an action on a weapon
enum Action {
    BLOCKED,
    OKAY,
    NOT_READY
}


signal ammo_updated()

signal reload_complete()


@export var controller: CharacterBase

## Activated by weapons that use hitboxes
@export var hitbox: HitBox

@export var weapon_type: WeaponResource:
    set = load_weapon_type

## If the weapon should align itself with the target RayCast3D. You should
## disable this for melee weapons.
@export var do_targeting: bool = true
## Aim target for weapon
@export var target: RayCast3D
## Speed for weapon re-targeting
@export var target_update_speed: float = 15
## Frequency of target position checks in physics frames.
@export var target_update_rate: int = 3

## Ammo bank to use for weapons
var ammo_bank: Dictionary

# For moving weapon to face target
var _weapon_target_from: Quaternion
var _weapon_target_to: Quaternion
var _weapon_target_tick: int = 0
var _weapon_target_amount: float = 0

var continue_reload: bool = false:
    set = set_continue_reload

var continue_unload: bool = false:
    set = set_continue_unload

var _weapon_scene: WeaponScene

var _particle_system: ParticleSystem

var _weapon_audio_player: WeaponAudioPlayer

var melee_excluded_hurtboxes: Array[RID]


func _ready() -> void:
    _weapon_audio_player = WeaponAudioPlayer.new()
    add_child(_weapon_audio_player)

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

    update_targetting(delta)

func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if not do_targeting or not _weapon_scene:
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

func update_targetting(delta: float) -> void:
    if not do_targeting or not _weapon_scene:
        return

    if _weapon_target_to.is_equal_approx(_weapon_scene.global_basis.get_rotation_quaternion()):
        return

    _weapon_target_amount += target_update_speed * delta
    _weapon_scene.global_basis = Basis(
        _weapon_target_from.slerp(_weapon_target_to, _weapon_target_amount)
    )

## Get the global weapon transform
func weapon_tranform() -> Transform3D:
    return _weapon_scene.global_transform

## Get the transform of the weapon projectile marker
func weapon_projectile_transform() -> Transform3D:
    if _weapon_scene and _weapon_scene.projectile_marker:
        return _weapon_scene.projectile_marker.global_transform
    return weapon_tranform()

func aim_target_transform() -> Transform3D:
    return target.global_transform

func set_continue_reload(value: bool) -> void:
    continue_reload = value

func set_continue_unload(value: bool) -> void:
    continue_unload = value

func set_melee_excluded_hurboxes(hurtboxes: Array[HurtBox]) -> void:
    melee_excluded_hurtboxes.assign(hurtboxes.map(func (h): return h.get_rid()))

func set_walking(walking: bool) -> void:
    if not _weapon_scene:
        return

    _weapon_scene.is_walking = walking

## Switches ammo types, returns true if successful
func switch_ammo() -> bool:
    # There is no animation to switch ammo type, so just pass to weapon
    if not weapon_type:
        return false

    if not weapon_type.switch_ammo():
        return false

    ammo_updated.emit()

    if not _weapon_scene:
        return true

    # Put the reload mesh on the weapon
    _weapon_scene.set_reload_ammo(weapon_type.ammo_stock.ammo)
    return true

## Updates weapon trigger, can fire
func update_trigger(triggered: bool, delta: float) -> Action:
    var mechanism: TriggerMechanism = weapon_type.trigger_mechanism

    mechanism.tick(delta)
    mechanism.update_trigger(triggered)

    if not mechanism.should_trigger() or not weapon_type.can_fire():
        return Action.BLOCKED

    if _weapon_scene.goto_fire():
        return Action.OKAY

    return Action.NOT_READY

## Test if the weapon could be aiming right now
func can_aim() -> bool:
    if not weapon_type.aim_enabled:
        return false

    return _weapon_scene.can_aim()

## The weapon should charge
func charge() -> Action:
    if not weapon_type.can_charge():
        return Action.BLOCKED

    if _weapon_scene.goto_charge():
        return Action.OKAY

    return Action.NOT_READY

## The weapon should do a melee
func melee() -> Action:
    if not weapon_type.can_melee():
        return Action.BLOCKED

    if _weapon_scene.goto_melee():
        return Action.OKAY

    return Action.NOT_READY

## The weapon should reload
func reload() -> Action:
    if not weapon_type.can_reload():
        return Action.BLOCKED

    if _weapon_scene.goto_reload():
        return Action.OKAY

    return Action.NOT_READY

## The weapon should unload
func unload() -> Action:
    if not weapon_type.can_unload():
        return Action.BLOCKED

    if _weapon_scene.goto_unload():
        return Action.OKAY

    return Action.NOT_READY

func has_ammo_stock() -> bool:
    return not weapon_type.ammo_stock.is_empty()

## Trigger the weapon sound
func trigger_sound(_activate: bool = true) -> void:
    _weapon_audio_player.play_sound()

## Trigger the particle effect
func trigger_particle(activate: bool = true) -> void:
    if not _particle_system:
        return

    _particle_system.emitting = activate

func load_weapon_type(type: WeaponResource) -> void:
    weapon_type = type

    continue_reload = false
    continue_unload = false

    _load_weapon_scene()
    _load_particle_system()

    if not weapon_type:
        return

    weapon_type.ammo_bank = ammo_bank

    _weapon_audio_player.weapon_sound_resource = weapon_type.sound_effect

func _load_weapon_scene() -> void:
    if _weapon_scene:
        _weapon_scene.fired.disconnect(on_weapon_fire)
        _weapon_scene.melee.disconnect(on_weapon_melee)
        _weapon_scene.charged.disconnect(on_weapon_charged)
        _weapon_scene.reload_loop.disconnect(on_weapon_reload_loop)
        _weapon_scene.unload_loop.disconnect(on_weapon_unload_loop)
        _weapon_scene.round_ejected.disconnect(on_weapon_round_ejected)
        _weapon_scene.round_loaded.disconnect(on_weapon_round_loaded)
        _weapon_scene.round_unloaded.disconnect(on_weapon_round_unloaded)

        remove_child(_weapon_scene)
        _weapon_scene.queue_free()
        _weapon_scene = null

    if not weapon_type or not weapon_type.scene:
        return

    var weapon_scene = weapon_type.scene.instantiate()
    if weapon_scene is not WeaponScene:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" weapon scene \"" +
            str(weapon_type.scene.resource_name) +
            "\" root node is not a WeaponScene!"
        )
        return

    _weapon_scene = weapon_scene

    add_child(_weapon_scene)
    _weapon_scene.position = weapon_type.scene_offset
    _weapon_scene.fired.connect(on_weapon_fire)
    _weapon_scene.melee.connect(on_weapon_melee)
    _weapon_scene.charged.connect(on_weapon_charged)
    _weapon_scene.reload_loop.connect(on_weapon_reload_loop)
    _weapon_scene.unload_loop.connect(on_weapon_unload_loop)
    _weapon_scene.round_ejected.connect(on_weapon_round_ejected)
    _weapon_scene.round_loaded.connect(on_weapon_round_loaded)
    _weapon_scene.round_unloaded.connect(on_weapon_round_unloaded)
    _weapon_scene.goto_ready()

func _load_particle_system() -> void:
    if _particle_system:
        remove_child(_particle_system)
        _particle_system.queue_free()
        _particle_system = null

    if not weapon_type or not weapon_type.particle_scene:
        return

    var particle_system = weapon_type.particle_scene.instantiate()
    if particle_system is not ParticleSystem:
        push_error(
            "Weapon type \"" +
            str(weapon_type.resource_name) +
            "\" particle system \"" +
            str(weapon_type.particle_scene.resource_name) +
            "\" root node is not a ParticleSystem!"
        )
        return
    _particle_system = particle_system

    if _weapon_scene.particle_marker:
        _weapon_scene.particle_marker.add_child(_particle_system)
    else:
        add_child(_particle_system)
    _particle_system.position = weapon_type.particle_offset

func on_weapon_fire() -> void:
    if not weapon_type:
        return

    if not Engine.is_in_physics_frame():
        get_tree().physics_frame.connect(on_weapon_fire, Object.CONNECT_ONE_SHOT)
        return

    trigger_sound()
    trigger_particle()

    if weapon_type.fire(self):
        ammo_updated.emit()

func on_weapon_melee() -> void:
    if not weapon_type:
        return

    if not Engine.is_in_physics_frame():
        get_tree().physics_frame.connect(on_weapon_melee, Object.CONNECT_ONE_SHOT)
        return

    weapon_type.fire_melee(self)

func on_weapon_charged() -> void:
    if not weapon_type or not weapon_type.can_charge():
        return

    weapon_type.charge_weapon()

func on_weapon_reload_loop() -> void:
    if not continue_reload:
        reload_complete.emit()
        return

    if weapon_type.can_reload():
        _weapon_scene.goto_reload_continue()
    else:
        reload_complete.emit()
        continue_reload = false

func on_weapon_unload_loop() -> void:
    if continue_unload:
        _weapon_scene.goto_unload_continue()

func on_weapon_round_loaded() -> void:
    if not weapon_type:
        return

    weapon_type.load_rounds()
    ammo_updated.emit()

func on_weapon_round_ejected() -> void:
    if not weapon_type or not weapon_type.can_eject():
        return

    var round_dict: Dictionary = weapon_type.get_chamber_round()

    if weapon_type.eject_round():
        ammo_updated.emit()

    _weapon_scene.eject_round(
        round_dict,
        controller.velocity,
        weapon_type.ammo_expend_direction,
        weapon_type.ammo_expend_direction_range,
        weapon_type.ammo_expend_force,
        weapon_type.ammo_expend_force_range,
    )

func on_weapon_round_unloaded() -> void:
    # NOTE: keeping this for naming, in the event a weapon is made that
    #       does something else, but these are fundamentally the same
    #       operation in all currently planned weapons.
    on_weapon_round_ejected()
