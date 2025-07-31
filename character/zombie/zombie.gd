@tool

class_name Zombie extends CharacterBase

@onready var navigation: NavigationAgent3D = %NavigationAgent3D
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


@export_subgroup("Turning", "rotate")
## Maximum rotation rate in radians/ second
@export var rotate_top_speed: float = TAU
## Rotation acceleration in radians
@export var rotate_acceleration: float = PI / 8
## Rotation decceleration in radians
@export var rotate_decceleration: float = PI / 4
## Seconds to stop rotation if reaching top speed, rotation may stop
## sooner for shorter turns
@export var rotate_stop_time: float = 2
## How close to target to face them regardless of velocity
@export var rotate_face_target_distance: float = 1

## The sign encodes the direction, - is clockwise, + is counter-clockwise
var _rotation_velocity: float = 0

@export_group("Target Detection", "target")
## How far to be aware of potential targets
@export var target_search_radius: float = 50

## Target groups to search for
@export var target_search_groups: Array[String]
var _active_target: Node3D = null

## Deviation for randomized target updates, important for performance of many agents
## Randomization is always clamped to the relevant update rate
@export var target_update_deviation: float = 0.2

## How long it takes to search for a new target
@export var target_search_rate: float = 3
var _target_search_accumulator: float = randfn(0.0, 0.2)

## How often to update target location, influences rotation
@export var target_update_rate: float = 1
var _target_update_accumulator: float = randfn(0.0, 0.2)

## If a target's updated position deviates this far, recalculate pathing
@export var target_update_distance: float = 0.5

## Switch for simple chase while waiting for pathing update
var _simple_move: bool = false

@export_group("Animation", "anim")

@export var anim_idle: String = "idle"
@export var anim_attack: String = "attack"
@export var anim_run: String = "run"

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

## How close must the target be in order to attack
@export var attack_range: float = 1.24
## How nearly facing the target in order to attack, use cos() to get your desired value
@export var attack_facing: float = 0.996

## Locomotion state machine
var locomotion: AnimationNodeStateMachinePlayback

## The last player who damaged the zombie
var last_player_damage: Player

func _ready() -> void:
    # Animate in editor
    locomotion = animation_tree["parameters/Locomotion/playback"]
    locomotion.travel(anim_idle)

    if Engine.is_editor_hint():
        return

    attack_hitbox.damage = attack_damage

    target_search_groups = target_search_groups.duplicate()

    connect_hurtboxes()
    life.died.connect(on_death)
    life.hurt.connect(on_hurt)
    life.check_health()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return

    pass

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if not life.is_alive:
        return

    if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) == 0:
        return

    movement_direction = Vector3.ZERO

    # Only path on ground
    if not is_grounded():
        # Do not spin in air
        # update_rotation()
        update_movement(delta)
        return

    update_target_position(delta)

    if _active_target == null:
        anim_goto(locomotion, anim_idle)
        update_movement(delta)
        return

    # dont move if attacking
    if locomotion.get_current_node() == anim_attack:
        movement_direction = Vector3.ZERO
    elif _simple_move:
        movement_direction = get_simple_move_direction()
    elif not navigation.is_navigation_finished():
        var next_pos: Vector3 = navigation.get_next_path_position()
        movement_direction = global_position.direction_to(next_pos)
    else:
        _simple_move = true
        movement_direction = get_simple_move_direction()

    update_movement(delta)

    if is_zero_approx(movement_direction.length_squared()):
        # If attacking, dont rotate and queue back to idle
        if locomotion.get_current_node() == anim_attack:
            anim_goto(locomotion, anim_idle)
        else:
            # Check if me are close enough to attack and facing the right way
            var target_dist_sqr: float = global_position.distance_squared_to(_active_target.global_position)
            var target_facing: float = basis.z.dot(global_position.direction_to(_active_target.global_position))
            if target_dist_sqr <= attack_range ** 2 and target_facing >= attack_facing:
                anim_goto(locomotion, anim_attack)
            else:
                update_rotation(delta)
        return

    update_rotation(delta)

    var speed: float = velocity.length_squared()
    if is_zero_approx(speed):
        anim_goto(locomotion, anim_idle)
    else:
        speed = sqrt(speed)

        if speed >= 0.5:
            anim_goto(locomotion, anim_run)
        else:
            # Return to idle when too slow
            anim_goto(locomotion, anim_idle)


func on_attack_start() -> void:
    attack_hitbox.enable()

func on_attack_end() -> void:
    attack_hitbox.disable()

func update_rotation(delta: float) -> void:
    var direction: Vector3 = Vector3(velocity.x, 0, velocity.z)
    var stationary: float = direction.length_squared() < 0.5

    # When (nearly) stationary, or close to target, try to face the target
    if stationary or (_active_target and \
         global_position.distance_squared_to(
        _active_target.global_position) <= rotate_face_target_distance ** 2
    ):
        if not _active_target:
            return

        direction = Vector3(
                global_position.x,
                0,
                global_position.z
            ).direction_to(Vector3(
                _active_target.global_position.x,
                0,
                _active_target.global_position.z
            ))
    else:
        direction = direction.normalized()

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

func get_simple_move_direction() -> Vector3:
    var dist: float = global_position.distance_squared_to(_active_target.global_position)
    var desired_squared: float = navigation.target_desired_distance ** 2
    if dist > desired_squared:
        return global_position.direction_to(_active_target.global_position)
    return Vector3.ZERO

func update_target_position(delta: float) -> void:
    if _active_target != null:
        # check to update target position
        if _target_update_accumulator < target_update_rate:
            _target_update_accumulator += delta
            return

        var deviation: float = _active_target.global_position.distance_squared_to(
            navigation.target_position
        )

        if deviation > target_update_distance:
            navigation.target_position = _active_target.global_position
            _simple_move = false

        _target_update_accumulator = randomize_accumulator(
            target_update_rate
        ) + delta

        return

    if _target_search_accumulator > target_search_rate:
        # reset accumulator
        _target_search_accumulator = randomize_accumulator(target_search_rate)

        # we assume there are few enough potential targets that iterating
        # them all is okay
        var targets: Array[Node3D] = []
        var scene_tree: SceneTree = get_tree()
        for group in target_search_groups:
            var nodes: Array[Node] = scene_tree.get_nodes_in_group(group)
            for node in nodes:
                if node is not Node3D:
                    continue

                if node not in targets:
                    targets.append(node)

        # make closest option the target
        var closest: Node3D = null
        var closest_dist: float = INF
        for target in targets:
            var dist: float = global_position.distance_squared_to(
                target.global_position
            )

            if dist < closest_dist:
                closest = target
                closest_dist = dist

        if closest != null:
            _active_target = closest
            navigation.target_position = _active_target.global_position
            _simple_move = false
            return

    _target_search_accumulator += delta

func randomize_accumulator(range_max: float) -> float:
    return clamp(
        randfn(0.0, target_update_deviation),
        -range_max, range_max
    )

func anim_goto(
        state_machine: AnimationNodeStateMachinePlayback,
        state: String,
        reset: bool = false
) -> void:
    if not reset and state_machine.get_current_node() == state:
        return

    state_machine.travel(state, reset)

func connect_hurtboxes() -> void:
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

func on_death() -> void:
    if last_player_damage:
        last_player_damage.score += 100

    #print("RAHH I DIE!")
    collider.disabled = true
    animation_tree.active = false
    bone_simulator.active = true
    #bone_simulator.process_mode = Node.PROCESS_MODE_PAUSABLE
    bone_simulator.physical_bones_start_simulation()
    #process_mode = Node.PROCESS_MODE_DISABLED
    get_tree().create_timer(10.0).timeout.connect(queue_free)

func on_hurt(from: Node3D, part: HurtBox, _damage: float, _hit: Dictionary) -> void:
    var player: Player = from as Player
    if not player:
        return

    last_player_damage = from

    if life.is_alive:
        if part == head:
            last_player_damage.score += 25
        else:
            last_player_damage.score += 10

func is_alive() -> bool:
    return life.is_alive
