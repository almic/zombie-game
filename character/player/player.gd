@tool

class_name Player extends CharacterBase


const LOOK_UP_MAX = deg_to_rad(89)
const LOOK_DOWN_MAX = deg_to_rad(-89)


@onready var neck: Node3D = %Neck
@onready var camera_target: Node3D = %CameraTarget
@onready var camera_3d: Camera3D = %Camera3D
@onready var hurtbox: HurtBox = %Hurtbox
@onready var weapon_node: WeaponNode = %WeaponNode
@onready var aim_target: RayCast3D = %AimTarget
@onready var flashlight: SpotLight3D = %Flashlight


@export_group("Combat")
@export var life: LifeResource
@export var right_hand: bool = true

## Position of the weapon node relative to the camera
@export var weapon_position: Vector3 = Vector3.ZERO


@export_group("Movement Sounds")

## How many meters of travel to play a footstep sound when walking
@export var footstep_frequency_walk: float = 0.62

## How many meters of travel to play a footstep sound when running
@export var footstep_frequency_run: float = 1.4

## The split between running and walking frequency to play running footsteps.
@export_range(0.0, 1.0, 0.01) var footstep_run_percent: float = 0.7

## Minimum vertical speed when landing to play a landing sound
@export_range(0.0, 2.0, 0.01, 'or_greater')
var land_sound_speed: float = 0.98


@export_group("Camera")

## Look speed input multiplier
@export_range(0.0001, 1.0, 0.0001, 'or_greater', 'radians_as_degrees')
var look_speed: float = deg_to_rad(0.5)

## FOV of the camera
@export_range(1.0, 179.0, 0.001, 'suffix:°')
var fov: float = 75.0


@export_subgroup("Smoothing", "camera_smooth")
## Enables camera smoothing
@export var camera_smooth_enabled: bool = true
## The target location for the camera. This is used as the endpoint for
## smoothing, and if smoothing must be performed. However, it is not used to
## reset interpolation duration, the position of the Player is used for that.
@export var camera_smooth_target_node: Node3D = null
## Maximum distance from the target node
@export var camera_smooth_max_distance: float = 0.45


@export_group("Aiming")

## Relative movement speed when aiming, scales top speed over time
@export_range(0.001, 1.0, 0.001)
var aim_move_speed: float = 0.3

## Target aiming speed
@export_range(0.0001, 1.0, 0.0001, 'or_greater', 'radians_as_degrees')
var look_aim_speed: float = deg_to_rad(0.25)

## Interpolation time when aiming
@export_range(0.001, 1.0, 0.001)
var look_aim_time: float = 0.28

## Interpolation time when leaving aim, should be a bit faster
@export_range(0.001, 1.0, 0.001)
var look_aim_return_time: float = 0.22

## Position of the weapon node when aiming, relative to the camera
@export var weapon_aim_position: Vector3 = Vector3.ZERO


@export_group("Controls")

@export_subgroup("First Person")

@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction
@export var fire_primary: GUIDEAction
@export var aim: GUIDEAction
@export var fan_hammer: GUIDEAction
@export var flashlight_action: GUIDEAction
@export var interact: GUIDEAction
@export var charge: GUIDEAction
@export var melee: GUIDEAction
@export var weapon_next: GUIDEAction
@export var weapon_previous: GUIDEAction
@export var reload: GUIDEAction
@export var unload: GUIDEAction
@export var switch_ammo: GUIDEAction

@export_subgroup("Vehicle")

## Input to accelerate the engine
@export var accelerate: GUIDEAction
## Input to accelerate in reverse only
@export var reverse: GUIDEAction
## Input for any vehicle direction, tank controls
@export var drive: GUIDEAction
## Toggle headlights
@export var headlights: GUIDEAction
## Blast horn
@export var horn: GUIDEAction
## Steer left and right, as if with a wheel
@export var steer: GUIDEAction
## Button to leave vehicle
@export var exit_vehicle: GUIDEAction
## Input to apply brakes
@export var brake: GUIDEAction
## Input to apply handbrake, typically locking rear wheels with high torque
@export var handbrake: GUIDEAction


var score: int = 0:
    set = set_score


var weapons: Dictionary = {}
var weapon_index: int = 0
var weapon_aim_offset: Vector3 = Vector3.ZERO
var weapon_aim_roll: float = 0.0
## FOV when aiming, set to the weapon's FOV value
var weapon_aim_fov: float = fov
## Look speed multiplier when aiming, set by the weapon
var weapon_aim_look_speed: float = 1.0

var ammo_bank: Dictionary = {}

## The vehicle currently controlled by the player
var current_vehicle: JoltVehicle = null
## The action which must be released to allow entering / exiting a vehicle
var _vehicle_enter_exit_action: GUIDEAction = null


## If we are aiming
var _aim_is_aiming: bool = false
## If we were trying to aim on the last tick
var _aim_was_triggered: bool = false
## Top speed interpolation, used for aiming
var _top_speed: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_OUT)
## FOV interpolation, used for aiming
var _fov: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
## Look speed interpolation, used for aiming
var _look_speed: Interpolation = Interpolation.new(0.0, Tween.TRANS_LINEAR)
## Camera roll interpolation, used for aiming
var _look_roll: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
## Weapon position interpolation, used for aiming
var _weapon_position: Interpolation = Interpolation.new(0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

## Transform containing recoil deltas
var _recoil_transform: Transform3D
## Transform containing look deltas
var _look_transform: Transform3D

## Camera smoothing duration
var _camera_smooth_duration: float = 0.0
## The elapsed smoothing time
var _camera_smooth_time: float = 0.0
## Computed position of the camera for smoothing
var _camera_smooth_position: Vector3
## Mutex for setting camera smoothing values
var _camera_smooth_lock: Mutex = Mutex.new()

## The last location of the smooth target node
var _camera_smooth_target_last_position: Vector3 = Vector3.ZERO
## The initial transform of the camera
var _camera_smooth_initial_position: Vector3
## Target position of the camera
var _camera_smooth_target_position: Vector3
## Predicted next positions of the camera target
var _camera_smooth_next_position_a: Vector3
var _camera_smooth_next_position_b: Vector3

## Jump can be activated
var _jump_ready: bool = true

## Melee can be activated
var _melee_ready: bool = true

## Fire can be activated
var _fire_ready: bool = true

## Disabled when mouse is not captured
var _handle_input: bool = true

## Ground travel accumulator for playing footstep sounds
var _footstep_accumulator: float = 0.0

## Fire may be buffered
var _fire_can_buffer: bool = true

## Timer for doing a full reload.
## Tap to full reload, hold for controlled reload.
var _weapon_reload_time: int


## Buffered input
var _last_input: GUIDEAction
var _last_input_timer: float = 0.0
const LAST_INPUT_TIME = 0.2

var _next_input: GUIDEAction
var _next_input_timer: float = 0.0
const GENERIC_INPUT_BUFFER_TIME = 0.8
const FIRE_INPUT_BUFFER_TIME = 0.13


## How long aim action must be triggered to actually aim, only for the revolver
## as fanning is two rapid aim inputs.
const REVOLVER_AIM_TIME = 0.075
var _revolver_aim_time: float = 0.0


func _ready() -> void:
    super._ready()

    ammo_bank.set('owner', get_rid())

    #if not Engine.is_editor_hint():
        #camera_smooth_enabled = randf() > 0.5

    if camera_smooth_enabled and not Engine.is_editor_hint():
        camera_3d.top_level = true
        _camera_smooth_initial_position = camera_smooth_target_node.global_position
        _camera_smooth_target_last_position = _camera_smooth_initial_position

    weapons = weapons.duplicate()

    weapon_node.position = weapon_position

    if Engine.is_editor_hint():
        return

    GlobalWorld.player = self

    collider = %collider
    movement_audio_player = %MovementSoundPlayer

    _fov.current = fov
    _look_roll.current = 0.0
    _look_speed.current = look_speed
    _top_speed.current = top_speed
    _weapon_position.current = weapon_position

    aim_target.add_exception(hurtbox)
    aim_target.add_exception(self)

    weapon_node.ammo_bank = ammo_bank
    weapon_node.weapon_updated.connect(update_weapon_hud)
    weapon_node.reload_complete.connect(on_reload_complete)

    connect_hurtboxes()
    life.died.connect(on_death)
    life.hurt.connect(on_hurt)
    life.check_health()

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        camera_3d.global_transform = camera_target.global_transform
        weapon_node.position = weapon_position
        return

    # If we could not fire the last frame, force a "trigger reset" for fire_primary
    if not _handle_input:
        _fire_ready = false

    _handle_input = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

    # Check vehicle enter/exit input is released first
    if (
            _vehicle_enter_exit_action
        and _vehicle_enter_exit_action.is_completed()
    ):
        _vehicle_enter_exit_action = null

    # Test interactions before everything else, so they appear to occur with
    # the frame the player sees right now
    if _handle_input and interact.is_triggered():
        var a_collider = aim_target.get_collider()
        if a_collider:
            interact_with(a_collider)

    if current_vehicle:
        update_vehicle(delta)
    else:
        update_first_person(delta)


func update_first_person_camera(delta: float) -> void:
    if not _look_roll.is_done:
        _look_roll.update(delta)

    if not _look_speed.is_done:
        _look_speed.update(delta)

    if not _fov.is_done:
        _fov.update(delta)

    camera_3d.fov = _fov.current

    if _handle_input:
        rotation.y -= look.value_axis_2d.x * _look_speed.current

    neck.rotation.z = _look_roll.current
    weapon_node.rotation.z = -_look_roll.current * 0.5

    if _handle_input:
        _look_transform = _look_transform.rotated_local(
                Vector3.RIGHT,
                -look.value_axis_2d.y * _look_speed.current
        )
        var look_euler: Vector3 = _look_transform.basis.get_euler()
        look_euler.x = clampf(look_euler.x, LOOK_DOWN_MAX, LOOK_UP_MAX)
        look_euler.z = _look_roll.current * 0.5
        look_euler.y = rotation.y
        _look_transform.basis = Basis.from_euler(look_euler)


    interpolate_camera_smooth(delta)
    _look_transform.origin = _camera_smooth_position

    # NOTE: this allows recoil to push the camera over max rotations, but
    #       I will accept this because it would be hard to intuitively remove
    camera_3d.transform = _look_transform
    camera_3d.transform *= _recoil_transform

func update_first_person(delta: float) -> void:

    if not _top_speed.is_done:
        _top_speed.update(delta)

    update_aiming(_handle_input && aim.is_triggered(), delta)

    var was_fanning: bool
    var revolver: RevolverWeaponScene = weapon_node._weapon_scene as RevolverWeaponScene
    if revolver:
        was_fanning = revolver.is_fanning

    # NOTE: Must be before camera update, so the weapon fires where it appears
    #       to point right now
    update_weapon_node(delta)

    if revolver:
        update_fanning(revolver, was_fanning)

    if not _weapon_position.is_done:
        _weapon_position.update(delta)

    # NOTE: set weapon position after update_fanning(), as we may need to start
    #       moving to a new position.
    weapon_node.position = _weapon_position.current

    # NOTE: Reload cancel uses this to track if it should ignore aim attempts
    #       if we were not already trying to aim
    _aim_was_triggered = _handle_input && aim.is_triggered()

    var move_length: float = move.value_axis_3d.length()

    if is_zero_approx(move_length):
        movement_direction = Vector3.ZERO
    else:
        movement_direction = basis * move.value_axis_3d.normalized()

    if jump.is_triggered() or jump.is_ongoing():
        if _jump_ready:
            do_jump()
    else:
        _jump_ready = true

    if _handle_input and flashlight_action.is_triggered():
        flashlight.visible = !flashlight.visible

    if _next_input_timer > 0.0:
        _next_input_timer -= delta
        if _next_input_timer < 0.0001:
            _next_input = null
            _next_input_timer = 0.0

    if _last_input_timer > 0.0:
        if _last_input.is_completed():
            _last_input_timer = 0.0
            _last_input = null
        else:
            _last_input_timer -= delta
            if _last_input_timer < 0.0001:
                _last_input = null
                _last_input_timer = 0.0

    update_first_person_camera(delta)

func update_vehicle(delta: float) -> void:
    if _handle_input and (not _vehicle_enter_exit_action) and exit_vehicle.is_triggered():
        global_position = current_vehicle.get_exit_position()
        _vehicle_enter_exit_action = interact
        show_self(true)

        current_vehicle = null

        GlobalWorld.world.on_exit_vehicle()
        return

    # Keep player body attached to the vehicle
    global_position = current_vehicle.global_position

    if accelerate.is_triggered():
        if current_vehicle is WheeledJoltVehicle:
            current_vehicle.forward(1)

    if reverse.is_triggered():
        if current_vehicle is WheeledJoltVehicle:
            current_vehicle.forward(-1)

    if steer.is_triggered():
        if current_vehicle is WheeledJoltVehicle:
            current_vehicle.steer(steer.value_axis_1d)

    if brake.is_triggered():
        if current_vehicle is WheeledJoltVehicle:
            current_vehicle.brake(1)

    if handbrake.is_triggered():
        if current_vehicle is WheeledJoltVehicle:
            current_vehicle.handbrake(1)

    update_vehicle_camera(delta)

func update_vehicle_camera(_delta: float) -> void:
    const follow_distance: float = 5.0

    # TODO: Create an arm to track distance and lock vertical look
    _look_transform.origin = Vector3.ZERO
    if _handle_input:
        _look_transform = _look_transform.rotated(
                Vector3.UP,
                -look.value_axis_2d.x * _look_speed.current
        )
        _look_transform = _look_transform.rotated_local(
                Vector3.RIGHT,
                -look.value_axis_2d.y * _look_speed.current
        )

    camera_3d.transform = _look_transform

    # Track backwards from forward to follow distance
    camera_3d.transform = camera_3d.transform.translated_local(Vector3.BACK * follow_distance)

    camera_3d.global_transform = current_vehicle.camera_target.global_transform * camera_3d.transform


func _physics_process(delta: float) -> void:

    if Engine.is_editor_hint():
        return

    # NOTE: Only process input in _process(), so we do not
    # miss inputs shorter than a physics frame.

    var initial_camera_position: Vector3 = camera_smooth_target_node.global_position

    var last_accel: Vector3 = acceleration
    update_movement(delta, _top_speed.current)

    if is_grounded():
        _footstep_accumulator += velocity.length() * delta

    if just_jumped:
        _jump_ready = false
        play_sound_jump()
        _footstep_accumulator = 0.0
    else:
        var target_aim_speed: float = top_speed * aim_move_speed
        var run_amount: float = clampf(
                (_top_speed.current - target_aim_speed) / (top_speed - target_aim_speed),
                0.0,
                1.0
        )
        var freq: float = lerpf(
                footstep_frequency_walk,
                footstep_frequency_run,
                run_amount
        )
        if _footstep_accumulator > freq:
            var is_running: bool = false
            if run_amount >= footstep_run_percent:
                is_running = true
            play_sound_footstep(is_running)
            _footstep_accumulator = 0.0
        elif just_landed:
            var down_speed_sqrd: float = (up_direction * last_velocity.dot(up_direction)).length_squared()
            if down_speed_sqrd >= (land_sound_speed * land_sound_speed):
                play_sound_land()
                _footstep_accumulator = 0.0

    if camera_smooth_enabled:
        if not camera_smooth_target_node.global_position.is_equal_approx(_camera_smooth_target_last_position):
            _camera_smooth_target_last_position = camera_smooth_target_node.global_position

            var jerk: Vector3 = acceleration - last_accel

            _camera_smooth_lock.lock()

            _camera_smooth_initial_position = initial_camera_position
            _camera_smooth_target_position = _camera_smooth_target_last_position
            _camera_smooth_next_position_a = _camera_smooth_target_position + (last_velocity + acceleration + jerk) * delta
            _camera_smooth_next_position_b = _camera_smooth_next_position_a + (last_velocity + (acceleration + jerk + jerk)) * delta

            _camera_smooth_time = 0.0
            _camera_smooth_duration = delta * 3

            _camera_smooth_lock.unlock()

        else:
            _camera_smooth_duration = 0.0

func get_camera() -> Camera3D:
    return camera_3d

func set_recoil_transform(recoil_transform: Transform3D) -> void:
    _recoil_transform = recoil_transform

func update_aiming(should_aim: bool, delta: float = 0.0) -> void:
    var aim_starting: bool = false
    var aim_ending: bool = false
    if should_aim and weapon_node.can_aim():
        if not _aim_is_aiming:
            # NOTE: Special revolver input, aiming is delayed, charges if not
            #       charged, and cancels fan hammer state.
            if weapon_node.weapon_type is RevolverWeapon:
                var revolver_scene: RevolverWeaponScene = weapon_node._weapon_scene as RevolverWeaponScene
                if revolver_scene and revolver_scene.is_fanning:
                    revolver_scene.is_fanning = false

                if is_zero_approx(_revolver_aim_time):
                    _revolver_aim_time = REVOLVER_AIM_TIME
                else:
                    _revolver_aim_time -= delta

                if _revolver_aim_time < 0.001:
                    aim_starting = true
                    _revolver_aim_time = 0.0

                    if weapon_node.weapon_type.can_charge():
                        weapon_node.charge()
            else:
                aim_starting = true

    elif _aim_is_aiming:
        aim_ending = true
        _revolver_aim_time = 0.0

    if aim_starting:
        _aim_is_aiming = true
        weapon_node.set_aiming(true)

        _fov.duration = look_aim_time
        _fov.set_target_delta(weapon_aim_fov, weapon_aim_fov - _fov.current)

        _look_speed.duration = look_aim_time
        var target_look_speed = (weapon_aim_fov / fov) * look_aim_speed * weapon_aim_look_speed
        _look_speed.set_target_delta(target_look_speed, target_look_speed - _look_speed.current)

        _top_speed.duration = look_aim_time
        var target_speed: float = top_speed * aim_move_speed
        _top_speed.set_target_delta(target_speed, target_speed - _top_speed.current)

        if weapon_index:
            _weapon_position.duration = look_aim_time
            _weapon_position.set_target_delta(weapon_aim_offset, weapon_aim_offset - _weapon_position.current)

            _look_roll.duration = look_aim_time
            _look_roll.set_target_delta(weapon_aim_roll, weapon_aim_roll - _look_roll.current)

    elif aim_ending:
        _aim_is_aiming = false
        weapon_node.set_aiming(false)

        _fov.duration = look_aim_return_time
        _fov.set_target_delta(fov, fov - _fov.current)

        _look_roll.duration = look_aim_return_time
        _look_roll.set_target_delta(0.0, -_look_roll.current)

        _look_speed.duration = look_aim_return_time
        _look_speed.set_target_delta(look_speed, look_speed - _look_speed.current)

        _top_speed.duration = look_aim_time
        _top_speed.set_target_delta(top_speed, top_speed - _top_speed.current)

        _weapon_position.duration = look_aim_return_time
        _weapon_position.set_target_delta(weapon_position, weapon_position - _weapon_position.current)

func update_fanning(revolver: RevolverWeaponScene, was_fanning: bool) -> void:
    if revolver.is_fanning and not revolver.can_fan():
        revolver.is_fanning = false
        weapon_node.set_aiming(false)
        _weapon_position.duration = look_aim_return_time
        _weapon_position.set_target_delta(weapon_position, weapon_position - _weapon_position.current)
    elif not was_fanning and revolver.is_fanning:
        weapon_node.set_aiming(true)
        _weapon_position.duration = look_aim_time
        var target_position: Vector3 = weapon_position + weapon_node.weapon_type.fan_offset
        _weapon_position.set_target_delta(target_position, target_position - _weapon_position.current)

func interpolate_camera_smooth(delta: float) -> void:
    if not camera_smooth_enabled:
        return

    _camera_smooth_lock.lock()

    if is_zero_approx(_camera_smooth_duration):
        _camera_smooth_position = _camera_smooth_target_position
        _camera_smooth_lock.unlock()
        return

    _camera_smooth_time = minf(_camera_smooth_time + delta, _camera_smooth_duration)

    var t: float = _camera_smooth_time / _camera_smooth_duration
    var t2: float = t * t
    var t3: float = t2 * t

    if is_equal_approx(_camera_smooth_time, _camera_smooth_duration):
        _camera_smooth_duration = 0.0

    _camera_smooth_position = (
            _camera_smooth_initial_position * (-t3 + 3.0 * t2 - 3.0 * t + 1.0)
            + _camera_smooth_target_position * (3.0 * t3 - 6.0 * t2 + 3.0 * t)
            + _camera_smooth_next_position_a * (-3.0 * t3 + 3.0 * t2)
            + _camera_smooth_next_position_b * (t3)
    )

    _camera_smooth_lock.unlock()

    #print('lag ' + str(camera_3d.global_position.distance_to(camera_smooth_target_node.global_position)))

func update_weapon_node(delta: float) -> void:
    if not weapon_index:
        return

    update_weapon_switch()

    weapon_node.set_walking(!_aim_is_aiming and !movement_direction.is_zero_approx())

    if _handle_input and switch_ammo.is_triggered():
        weapon_node.switch_ammo()

    if not _fire_ready and not fire_primary.is_triggered():
        _fire_ready = true

    var triggered: bool = _fire_ready && _handle_input && fire_primary.is_triggered()
    if triggered:
        update_last_input(fire_primary)
    else:
        _fire_can_buffer = _fire_ready && _handle_input

    var action: WeaponNode.Action = weapon_node.update_trigger(triggered, delta)

    if action == WeaponNode.Action.OKAY:
        _fire_can_buffer = false
        clear_input_buffer(fire_primary)
    else:
        if triggered:
            if _fire_can_buffer:
                # Use the longer buffer for reloading
                if weapon_node.continue_reload:
                    update_input_buffer(fire_primary)
                # NOTE: For the revolver only, use the longer buffer if we are charging.
                #       This happens when aiming auto-charges, which is longer than the buffer.
                elif weapon_node.weapon_type is RevolverWeapon and weapon_node._weapon_scene.is_state(WeaponScene.CHARGE):
                    update_input_buffer(fire_primary)
                else:
                    update_input_buffer(fire_primary, FIRE_INPUT_BUFFER_TIME)
        elif is_input_buffered(fire_primary):
            # NOTE: If the action was blocked, keep trying anyway
            #       because we may be waiting to charge/ reload
            action = weapon_node.update_trigger(true, 0.0)
            if action == WeaponNode.Action.OKAY:
                clear_input_buffer()

    # NOTE: do this after so we can change buffer times if we are reloading
    if triggered:
        weapon_node.continue_reload = false

    if _handle_input and melee.is_triggered():
        weapon_node.continue_reload = false
        update_last_input(melee)
        if _melee_ready or weapon_node.melee():
            # If a melee ever activates, clear the buffer
            if _next_input:
                clear_input_buffer()
            _melee_ready = false
    else:
        _melee_ready = true

    if _handle_input and fan_hammer.is_triggered():
        # NOTE: ignore this action unless we have a revolver
        if weapon_node.weapon_type is RevolverWeapon:
            weapon_node.continue_reload = false
            update_last_input(fan_hammer)

            var revolver_scene: RevolverWeaponScene = weapon_node._weapon_scene as RevolverWeaponScene
            if revolver_scene:
                var okay: bool = revolver_scene.goto_fan()
                if okay:

                    clear_input_buffer(fan_hammer)
                else:
                    update_input_buffer(fan_hammer)
    elif is_input_buffered(fan_hammer):
        var revolver_scene: RevolverWeaponScene = weapon_node._weapon_scene as RevolverWeaponScene
        if revolver_scene:
            var okay: bool = revolver_scene.goto_fan()
            if okay:
                clear_input_buffer()

    if _handle_input and charge.is_triggered():
        weapon_node.continue_reload = false
        update_last_input(charge)

        # NOTE: Even if the action is blocked, buffer anyway because we
        #       may be waiting to load a round
        action = weapon_node.charge()
        if action == WeaponNode.Action.OKAY:
            clear_input_buffer(charge)
        else:
            update_input_buffer(charge)
    elif is_input_buffered(charge):
        # NOTE: If the action was blocked, keep trying anyway
        #       because we way be waiting to reload
        action = weapon_node.charge()
        if action == WeaponNode.Action.OKAY:
            clear_input_buffer()
    # NOTE: We may have a fire buffered, but we have failed to shoot, so try
    #       charging the weapon in case we were waiting for that
    elif is_input_buffered(fire_primary):
        if weapon_node.weapon_type is RevolverWeapon:
            # NOTE: Revolver cannot be charged from a buffered trigger.
            #       This is because it charges as part of a longer fire animation
            pass
        else:
            if weapon_node.charge() == WeaponNode.Action.OKAY:
                # Requeue the primary fire action as buffer is too short normally
                update_input_buffer(fire_primary)

    if _handle_input and reload.is_triggered():
        var do_reload: bool = false
        if _weapon_reload_time == 0:
            # Cancel a full reload if we trigger while continue is on
            if weapon_node.continue_reload:
                weapon_node.continue_reload = false
                _weapon_reload_time = -1
                #print('cancel reload!')
            else:
                weapon_node.continue_reload = true
                _weapon_reload_time = Time.get_ticks_msec()
                do_reload = true
                #print('begin reload!')

        update_last_input(reload)

        if do_reload:
            # NOTE: Even if the action is blocked, buffer anyway because we
            #       may be waiting to cycle a round from reserve
            #print('please reload!')
            action = weapon_node.reload()
            if action == WeaponNode.Action.OKAY:
                clear_input_buffer(reload)
            else:
                update_input_buffer(reload)
        #else:
            #print('not gonna reload!')
    else:
        if _weapon_reload_time > 0:
            var elapsed: int = Time.get_ticks_msec() - _weapon_reload_time
            if elapsed > 500:
                weapon_node.continue_reload = false
            _weapon_reload_time = 0
        elif _weapon_reload_time == -1:
            _weapon_reload_time = 0

        if is_input_buffered(reload):
            action = weapon_node.reload()
            if action == WeaponNode.Action.OKAY:
                clear_input_buffer()

    if _handle_input and unload.is_triggered():
        weapon_node.continue_reload = false
        weapon_node.continue_unload = true
        weapon_node.unload()
    else:
        weapon_node.continue_unload = false

    # Stop reloads if we press the aim button for the first time
    if weapon_node.continue_reload and (_handle_input and aim.is_triggered()) and not _aim_was_triggered:
        weapon_node.continue_reload = false

func on_reload_complete() -> void:
    # If a reload ended and we wanted to continue, queue a charge
    if weapon_node.continue_reload:
        update_input_buffer(charge)
    # Don't buffer a reload off a reload
    elif _next_input == reload:
        clear_input_buffer()

func on_hurt(_from: Node3D, _part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    get_tree().call_group('hud', 'update_health', life.health / life.max_health)

func on_death() -> void:
    print('Gah! I died!')

    GlobalWorld.world.on_player_death()

func is_input_buffered(action: GUIDEAction) -> bool:
    if _next_input_timer < 0.0001:
        return false

    return action == _next_input

func clear_input_buffer(action: GUIDEAction = null) -> void:
    if action == null or _next_input == action:
        _next_input = null
        _next_input_timer = 0.0

func update_input_buffer(action: GUIDEAction, time: float = GENERIC_INPUT_BUFFER_TIME) -> void:
    if action == _last_input:
        # If we set the last input this frame, allow to buffer
        if is_equal_approx(_last_input_timer, LAST_INPUT_TIME):
            pass
        elif _last_input_timer > 0.0:
            return

    if _next_input == action:
        if _next_input_timer < 0.5:
            _next_input_timer = time
        return

    _next_input = action
    _next_input_timer = time

func update_last_input(action: GUIDEAction) -> void:
    if action == _last_input:
        if _last_input_timer < 0.0001:
            _last_input_timer = LAST_INPUT_TIME
        return

    _last_input = action
    _last_input_timer = LAST_INPUT_TIME

func update_weapon_switch() -> void:
    if not _handle_input:
        return

    var next_weapon_dir: int = 0
    if weapon_next.is_triggered():
        next_weapon_dir += 1
    if weapon_previous.is_triggered():
        next_weapon_dir -= 1

    if next_weapon_dir == 0:
        return

    var max_loop: int = 10
    var next_slot: int = weapon_index + next_weapon_dir

    while next_slot != weapon_index and max_loop > 0:
        max_loop -= 1

        if next_slot < 1:
            next_slot = 10
        elif next_slot > 10:
            next_slot = 1

        if weapons.has(next_slot):
            select_weapon(next_slot)
            return

        next_slot += next_weapon_dir

func select_weapon(slot: int) -> void:
    if not weapons.has(slot):
        push_warning('Cannot select weapon ' + str(slot) + '!')
        return

    if weapon_index == slot:
        return

    weapon_index = slot

    # If the current weapon had a queued input, clear when changing
    clear_input_buffer()

    var weapon: WeaponResource = weapons.get(slot) as WeaponResource
    weapon_node.weapon_type = weapon
    weapon_aim_fov = weapon.aim_camera_fov
    weapon_aim_look_speed = weapon.aim_camera_look_speed_scale

    get_tree().call_group('hud', 'set_crosshair_visible', weapon.crosshair_enabled)

    weapon_node.set_aiming(false)
    _aim_is_aiming = false
    _weapon_position.reset(weapon_position)
    weapon_aim_offset = weapon_aim_position + weapon.aim_offset
    weapon_aim_roll = -weapon.aim_camera_roll

    update_weapon_hud()

    # NOTE: Special behavior for scoped rifle, it needs our camera attributes
    var scoped_rifle: ScopeRifle = weapon_node._weapon_scene as ScopeRifle
    if scoped_rifle:
        var cam_attributes: CameraAttributes = camera_3d.attributes
        if not cam_attributes:
            # Use environment attributes
            cam_attributes = get_world_3d().camera_attributes
        scoped_rifle.apply_camera_attributes(cam_attributes)

func interact_with(object: Object) -> void:
    if object is JoltVehicle:
        if _vehicle_enter_exit_action:
            return

        current_vehicle = object
        _vehicle_enter_exit_action = exit_vehicle

        # Disable and hide self
        show_self(false)

        # Input house-keeping
        update_aiming(false)
        _top_speed.reset(top_speed)
        _fov.reset(fov)
        _look_roll.reset(0.0)
        _look_speed.reset(look_speed)

        GlobalWorld.world.on_enter_vehicle()

func set_score(value: int) -> void:
    if score == value:
        return

    score = value

    get_tree().call_group('hud', 'update_score', score)

func update_weapon_hud() -> void:
    get_tree().call_group('hud', 'update_weapon_hud', weapon_node.weapon_type)

func pickup_item(item: Pickup) -> void:
    if item.item_type is WeaponResource:
        var weapon: WeaponResource = item.item_type as WeaponResource
        if weapons.has(weapon.slot):
            print('Already have slot ' + str(weapon.slot))

            # Add loaded ammo to bank
            if item.item_count > 0:
                add_ammo(weapon.get_default_ammo(), item.item_count)

            return

        weapons[weapon.slot] = weapon
        print('Picked up ' + str(weapon.name) + '!')
        item.queue_free()

        # Weapon comes with ammo, preload it with first ammo type
        if item.item_count > 0:
            add_ammo(weapon.get_default_ammo(), item.item_count)


        if weapon_index == 0:
            # New and first weapon, pull it out
            select_weapon(weapon.slot)
        else:
            # New weapon with ammo, but not swapping, give our ammo bank
            weapon.ammo_bank = ammo_bank

        if item.item_count > 0:
            weapon.load_rounds(item.item_count, weapon.get_default_ammo().type)
            update_weapon_hud()

        # For the revolver, rotate to one after the highest live round index
        var revolver: RevolverWeapon = weapon as RevolverWeapon
        if revolver:
            revolver_spin_to_next(revolver)

    elif item.item_type is AmmoResource:
        var ammo: AmmoResource = item.item_type as AmmoResource

        add_ammo(ammo, item.item_count)

        # If holding a weapon with no ammo stock, get next ammo
        if weapon_index and not weapon_node.has_ammo_stock():
            # NOTE: this will update ammo on the hud if true
            if not weapon_node.switch_ammo():
                update_weapon_hud()
        else:
            update_weapon_hud()

        item.queue_free()

func add_ammo(ammo: AmmoResource, amount: int) -> void:
    if not ammo_bank.has(ammo.type):
        ammo_bank.set(ammo.type, {
            'amount': 0,
            'ammo': ammo
        })
    ammo_bank.get(ammo.type).amount += amount

func revolver_spin_to_next(revolver: RevolverWeapon) -> void:
    # Pick the shortest rotation, either in the negative direction or
    # positive direction.
    var pos: int = revolver._cylinder_position
    var found_forward: bool = false
    var found_backward: bool = false
    var forward: int = 0
    var backward: int = 0

    var i: int = 0
    # Clockwise, this position is empty and the next is live
    while i < 3:
        var current: int = posmod(pos + i, revolver.ammo_reserve_size)
        current = revolver._cylinder_ammo_state[current]
        var next: int = posmod(pos + i + 1, revolver.ammo_reserve_size)
        next = revolver._cylinder_ammo_state[next]
        if current == 0 and next > 0:
            # Already on a good spot, do not spin
            if i == 0:
                return
            found_forward = true
            forward = i
            break
        i += 1

    # Counter-clockwise, this position is live and the next is empty
    i = 0
    while i < 3:
        var current: int = posmod(pos - i, revolver.ammo_reserve_size)
        current = revolver._cylinder_ammo_state[current]
        var next: int = posmod(pos - i - 1, revolver.ammo_reserve_size)
        next = revolver._cylinder_ammo_state[next]
        if next == 0 and current > 0:
            found_backward = true
            backward = i + 1
            break
        i += 1

    # NOTE: either an empty or full revolver, no need to spin
    if not found_forward and not found_backward:
        return

    var spin: int
    if found_forward and found_backward:
        if forward < backward:
            spin = forward
        else:
            spin = -backward
    elif found_forward:
        spin = forward
    else:
        spin = -backward

    revolver.rotate_cylinder(spin)

func connect_hurtboxes() -> void:
    hurtbox.enable()
    life.connect_hurtbox(hurtbox)

    weapon_node.set_melee_excluded_hurboxes([hurtbox])

func show_self(yes: bool = true) -> void:
    if yes:
        visible = true
        collider.disabled = false
        weapon_node.process_mode = Node.PROCESS_MODE_INHERIT
        return

    visible = false
    collider.disabled = true
    weapon_node.process_mode = Node.PROCESS_MODE_DISABLED
