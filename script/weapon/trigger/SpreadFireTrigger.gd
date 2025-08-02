
## Spread shot trigger method, uses single fire mode but fires multiple bullets
class_name SpreadFireTrigger extends SingleFireTrigger


## How many bullets (rays) to fire
@export var bullets: int = 12

## Cone of spread for the bullets
@export_range(0.0, 180.0, 0.001, 'or_greater', 'radians_as_degrees')
var spread: float = PI / 18

@export_range(0.0, 1.0, 0.001)
var clustering: float = 0.25


func _do_raycasts(base: WeaponNode) -> void:

    var space: PhysicsDirectSpaceState3D = base.get_world_3d().direct_space_state
    var transform: Transform3D = base.weapon_tranform()
    var from: Vector3 = transform.origin

    #var max_y: float = 0.0
    #var avg_y: float = 0.0
    var total_hits: int = 0

    for i in range(bullets):
        var random_forward: Vector3 = transform.basis.z

        # Random scatter, pick 2 angles, add them to the forward, normalize
        if spread > 0.0:
            var rand_spread: float = randf_range(0.0, 1.0)
            if clustering < 1.0:
                rand_spread = lerp(sqrt(rand_spread), rand_spread, clustering)
            rand_spread *= spread
            #rand_spread = spread

            random_forward = random_forward.rotated(transform.basis.x, rand_spread)
            random_forward = random_forward.rotated(transform.basis.z, randf_range(0.0, TAU))

            #print('random: ' + str(random_forward))

        var to: Vector3 = transform.origin - random_forward * base.weapon_type.max_range
        var query := PhysicsRayQueryParameters3D.create(from, to, base.weapon_type.hit_mask)

        query.collide_with_areas = true
        query.collide_with_bodies = true

        var hit := space.intersect_ray(query)
        if hit:
            to = hit.position
            #var y_diff: float = abs(from.y - to.y)
            #avg_y += y_diff
            #if y_diff > max_y:
                #max_y = y_diff

        #DrawLine3d.DrawLine(from, to, Color(0.9, 0.15, 0.15, 0.2), 5)

        if not hit:
            continue

        if hit.collider is HurtBox:
            total_hits += 1
            var from_node: Node3D = base
            if base.controller:
                from_node = base.controller
            hit['from'] = from
            hit.collider.do_hit(from_node, hit, base.weapon_type.damage)

    #print('max y: ' + str(max_y))
    #print('avg y: ' + str(avg_y / bullets))
    #print('hits: ' + str(total_hits))
