# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Class that does collision detection between wheels and ground
class_name VehicleCollisionTester


var body_excludes: Array[RID]
var collision_mask: int


func _init(exclude: Array[RID], layer: int) -> void:
    body_excludes = exclude.duplicate()
    collision_mask = layer


## Do a collision test with the world
##
## vehicle         - The vehicle constraint
## wheel_index     - Index of the wheel that we're testing collision for
## origin          - Origin for the test, corresponds to the world space
##                   position for the suspension attachment point
## direction       - Direction for the test (unit vector, world space)
## vehicle_body_id - This body should be filtered out during collision detection
##                   to avoid self collisions
## wheel           - wheel to perform collision with, must update wheel when colliding
##
## return true when collision found, false if not
@warning_ignore('unused_parameter')
func Collide(
        space: PhysicsDirectSpaceState3D,
        vehicle: VehicleBase,
        wheel_index: int,
        origin: Vector3,
        direction: Vector3,
        vehicle_body_id: RID,
        wheel: Wheel
) -> bool:
    return false

## Do a cheap contact properties prediction based on the contact properties from
## the last collision test (provided as input parameters)
##
## vehicle         - The vehicle constraint
## wheel_index     - Index of the wheel that we're testing collision for
## origin          - Origin for the test, corresponds to the world space
##                   position for the suspension attachment point
## direction       - Direction for the test (unit vector, world space)
## vehicle_body_id - This body should be filtered out during collision detection
##                   to avoid self collisions
## wheel           - wheel to perform collision with, must update wheel when colliding
@warning_ignore('unused_parameter')
func PredictContactProperties(
        space: PhysicsDirectSpaceState3D,
        vehicle: VehicleBase,
        wheel_index: int,
        origin: Vector3,
        direction: Vector3,
        vehicle_body_id: RID,
        wheel: Wheel
) -> void:
    pass


## Collision tester that tests collision using a raycast
class CastRay extends VehicleCollisionTester:
    var up: Vector3
    var cos_max_slope_angle: float

    ## Constructor
    ##
    ## exclude   - list of RIDs to ignore collision with
    ## layer     - layer to test collision with
    ## up        - World space up vector, used to avoid colliding with vertical walls.
    ## max_slope - Max angle (rad) that is considered for colliding wheels. This
    ##             is to avoid colliding with vertical walls.
    @warning_ignore('shadowed_variable')
    func _init(
            exclude: Array[RID],
            layer: int,
            up: Vector3 = Vector3.UP,
            max_slope: float = deg_to_rad(80.0)
    ) -> void:
        super._init(exclude, layer)

        self.up = up
        cos_max_slope_angle = cos(max_slope)

    @warning_ignore('unused_parameter')
    func Collide(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> bool:
        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float wheel_radius = wheel_settings->mRadius;
        var wheel_radius: float = wheel_settings.radius

        # float ray_length = wheel_settings->mSuspensionMaxLength + wheel_radius;
        var ray_length: float = wheel_settings.suspension_max_length + wheel_radius

        var ray_travel: Vector3 = ray_length * direction

        # RRayCast ray { inOrigin, ray_length * inDirection };
        var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
                origin,
                ray_travel,
                collision_mask,
                body_excludes
        )

        var ray: Dictionary = space.intersect_ray(query)
        if not ray.collider:
            return false

        # outBody = const_cast<Body *>(collector.mBody);
        wheel._contact_body = ray.collider

        # outSubShapeID = collector.mSubShapeID2;
        wheel._contact_shape_idx = ray.shape

        # outContactPosition = collector.mContactPosition;
        wheel._contact_point = ray.position

        # outContactNormal = collector.mContactNormal;
        wheel._contact_normal = ray.normal

        # outSuspensionLength = max(0.0f, ray_length * collector.GetEarlyOutFraction() - wheel_radius);
        var travel: float = (ray_travel - origin).length()
        wheel._suspension_length = maxf(0.0, travel - wheel_radius)

        return true

    @warning_ignore('unused_parameter')
    func PredictContactProperties(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> void:
        # Recalculate the contact points assuming the contact point is on an infinite plane
        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float d_dot_n = inDirection.Dot(ioContactNormal);
        var d_dot_n: float = direction.dot(wheel._contact_normal)

        # if (d_dot_n < -1.0e-6f)
        if d_dot_n < -1.0e-6:
            # Reproject the contact position using the suspension ray and the plane formed by the contact position and normal
            # ioContactPosition = inOrigin + Vec3(ioContactPosition - inOrigin).Dot(ioContactNormal) / d_dot_n * inDirection;
            wheel._contact_point = origin + (wheel._contact_point - origin).dot(wheel._contact_normal) / d_dot_n * direction

            # The suspension length is simply the distance between the contact position and the suspension origin excluding the wheel radius
            # ioSuspensionLength = Clamp(Vec3(ioContactPosition - inOrigin).Dot(inDirection) - wheel_settings->mRadius, 0.0f, wheel_settings->mSuspensionMaxLength);
            wheel._suspension_length = clampf((wheel._contact_point - origin).dot(direction) - wheel_settings.radius, 0.0, wheel_settings.suspension_max_length)
        else:
            # If the normal is pointing away we assume there's no collision anymore
            # ioSuspensionLength = wheel_settings->mSuspensionMaxLength;
            wheel._suspension_length = wheel_settings.suspension_max_length


## Collision tester that tests collision using a sphere cast
class CastSphere extends VehicleCollisionTester:
    var radius: float
    var up: Vector3
    var cos_max_slope_angle: float

    ## Constructor
    ##
    ## exclude   - list of RIDs to ignore collision with
    ## layer     - layer to test collision with
    ## radius    - Radius of sphere
    ## up        - World space up vector, used to avoid colliding with vertical walls.
    ## max_slope - Max angle (rad) that is considered for colliding wheels. This
    ##             is to avoid colliding with vertical walls.
    @warning_ignore('shadowed_variable')
    func _init(
            exclude: Array[RID],
            layer: int,
            radius: float,
            up: Vector3 = Vector3.UP,
            max_slope: float = deg_to_rad(80.0)
    ) -> void:
        super._init(exclude, layer)

        self.radius = radius
        self.up = up
        cos_max_slope_angle = cos(max_slope)

    @warning_ignore('unused_parameter')
    func Collide(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> bool:
        # SphereShape sphere(mRadius);
        var sphere: RID = PhysicsServer3D.sphere_shape_create()
        PhysicsServer3D.shape_set_data(sphere, radius)

        # sphere.SetEmbedded();
        # NOTE: this is not necessary, SetEmbedded() is effectively a ref() call

        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float wheel_radius = wheel_settings->mRadius;
        var wheel_radius: float = wheel_settings.radius

        # float shape_cast_length = wheel_settings->mSuspensionMaxLength + wheel_radius - mRadius;
        var shape_cast_length: float = wheel_settings.suspension_max_length + wheel_radius - radius

        # RShapeCast shape_cast(&sphere, Vec3::sOne(), RMat44::sTranslation(inOrigin), inDirection * shape_cast_length);
        var shape_cast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
        shape_cast.shape_rid = sphere
        shape_cast.transform = Transform3D(Basis.IDENTITY, origin)
        shape_cast.motion = direction * shape_cast_length

        # inPhysicsSystem.GetNarrowPhaseQueryNoLock().CastShape(shape_cast, settings, shape_cast.mCenterOfMassStart.GetTranslation(), collector, broadphase_layer_filter, object_layer_filter, body_filter);
        shape_cast.collision_mask = collision_mask
        shape_cast.exclude = body_excludes
        var result: Dictionary = space.cast_shape(shape_cast)

        # if (collector.mBody == nullptr)
        if not result.collider:
            return false

        # outBody = const_cast<Body *>(collector.mBody);
        wheel._contact_body = result.collider

        # outSubShapeID = collector.mSubShapeID2;
        wheel._contact_shape_idx = result.shape

        # outContactPosition = collector.mContactPosition;
        wheel._contact_point = result.position

        # outContactNormal = collector.mContactNormal;
        wheel._contact_normal = result.normal

        # outSuspensionLength = max(0.0f, shape_cast_length * collector.mFraction + mRadius - wheel_radius);
        wheel._suspension_length = maxf(0.0, shape_cast_length * result.safe_fraction + radius - wheel_radius)

        return true

    @warning_ignore('unused_parameter')
    func PredictContactProperties(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> void:
        # Recalculate the contact points assuming the contact point is on an infinite plane
        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float d_dot_n = inDirection.Dot(ioContactNormal);
        var d_dot_n: float = direction.dot(wheel._contact_normal)

        # if (d_dot_n < -1.0e-6f)
        if d_dot_n < -1.0e-6:
            # Reproject the contact position using the suspension cast sphere and the plane formed by the contact position and normal
            # This solves x = inOrigin + fraction * inDirection and (x - ioContactPosition) . ioContactNormal = mRadius for fraction
            # float oc_dot_n = Vec3(ioContactPosition - inOrigin).Dot(ioContactNormal);
            var oc_dot_n: float = (wheel._contact_point - origin).dot(wheel._contact_normal)

            # float fraction = (mRadius + oc_dot_n) / d_dot_n;
            var fraction: float = (radius + oc_dot_n) / d_dot_n

            # ioContactPosition = inOrigin + fraction * inDirection - mRadius * ioContactNormal;
            wheel._contact_point = origin + (fraction * direction) - (radius * wheel._contact_normal)

            # Calculate the new suspension length in the same way as the cast sphere normally does
            # ioSuspensionLength = Clamp(fraction + mRadius - wheel_settings->mRadius, 0.0f, wheel_settings->mSuspensionMaxLength);
            wheel._suspension_length = clampf(fraction + radius - wheel_settings.radius, 0.0, wheel_settings.suspension_max_length)
        else:
            # If the normal is pointing away we assume there's no collision anymore
            # ioSuspensionLength = wheel_settings->mSuspensionMaxLength;
            wheel._suspension_length = wheel_settings.suspension_max_length


## Collision tester that tests collision using a cylinder shape
class CastCylinder extends VehicleCollisionTester:
    var convex_radius_fraction: float

    ## Constructor
    ##
    ## exclude  - list of RIDs to ignore collision with
    ## layer    - layer to test collision with
    ## fraction - Fraction of half the wheel width (or wheel radius if it is
    ##            smaller) that is used as the convex radius
    func _init(
            exclude: Array[RID],
            layer: int,
            fraction: float = 0.1
    ) -> void:
        super._init(exclude, layer)

        convex_radius_fraction = fraction

    @warning_ignore('unused_parameter')
    func Collide(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> bool:
        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float max_suspension_length = wheel_settings->mSuspensionMaxLength;
        var max_suspension_length: float = wheel_settings.suspension_max_length

        # Get the wheel transform given that the cylinder rotates around the Y axis
        # RMat44 shape_cast_start = inVehicleConstraint.GetWheelWorldTransform(inWheelIndex, Vec3::sAxisY(), Vec3::sAxisX());
        var shape_cast_start: Transform3D = vehicle.GetWheelWorldTransform(wheel_index, Vector3.UP, Vector3.RIGHT)

        # shape_cast_start.SetTranslation(inOrigin);
        shape_cast_start.origin = origin

        # Construct a cylinder with the dimensions of the wheel
        # float wheel_half_width = 0.5f * wheel_settings->mWidth;
        var wheel_half_width: float = 0.5 * wheel_settings.width

        # CylinderShape cylinder(wheel_half_width, wheel_settings->mRadius, min(wheel_half_width, wheel_settings->mRadius) * mConvexRadiusFraction);
        var cylinder: RID = PhysicsServer3D.cylinder_shape_create()
        PhysicsServer3D.shape_set_data(cylinder, { height = wheel_half_width, radius = wheel_settings.radius})
        PhysicsServer3D.shape_set_margin(cylinder, min(wheel_half_width, wheel_settings.radius) * convex_radius_fraction)

        # cylinder.SetEmbedded();
        # NOTE: this is not necessary, SetEmbedded() is effectively a ref() call

        # RShapeCast shape_cast(&cylinder, Vec3::sOne(), shape_cast_start, inDirection * max_suspension_length);
        var shape_cast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
        shape_cast.shape_rid = cylinder
        shape_cast.transform = shape_cast_start
        shape_cast.motion = direction * max_suspension_length

        # inPhysicsSystem.GetNarrowPhaseQueryNoLock().CastShape(shape_cast, settings, shape_cast.mCenterOfMassStart.GetTranslation(), collector, broadphase_layer_filter, object_layer_filter, body_filter);
        shape_cast.collision_mask = collision_mask
        shape_cast.exclude = body_excludes
        var result = space.cast_shape(shape_cast)

        # if (collector.mBody == nullptr)
        if not result.collider:
            return false

        # outBody = const_cast<Body *>(collector.mBody);
        wheel._contact_body = result.collider

        # outSubShapeID = collector.mSubShapeID2;
        wheel._contact_shape_idx = result.shape

        # outContactPosition = collector.mContactPosition;
        wheel._contact_point = result.position

        # outContactNormal = collector.mContactNormal;
        wheel._contact_normal = result.normal

        # outSuspensionLength = max_suspension_length * collector.mFraction;
        wheel._suspension_length = max_suspension_length * result.safe_fraction

        return true

    @warning_ignore('unused_parameter')
    func PredictContactProperties(
            space: PhysicsDirectSpaceState3D,
            vehicle: VehicleBase,
            wheel_index: int,
            origin: Vector3,
            direction: Vector3,
            vehicle_body_id: RID,
            wheel: Wheel
    ) -> void:
        # Recalculate the contact points assuming the contact point is on an infinite plane
        # const WheelSettings *wheel_settings = inVehicleConstraint.GetWheel(inWheelIndex)->GetSettings();
        var wheel_settings: WheelSettings = wheel.mSettings

        # float d_dot_n = inDirection.Dot(ioContactNormal);
        var d_dot_n: float = direction.dot(wheel._contact_normal)

        # if (d_dot_n < -1.0e-6f)
        if d_dot_n < -1.0e-6:
            # Wheel size
            # float half_width = 0.5f * wheel_settings->mWidth;
            var half_width: float = 0.5 * wheel_settings.width

            # float radius = wheel_settings->mRadius;
            var radius: float = wheel_settings.radius

            # Get the inverse local space contact normal for a cylinder pointing along Y
            # RMat44 wheel_transform = inVehicleConstraint.GetWheelWorldTransform(inWheelIndex, Vec3::sAxisY(), Vec3::sAxisX());
            var wheel_transform: Transform3D = vehicle.GetWheelWorldTransform(wheel_index, Vector3.UP, Vector3.RIGHT)

            # Vec3 inverse_local_normal = -wheel_transform.Multiply3x3Transposed(ioContactNormal);
            var inverse_local_normal: Vector3 = -(wheel_transform.basis.transposed() * wheel._contact_normal)

            # Get the support point of this normal in local space of the cylinder
            # See CylinderShape::Cylinder::GetSupport
            # float x = inverse_local_normal.GetX(), y = inverse_local_normal.GetY(), z = inverse_local_normal.GetZ();
            var x: float = inverse_local_normal.x
            var y: float = inverse_local_normal.y
            var z: float = inverse_local_normal.z

            # float o = sqrt(Square(x) + Square(z));
            var o: float = sqrt(x * x + z * z)

            # Vec3 support_point;
            var support_point: Vector3
            # if (o > 0.0f)
            if o > 0.0:
                # support_point = Vec3((radius * x) / o, Sign(y) * half_width, (radius * z) / o);
                support_point = Vector3((radius * x) / o, signf(y) * half_width, (radius * z) / o)
            else:
                # support_point = Vec3(0, Sign(y) * half_width, 0);
                support_point = Vector3(0, signf(y) * half_width, 0)

            # Rotate back to world space
            # support_point = wheel_transform.Multiply3x3(support_point);
            support_point = wheel_transform.basis * support_point

            # Now we can use inOrigin + support_point as the start of a ray of our suspension to the contact plane
            # as know that it is the first point on the wheel that will hit the plane
            # RVec3 origin = inOrigin + support_point;
            var s_origin: Vector3 = origin + support_point

            # Calculate contact position and suspension length, the is the same as VehicleCollisionTesterRay
            # but we don't need to take the radius into account anymore
            # Vec3 oc(ioContactPosition - origin);
            var oc: Vector3 = wheel._contact_point - s_origin

            # ioContactPosition = origin + oc.Dot(ioContactNormal) / d_dot_n * inDirection;
            wheel._contact_point = s_origin + oc.dot(wheel._contact_normal) / d_dot_n * direction

            # ioSuspensionLength = Clamp(oc.Dot(inDirection), 0.0f, wheel_settings->mSuspensionMaxLength);
            wheel._suspension_length = clampf(oc.dot(direction), 0.0, wheel_settings.suspension_max_length)
        else:
            # If the normal is pointing away we assume there's no collision anymore
            # ioSuspensionLength = wheel_settings->mSuspensionMaxLength;
            wheel._suspension_length = wheel_settings.suspension_max_length
