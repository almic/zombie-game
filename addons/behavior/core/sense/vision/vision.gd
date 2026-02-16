## Sees things
class_name BehaviorSenseVision


const NAME = &"vision"


static func update(mind: BehaviorMind, settings: BehaviorSenseVisionSettings) -> void:
    if settings.fov_cos_half < 0.001:
        return

    if settings.vision_range < 0.001:
        return

    var eyes: Array[Node3D] = mind.agent.get_eyes()
    if eyes.size() == 0:
        return

    var targets: Array[Node] = GlobalWorld.get_nodes_in_groups(settings.target_groups)
    if targets.size() == 0:
        return

    var range_squared: float = settings.vision_range * settings.vision_range
    var space := mind.agent.get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    query.collision_mask = settings.mask
    for target in targets:
        # Skip nodes awaiting processing
        if mind.has_sense_event(NAME, target.get_path()):
            continue

        query.exclude = [mind.agent.get_rid(), target.get_rid()]

        var points: PackedVector3Array
        if target.has_method(&'get_sight_points'):
            var sight_points: Array[Node3D] = target.get_sight_points()
            var no_depth: bool = target.get(&'sight_points_no_depth') == true
            var size: int = sight_points.size()
            if size == 0:
                continue
            points.resize(size)

            if no_depth:
                var view_t: Transform3D = target.global_transform.looking_at(
                        mind.agent.global_position,
                        target.global_basis.y,
                        true
                )
                var i: int = 0
                while i < size:
                    points[i] = (view_t * sight_points[i].transform).origin
                    i += 1
            else:
                var i: int = 0
                while i < size:
                    points[i] = sight_points[i].global_position
                    i += 1

        elif is_instance_of(target, Node3D):
            points.resize(1)
            points[0] = target.global_position
        else:
            continue

        var num_points: int = points.size()

        for eye in eyes:
            var seen: bool = false
            query.from = eye.global_position

            var i: int = 0
            while i < num_points:

                query.to = points[i]
                i += 1
                var direction: Vector3 = query.to - query.from
                var distance_sq: float = direction.length_squared()

                # Out of range
                if distance_sq > range_squared:
                    continue

                # Check FOV angle
                if not is_zero_approx(distance_sq):
                    direction /= sqrt(distance_sq)
                    var target_cos_theta: float = direction.dot(eye.global_basis.z)
                    if target_cos_theta < settings.fov_cos_half:
                        continue
                    direction = target.global_position - mind.agent.global_position
                    distance_sq = direction.length_squared()
                else:
                    direction = mind.agent.global_basis.z

                var hit: Dictionary = space.intersect_ray(query)

                # A hit means NO line of sight!
                if hit:
                    continue

                seen = true

                # TODO: save memory
                var distance: float = 0.0
                if not is_zero_approx(distance_sq):
                    distance = sqrt(distance_sq)
                    direction /= distance
                print('I see %s! Direction %s, Distance %.2f' % [target.name, direction, distance])

                mind.add_sense_event(
                        NAME,
                        target.get_path(),
                        Vector4(direction.x, direction.y, direction.z, distance)
                )

                print(mind.sensory_events)

                break

            if seen:
                break
