## Sees things
class_name BehaviorSenseVision extends BehaviorSense


const NAME = &"vision"

func name() -> StringName:
    return NAME


## Groups that can be seen
@export var target_groups: Array[StringName]

## Angular size of the cone field of view
@export_range(1.0, 180.0, 1.0, 'radians_as_degrees')
var fov: float = deg_to_rad(100.0):
    set(value):
        fov = value
        _fov_cos = cos(fov * 0.5)
var _fov_cos: float = cos(fov * 0.5)

## Range of vision, cannot see anything beyond this distance.
@export_range(0.0, 100.0, 0.01, "or_greater")
var vision_range: float = 50.0:
    set(value):
        vision_range = value
        _range_squared = vision_range * vision_range
var _range_squared: float = vision_range * vision_range

## Mask of physics layers that block vision
@export_flags_3d_physics var mask: int = 16


@export_subgroup("Debug", "debug")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var debug_enabled: bool = false

## Show vision cones on the character
@export var debug_show_cone: bool = false

## Show raycasts when testing vision
@export var debug_show_raycast: bool = false

## Show only raycasts that reach the target being tested
@export var debug_show_raycast_sight_only: bool = false

## Show sight points on the target being tested
@export var debug_show_sight_points: bool = false

## Color of vision cones
@export var debug_cone_color: Color = Color(0.95, 0.9, 0.9, 0.06)

## Color of raycasts that reach target sight points
@export var debug_raycast_sight_color: Color = Color(0.1, 0.7, 0.9, 0.7)

## Color of raycasts that are blocked
@export var debug_raycast_block_color: Color = Color(0.5, 0.1, 0.12, 0.6)

## Color of target sight points
@export var debug_sight_point_color: Color = Color(0.5, 0.1, 0.2, 0.4)


## Location to see from, relative to the character
var eye_pos: Vector3 = Vector3.ZERO

## Direction of the eye, relative to the character
var eye_dir: Vector3 = Vector3.MODEL_FRONT

## Cone of vision for debug view
var debug_cone: DebugCone = null

## Parent to put the debug vision cone
var debug_eye: Node3D = null


func sense(mind: BehaviorMind) -> void:
    _update_debug_vision_cone()

    var me: CharacterBase = mind.parent
    var targets: Array[Node] = GlobalWorld.get_nodes_in_groups(target_groups)

    for target in targets:
        var visual: PackedVector4Array
        if is_instance_of(target, CharacterBase):
            visual = test_vision_character(mind.parent, target)
        elif is_instance_of(target, Node3D):
            visual = test_vision_node(mind.parent, target)
            # TODO: no memory container can track this yet

        var avg: Vector4 = Vector4.ZERO
        var count: int = 0
        for r in visual:
            if r.w >= 0.0:
                avg += r
                count += 1

        if count == 0:
            continue

        avg /= float(count)
        var direction: Vector3 = Vector3(avg.x, avg.y, avg.z)
        var distance: float = avg.w

        # NOTE: test function will ensure the directions are non-zero length.
        #       HOWEVER, averaging could change them to zero, so handle that
        if direction.is_zero_approx():
            direction = eye_dir
        else:
            direction = direction.normalized()

        # Track memory
        if is_instance_of(target, CharacterBase):
            var chara: CharacterBase = target as CharacterBase
            var memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
            if not memory:
                memory = BehaviorMemorySensory.new()

            var event: PackedByteArray = memory.start_event(BehaviorMemorySensory.Type.SIGHT)

            memory.event_set_expire(event, 100)
            memory.event_set_tracking_node(event, target)
            memory.event_set_flag(event, BehaviorMemorySensory.Flag.TRACKING_TIMED)

            # NOTE: Write two timers, the second one is updated for goals
            memory.event_add_game_time(event); memory.event_add_game_time(event)

            memory.event_add_time_of_day(event)
            memory.event_add_location(event, me.global_position, me.global_basis.z)
            memory.event_add_travel(event, direction, distance)
            memory.event_add_node_path(event, chara.get_path())

            var char_travel_dir: Vector3 = chara.last_velocity
            if char_travel_dir.is_zero_approx():
                char_travel_dir = Vector3.ZERO
            else:
                char_travel_dir = char_travel_dir.normalized()
            memory.event_add_forward(event, char_travel_dir)

            memory.finish_event(event)

            mind.memory_bank.save_memory_reference(memory)
            activated = true


func _update_debug_vision_cone() -> void:
    if not debug_enabled or not debug_show_cone or not debug_eye:
        if debug_cone:
            debug_cone.queue_free()
            debug_cone = null
        return

    if not debug_cone:
        debug_cone = DebugCone.new(0.0, 0.0)

    debug_cone.set_color(debug_cone_color)
    debug_cone.set_fov(vision_range, fov)

    var parent: Node = debug_cone.get_parent()
    if not parent:
        debug_eye.add_child(debug_cone)
    elif parent != debug_eye:
        debug_cone.reparent(debug_eye, false)

## Raycasts from this character's eyes to the given character's vision points.
## Returns an array of distances to each vision point that hit, or negative value
## if the point is not visible.
func test_vision_character(me: CharacterBase, other: CharacterBase) -> PackedVector4Array:
    # NOTE: For development only, should be removed
    if not other:
        push_error("Cannot see a null character in test_vision! Investigate!")
        return []

    var size: int = other.sight_points.size()
    if size < 1:
        return []

    var results: PackedVector4Array
    results.resize(size)
    results.fill(Vector4(0, 0, 0, -1))

    if fov < 0.001 or vision_range < 0.001:
        return results

    var targets: PackedVector3Array = []
    targets.resize(size)
    if other.sight_points_no_depth:
        var view_t: Transform3D = other.global_transform.looking_at(me.global_position, other.global_basis.y, true)
        var i: int = 0
        for point in other.sight_points:
            targets[i] = (view_t * point.transform).origin
            i += 1
    else:
        var i: int = 0
        for point in other.sight_points:
            targets[i] = point.global_position
            i += 1
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    query.from = eye_pos
    query.collision_mask = mask
    query.exclude = [me.get_rid(), other.get_rid()]

    test_vision_targets(
            me,
            query,
            targets,
            results,
    )

    return results

func test_vision_node(me: CharacterBase, other: Node3D) -> PackedVector4Array:
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    query.from = eye_pos
    query.collision_mask = mask
    query.exclude = [me.get_rid()]

    var results: PackedVector4Array
    results.resize(1)
    results.fill(Vector4(0, 0, 0, -1))

    test_vision_targets(
            me,
            query,
            [other.global_position],
            results,
    )

    return results

func test_vision_targets(
        me: CharacterBase,
        query: PhysicsRayQueryParameters3D,
        targets: PackedVector3Array,
        results: PackedVector4Array,
) -> void:
    var space := me.get_world_3d().direct_space_state

    for i in range(targets.size()):
        var target: Vector3 = targets[i]
        var direction: Vector3 = target - eye_pos
        var distance: float = direction.length_squared()

        if debug_enabled and debug_show_sight_points and not debug_show_raycast_sight_only:
            DebugSphere.create_color(me, target, 0.5, 0.05, debug_sight_point_color)

        # Out of range
        if distance > _range_squared:
            continue

        # Check FOV angle
        distance = sqrt(distance)
        if not is_zero_approx(distance):
            direction /= distance
            var target_cos_theta: float = direction.dot(eye_dir)
            if target_cos_theta < _fov_cos:
                continue
            direction = target - me.global_position
        else:
            distance = 0.0
            direction = eye_dir

        query.to = target
        var hit: Dictionary = space.intersect_ray(query)

        # No hit means there is line of sight!
        if not hit:
            direction = direction.normalized()
            results[i] = Vector4(direction.x, direction.y, direction.z, distance)

            if debug_enabled:
                if debug_show_raycast:
                    DrawLine3d.DrawLine(query.from, query.to, debug_raycast_sight_color, 0.5)
                if debug_show_sight_points:
                    DebugSphere.create_color(me, query.to, 0.5, 0.08, debug_raycast_sight_color)
        elif debug_enabled and debug_show_raycast and not debug_show_raycast_sight_only:
            DrawLine3d.DrawLine(query.from, hit.position, debug_raycast_block_color, 0.5)
            DebugSphere.create_color(me, hit.position, 0.5, 0.05, debug_raycast_block_color)
