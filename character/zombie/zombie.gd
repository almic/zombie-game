@tool

class_name Zombie extends CharacterBase


## NOTE: do not call any methods on nav_agent until mind processing is done!
##       many methods force a path update, which could cause bugs.
@onready var nav_agent: NavigationAgent3D = %NavigationAgent3D
@onready var animation_tree: AnimationTree = %AnimationTree
@onready var attack_hitbox: HitBox = %AttackHitbox
@onready var bone_simulator: PhysicalBoneSimulator3D = %BoneSimulator


## Body Region Hurtboxes
@onready var head: HurtBox = %head
@onready var body: HurtBox = %body
@onready var arm_l_1: HurtBox = %arm_l1
@onready var arm_l_2: HurtBox = %arm_l2
@onready var hand_l: HurtBox = %hand_l
@onready var arm_r_1: HurtBox = %arm_r1
@onready var arm_r_2: HurtBox = %arm_r2
@onready var hand_r: HurtBox = %hand_r
@onready var leg_l_1: HurtBox = %leg_l1
@onready var leg_l_2: HurtBox = %leg_l2
@onready var foot_l: HurtBox = %foot_l
@onready var leg_r_1: HurtBox = %leg_r1
@onready var leg_r_2: HurtBox = %leg_r2
@onready var foot_r: HurtBox = %foot_r


@export_group("Movement")

@export_range(0, 180.0, 0.1, 'radians_as_degrees')
var movement_direction_angle_max: float = deg_to_rad(20.0)

@export_subgroup("Turning", "rotate")

## Maximum rotation rate in radians/ second
@export_range(1, 180, 1, 'or_greater', 'radians_as_degrees', 'suffix:°/s')
var rotate_top_speed: float = deg_to_rad(15.0)

## Rotation acceleration in radians
@export_range(0.1, 30, 0.1, 'or_greater', 'radians_as_degrees', 'suffix:°/s²')
var rotate_acceleration: float = deg_to_rad(10.0)

## Rotation decceleration in radians
@export_range(0.1, 45, 0.1, 'or_greater', 'radians_as_degrees', 'suffix:°/s²')
var rotate_decceleration: float = deg_to_rad(20.0)

## Seconds to stop rotation if reaching top speed, rotation may stop
## sooner for shorter turns
@export_range(0.01, 2.0, 0.01, 'or_greater', 'suffix:sec')
var rotate_stop_time: float = 0.25


@export_group("Animation", "anim")

@export var anim_idle: StringName = &"idle"
@export var anim_attack: StringName = &"attack"
@export var anim_run: StringName = &"run"


@export_group("Combat")

## Health
@export var life: LifeResource

## How much damage to deal
@export var attack_damage: float = 0.0:
    set(value):
        attack_damage = value
        if is_node_ready():
            attack_hitbox.damage = attack_damage


@export_subgroup("Body Damage Multipliers", "mult")

## Damage received to head
@export var mult_head: float = 3.0
@export var mult_body: float = 1.0
@export var mult_arm: float = 0.35
@export var mult_leg: float = 0.5


@export_subgroup("Attacking", "attack")

## How close must the target be in order to attack, in meters
@export var attack_range: float = 1.24

## How nearly facing the target in order to attack, use cos() to get your desired value
@export var attack_facing: float = cos(deg_to_rad(7.0))


## Locomotion state machine, needed to check some state information
var anim_state_machine: AnimationNodeStateMachine
## Locomotion state machine playback
var locomotion: AnimationNodeStateMachinePlayback


## The last player who damaged the zombie
var last_player_damage: Player

## Most recent impacts from damage
var last_hits: Array[Dictionary] = []

## Movement target speed
var move_speed: float = top_speed

var sleep_min_travel: float = 0.001
var sleep_timeout: float = 0.5
var sleep_wakeup: float = 1.0

var _sleep_timeout_time: float = 0.0
var _sleep_wakeup_time: float = 0.0

## Track navigation status, without forcing a path update
var _is_nav_finished: bool = true

## Navigation direction to face when stationary while a nav is set
var _nav_direction: Vector3 = Vector3.ZERO

## Navigation completion function, called by NavigationAgent3D.navigation_finished()
var _nav_complete_func: Callable = Callable()

## Target look direction
## NOTE: when head turning is added, this would be limited when navigating or
##       attacking, otherwise zombie will at least turn the head to this direction
var _target_direction: Vector3 = Vector3.ZERO

## Direction to attack
var _attack_direction: Vector3 = Vector3.ZERO:
    set(value):
        _attack_direction = value
        _attack_direction_xz = _attack_direction
        _attack_direction_xz.y = 0
        if not _attack_direction_xz.is_zero_approx():
            _attack_direction_xz = _attack_direction_xz.normalized()

## Direction to attack excluding the y component
var _attack_direction_xz: Vector3

## Target to attack, used to check proximity before attacking
var _attack_target: Node3D = null

## Timer to check if zomie is trying to attack
var _attack_timer: float = 0


## The sign encodes the direction, - is clockwise, + is counter-clockwise
var _rotation_velocity: float = 0


func _ready() -> void:
    super._ready()

    # Animate in editor
    anim_state_machine = animation_tree.tree_root
    locomotion = animation_tree["parameters/playback"]
    locomotion.state_started.connect(_anim_started)
    locomotion.state_finished.connect(_anim_finished)
    locomotion.travel(anim_idle)

    if Engine.is_editor_hint():
        return

    collider = %collider
    movement_audio_player = %MovementSoundPlayer
    last_hits = last_hits.duplicate()
    life = life.duplicate(true)

    attack_hitbox.damage = attack_damage

    connect_hurtboxes()
    life.died.connect(on_death)
    life.hurt.connect(on_hurt)
    life.check_health()

    var vision: BehaviorSenseVision = mind.get_sense(BehaviorSenseVision.NAME)
    if vision:
        vision.on_sense.connect(func(_s): update_eyes())


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return

    pass


func _physics_process(delta: float) -> void:

    if Engine.is_editor_hint():
        return

    if _attack_timer > 0.0:
        _attack_timer -= delta

    if not life.is_alive:
        return

    mind.update(delta)

    # NOTE: move based on currently seen rotation, otherwise it looks like they
    #       move at a sharper angle than they should be
    do_pathing(delta)
    do_turning(delta)

    do_attacking()


func do_pathing(delta: float) -> void:

    if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
        return

    movement_direction = Vector3.ZERO

    # Only path on ground
    if not is_grounded():
        update_movement(delta, move_speed)
        return

    # dont move if attacking
    if _is_attacking():
        update_movement(delta, 0)
        return

    _is_nav_finished = nav_agent.is_navigation_finished()
    if not _is_nav_finished:
        var next_pos: Vector3 = nav_agent.get_next_path_position()
        movement_direction = global_position.direction_to(next_pos)
        movement_direction.y = 0
        if not movement_direction.is_zero_approx():
            movement_direction = movement_direction.normalized()
        _nav_direction = movement_direction

    var speed: float = move_speed
    # Compute real speed and direction
    if not movement_direction.is_zero_approx():
        # Modify speed based on desired travel direction and current direction
        var forward: Vector3 = global_basis.z
        var cos_theta: float = forward.dot(movement_direction)
        var speed_mult = (cos_theta + 1) * 0.5
        speed_mult *= speed_mult
        speed *= speed_mult

        # Limit travel direction to X degrees from current direction
        if is_zero_approx(movement_direction_angle_max):
            movement_direction = forward
        else:
            var vec_angle: float = acos(cos_theta)
            if vec_angle > movement_direction_angle_max:
                var rot_axis: Vector3 = forward.cross(movement_direction)
                if not rot_axis.is_zero_approx():
                    rot_axis = rot_axis.normalized()
                    movement_direction = forward.rotated(rot_axis, movement_direction_angle_max)

    update_movement(delta, speed)

    if not _is_nav_finished:
        # Could finish on this update
        _is_nav_finished = nav_agent.is_navigation_finished()

    # Play appropriate animation for current movement
    speed = velocity.length_squared()
    if is_zero_approx(speed):
        anim_goto(locomotion, anim_idle)
    else:
        speed = sqrt(speed)

        if speed >= 0.5:
            anim_goto(locomotion, anim_run)
        else:
            # Return to idle when too slow
            anim_goto(locomotion, anim_idle)

func do_turning(delta: float) -> void:
    # Do not spin in air
    if not is_grounded():
        return

    # If attacking, dont rotate
    if _is_attacking():
        return

    var direction: Vector3 = Vector3.ZERO

    # Prioritize facing the attack direction
    if not _attack_direction.is_zero_approx():
        direction = _attack_direction_xz
    # Face in the direction of where we would like to travel
    elif not _is_nav_finished:
        direction = _nav_direction
    elif not _target_direction.is_zero_approx():
        if is_zero_approx(_target_direction.dot(global_basis.z)):
            _target_direction = Vector3.ZERO
        else:
            direction = _target_direction
    # Maintain current direction
    else:
        return

    update_rotation(delta, direction)

func do_attacking() -> void:
    if not _attack_target:
        return

    if _attack_timer > 0.0:
        return

    # Probably a bad sign if target wasn't null, but whatever i think
    if _attack_direction.is_zero_approx():
        _attack_direction = Vector3.ZERO
        _attack_target = null

    var direction: Vector3 = _attack_direction_xz
    var facing: float = direction.dot(global_basis.z)
    if facing >= attack_facing:
        var distance: float = global_position.distance_squared_to(_attack_target.global_position)
        _attack_direction = Vector3.ZERO
        _attack_target = null
        if distance > (attack_range * attack_range):
            return

        _attack_timer = 1.0
        anim_goto(locomotion, anim_attack)


func _handle_action(action: BehaviorAction) -> bool:
    if action is BehaviorActionNavigate:
        act_navigate(action)
        return true

    if action is BehaviorActionAttack:
        act_attack(action)
        return true

    if action is BehaviorActionSpeed:
        move_speed = clampf(action.speed, 0.0, top_speed)
        return true

    if action is BehaviorActionTurn:
        _target_direction = global_basis.z.rotated(Vector3.UP, action.turn)
        return true

    return false

func act_navigate(navigate: BehaviorActionNavigate) -> void:
    if _nav_complete_func and nav_agent.navigation_finished.is_connected(_nav_complete_func):
        nav_agent.navigation_finished.disconnect(_nav_complete_func)
        _nav_complete_func = Callable()

    var next_target: Vector3 = navigate.get_global_position(self)
    var target_distance: float = nav_agent.target_desired_distance
    if not is_equal_approx(target_distance, navigate.target_distance):
        nav_agent.target_desired_distance = navigate.target_distance

    target_distance = navigate.target_distance * navigate.target_distance

    if (
                _is_nav_finished
            and global_position.distance_squared_to(next_target) < target_distance
    ):
        if navigate.can_complete():
            navigate.complete()
    else:
        nav_agent.target_position = next_target
        _nav_complete_func = navigate.complete

        # GlobalWorld.print('target nav: ' + str(navigate.direction))
        _is_nav_finished = false
        nav_agent.navigation_finished.connect(_nav_complete_func, CONNECT_ONE_SHOT)

func act_attack(attack: BehaviorActionAttack) -> void:
    # Check if the target is close enough to face
    var diff: Vector3 = attack.target.global_position - global_position
    var dist: float = diff.length_squared()

    if dist > attack_range * attack_range:
        return

    _attack_direction = diff / sqrt(dist)
    _attack_target = attack.target


## Helper to test animation state for attacks
func _is_attacking() -> bool:
    return _attack_timer > 0.0

func on_attack_start() -> void:
    attack_hitbox.enable()

func on_attack_end() -> void:
    attack_hitbox.disable()

func on_footstep(is_right: bool) -> void:
    if is_right:
        movement_audio_player.reparent(foot_r, false)
    else:
        movement_audio_player.reparent(foot_l, false)

    play_sound_footstep()


func update_movement(delta: float, speed: float = top_speed) -> void:

    if _sleep_wakeup_time > 0.0:
        _sleep_wakeup_time -= delta
        return

    super.update_movement(delta, speed)

    # NOTE: PERFORMANCE CRITICAL! TEST ANY CHANGES!
    if not movement_direction.is_zero_approx() and velocity.length_squared() < sleep_min_travel:
        if _sleep_timeout_time > sleep_timeout:
            _sleep_wakeup_time = sleep_wakeup
        else:
            _sleep_timeout_time += delta
    else:
        _sleep_timeout_time = 0.0


## Rotates to face a given direction. Returns `true` when reaching the direction.
func update_rotation(delta: float, direction: Vector3) -> void:
    # No requested direction, maintain current direction
    if direction.is_zero_approx():
        _rotation_velocity = 0
        return

    # NOTE: for development, should be removed later
    if not direction.is_normalized() or not is_zero_approx(direction.y):
        push_warning('Called update_rotation on zombie with a non-normalized direction, or a direction with a y component! Investigate!')
        return

    # Nearly facing the right direction
    if is_equal_approx(basis.z.dot(direction), 1):
        if is_zero_approx(_rotation_velocity):
            return

        _rotation_velocity = 0
        rotate_y(direction.signed_angle_to(basis.z, -Vector3.UP))
        return

    # Turn to face current direction of motion
    var rads_to_go: float = direction.signed_angle_to(basis.z, -Vector3.UP)
    var rate: float = 0
    if is_zero_approx(_rotation_velocity):
        # Simply accelerate
        rate = rotate_acceleration
    elif not is_equal_approx(signf(rads_to_go), signf(_rotation_velocity)):
        # Turning the wrong way, use decceleration speed
        rate = rotate_decceleration
    else:
        # 1. Can we start deccelerating now and still reach the target, and
        # 2. if we did, will we reach it in no more than "stop" seconds?
        var time: float = absf(_rotation_velocity) / rotate_decceleration
        var time_needed: float = 2 * rads_to_go / _rotation_velocity * delta

        if time >= time_needed and time_needed <= rotate_stop_time:
            # start slowing down
            rate = -rotate_decceleration
        else:
            rate = rotate_acceleration

    # Accelerate to top speed
    _rotation_velocity = clampf(
        _rotation_velocity + rate * delta * signf(rads_to_go),
        -rotate_top_speed, rotate_top_speed
    )

    rotate_y(_rotation_velocity)


func anim_goto(
        state_machine: AnimationNodeStateMachinePlayback,
        state: String,
        reset: bool = false
) -> void:
    if not reset and state_machine.get_current_node() == state:
        return

    state_machine.travel(state, reset)

func _anim_started(state: StringName) -> void:
    if state == anim_attack:
        _attack_timer = 1.0
    else:
        var path: Array[StringName] = locomotion.get_travel_path()
        if not path.is_empty() and path.back() == anim_attack:
            _attack_timer = 1.0

func _anim_finished(state: StringName) -> void:
    if state == anim_attack:
        _attack_timer = 0.0


func connect_hurtboxes() -> void:
    life.add_hitbox_exception(attack_hitbox)
    life.add_group_exception('zombie')

    life.connect_hurtbox(head, mult_head)
    life.connect_hurtbox(body, mult_body)

    for arm_part in [
        arm_l_1, arm_l_2, hand_l,
        arm_r_1, arm_r_2, hand_r
    ]:
        life.connect_hurtbox(arm_part, mult_arm)

    for leg_part in [
        leg_l_1, leg_l_2, foot_l,
        leg_r_1, leg_r_2, foot_r
    ]:
        life.connect_hurtbox(leg_part, mult_leg)

    life.enable_hurtboxes()


func get_hurtboxes() -> Array[HurtBox]:
    return [
        head, body,
        arm_l_1, arm_l_2, hand_l,
        arm_r_1, arm_r_2, hand_r,
        leg_l_1, leg_l_2, foot_l,
        leg_r_1, leg_r_2, foot_r
    ]


func on_death() -> void:
    if last_player_damage:
        last_player_damage.score += 100

    #print("RAHH I DIE!")
    ragdoll()

    var frame: int = Engine.get_physics_frames()
    var physics_delta: float = get_physics_process_delta_time()
    var delta: float
    for hit in last_hits:
        delta = (frame - hit.time) * physics_delta

        # Impact too long ago
        if delta > 0.25:
            break

        # Power calculation, continue in case an older hit has more power
        var power: float = lerpf(hit.hit.power, 0, delta / 0.25)
        if power <= 0.001:
            continue

        var impulse: Vector3 = hit.hit.direction * power

        do_part_impulse(hit.part, impulse, hit.hit.position)

    get_tree().create_timer(10.0).timeout.connect(queue_free)


func on_hurt(from: Node3D, part: HurtBox, damage: float, hit: Dictionary) -> void:
    # Only apply impulses after death
    if not life.is_alive:
        if bone_simulator.is_simulating_physics():
            if hit.has('hitbox'):
                pass
            else:
                do_part_impulse(part, hit.direction * hit.power, hit.position)
        else:
            # This shot killed us, must save to hit list
            _insert_hit_list(part, damage, hit)
        return

    var player: Player = from as Player
    if not player:
        return

    last_player_damage = from

    if part == head:
        last_player_damage.score += 25
    else:
        last_player_damage.score += 10

    _insert_hit_list(part, damage, hit)

func _insert_hit_list(part: HurtBox, damage: float, hit: Dictionary) -> void:
    # TODO: this could probably be better
    last_hits.insert(0, {
        'part': part,
        'damage': damage,
        'hit': hit,
        'time': Engine.get_physics_frames()
    })

    last_hits = last_hits.slice(0, 10)

func do_part_impulse(part: HurtBox, impulse: Vector3, point: Vector3) -> void:

    var bone_attachment: BoneAttachment3D = part.get_parent() as BoneAttachment3D
    if not bone_attachment:
        push_warning('Zombie has a bad hurtbox! Parent is not a bone attachment!')
        return

    point -= bone_attachment.global_position

    # TODO: this is super bad, make it faster. Needs a map?
    for child in bone_simulator.get_children():
        var bone: PhysicalBone3D = child as PhysicalBone3D
        if not bone:
            continue

        if bone.get_bone_id() != bone_attachment.bone_idx:
            continue

        bone.apply_impulse(impulse, point)
        break

func is_alive() -> bool:
    return life.is_alive

static func get_animation_bone_transform(animation: Animation, bone_name: String, time: float, back: bool = false) -> Transform3D:
    var track_id_pos: int = animation.find_track('Skeleton3D:' + bone_name, Animation.TYPE_POSITION_3D)
    var track_id_rot: int = animation.find_track('Skeleton3D:' + bone_name, Animation.TYPE_ROTATION_3D)

    var bone_pos: Vector3
    var bone_quat: Quaternion

    if track_id_pos == -1:
        bone_pos = Vector3.ZERO
    else:
        bone_pos = animation.position_track_interpolate(track_id_pos, time, back)

    if track_id_rot == -1:
        bone_quat = Quaternion()
    else:
        bone_quat = animation.rotation_track_interpolate(track_id_rot, time, back)

    return Transform3D(Basis(bone_quat), bone_pos)


# Activates ragdoll and applies small impulses to match the animation
func ragdoll() -> void:

    var skeleton: Skeleton3D = bone_simulator.get_skeleton()
    var bone_list: Array[PhysicalBone3D]
    bone_list.assign(bone_simulator.get_children().filter(func (node): return node is PhysicalBone3D))

    # The current node, and the fade_from node, animations
    var current_node: AnimationNodeAnimation = anim_state_machine.get_node(locomotion.get_current_node())
    var current_animation: Animation = animation_tree.get_animation(current_node.animation)

    var delta: float = get_physics_process_delta_time()
    var c_time: float = locomotion.get_current_play_position()
    var l_time: float = c_time - delta
    if l_time < 0.0:
        l_time += current_animation.length

    # Get every bone's current and last position, in local space
    var bone_transforms: Dictionary = {}
    for bone in bone_list:
        var bone_id: int = bone.get_bone_id()
        var bone_name: String = skeleton.get_bone_name(bone_id)

        if bone_transforms.has(bone_name):
            bone_transforms[bone_name].physical = true
            continue

        var current: Transform3D = get_animation_bone_transform(current_animation, bone_name, c_time)
        var last: Transform3D = get_animation_bone_transform(current_animation, bone_name, l_time, true)

        var child_name: String = skeleton.get_bone_name(skeleton.get_bone_children(bone_id)[0])
        var child: Transform3D = get_animation_bone_transform(current_animation, child_name, c_time)

        bone_transforms[bone_name] = {
            'id': bone_id,
            'current': current,
            'last': last,
            'size': child.origin,
            'physical': true
        }

        # Collect parents, in case some of them do not have a physical bone
        bone_id = skeleton.get_bone_parent(bone_id)
        while bone_id >= 0:
            bone_name = skeleton.get_bone_name(bone_id)

            # Already got this one and its parents, done
            if bone_transforms.has(bone_name):
                break

            current = get_animation_bone_transform(current_animation, bone_name, c_time)
            last = get_animation_bone_transform(current_animation, bone_name, l_time, true)

            child_name = skeleton.get_bone_name(skeleton.get_bone_children(bone_id)[0])
            child = get_animation_bone_transform(current_animation, child_name, c_time)

            bone_transforms[bone_name] = {
                'id': bone_id,
                'current': current,
                'last': last,
                'size': child.origin
            }
            bone_id = skeleton.get_bone_parent(bone_id)

    # Convert to global transforms, same as Godot does it
    var bone_chain: Array[String]
    var global_c_pose: Transform3D
    var global_l_pose: Transform3D
    for bone in bone_transforms:
        bone_chain.clear()
        global_c_pose = Transform3D.IDENTITY
        global_l_pose = Transform3D.IDENTITY

        var bone_id: int = bone_transforms[bone].id

        while bone_id >= 0:
            # Can stop when we reach a calculated bone
            var bone_name: String = skeleton.get_bone_name(bone_id)
            if bone_transforms[bone_name].has('calculated'):
                global_c_pose = bone_transforms[bone_name].current
                global_l_pose = bone_transforms[bone_name].last
                break
            bone_chain.append(bone_name)
            bone_id = skeleton.get_bone_parent(bone_id)

        if bone_chain.size() == 0:
            continue

        # Go backwards through the list, applying transforms
        for bone_chain_index in range(bone_chain.size() - 1, -1, -1):
            var bone_name: String = bone_chain[bone_chain_index]
            global_c_pose *= bone_transforms[bone_name].current
            global_l_pose *= bone_transforms[bone_name].last
            bone_transforms[bone_name].current = global_c_pose
            bone_transforms[bone_name].last = global_l_pose
            bone_transforms[bone_name].calculated = true

    # Get velocities here, stored as IDs for quicker lookup
    var bone_velocities: Dictionary = {}
    for bone in bone_transforms:
        # Skip bones that aren't physical
        if not bone_transforms[bone].has('physical'):
            continue

        var current_transform: Transform3D = bone_transforms[bone].current
        var last_transform: Transform3D = bone_transforms[bone].last

        # Linear displacement
        var pos_diff: Vector3 = current_transform.origin - last_transform.origin

        # Angular impulse calculation. The rotations are applied as impulses to
        # the end of the bones, giving accurate spins as opposed to angular
        # velocities which are applied to the middle of the shape.
        var current_quat: Quaternion = current_transform.basis.get_rotation_quaternion()
        var last_quat: Quaternion = last_transform.basis.get_rotation_quaternion()
        var quat_diff: Quaternion = current_quat * last_quat.inverse()

        var bone_size: Vector3 = bone_transforms[bone].size
        var angular_displacement: Vector3 = quat_diff * bone_size
        # Get vector perpendicular to the bone for the impulse direction
        var impulse_dir: Vector3 = bone_size.cross(angular_displacement)
        if not impulse_dir.is_zero_approx():
            impulse_dir = impulse_dir.cross(bone_size).normalized()
        angular_displacement -= bone_size

        var bone_id: int = bone_transforms[bone].id
        bone_velocities[bone_id] = {
            'linear': pos_diff / delta,
            'impulse_position': bone_size,
            'impulse': impulse_dir * angular_displacement / delta
        }

    collider.disabled = true
    animation_tree.active = false
    bone_simulator.active = true
    bone_simulator.physical_bones_start_simulation()

    # Apply impulses here
    for bone in bone_list:
        var velocities: Dictionary = bone_velocities[bone.get_bone_id()]
        bone.linear_velocity = 1.0 * velocities.linear + velocity
        bone.apply_impulse(1.0 * velocities.impulse, velocities.impulse_position)
