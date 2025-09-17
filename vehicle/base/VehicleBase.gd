# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Constraint that simulates a vehicle
##
## When the vehicle drives over very light objects (rubble) you may see the car body dip down. This is a known issue and is an artifact of the iterative solver that Jolt is using.
## Basically if a light object is sandwiched between two heavy objects (the static floor and the car body), the light object is not able to transfer enough force from the ground to
## the car body to keep the car body up. You can see this effect in the HeavyOnLightTest sample, the boxes on the right have a lot of penetration because they're on top of light objects.
##
## There are a couple of ways to improve this:
##
## 1. You can increase the number of velocity steps (global settings PhysicsSettings::mNumVelocitySteps or if you only want to increase it on
##    the vehicle you can use VehicleConstraintSettings::mNumVelocityStepsOverride). E.g. going from 10 to 30 steps in the HeavyOnLightTest sample makes the penetration a lot less.
##    The number of position steps can also be increased (the first prevents the body from going down, the second corrects it if the problem did
##    occur which inevitably happens due to numerical drift). This solution costs CPU cycles.
##
## 2. You can reduce the mass difference between the vehicle body and the rubble on the floor (by making the rubble heavier or the car lighter).
##
## 3. You could filter out collisions between the vehicle collision test and the rubble completely. This would make the wheels ignore the rubble but would cause the vehicle to drive
## through it as if nothing happened. You could create fake wheels (keyframed bodies) that move along with the vehicle and that only collide with rubble (and not the vehicle or the ground).
## This would cause the vehicle to push away the rubble without the rubble being able to affect the vehicle (unless it hits the main body of course).
##
## Note that when driving over rubble, you may see the wheel jump up and down quite quickly because one frame a collision is found and the next frame not.
## To alleviate this, it may be needed to smooth the motion of the visual mesh for the wheel.
@tool
class_name VehicleBase extends RigidBody3D


## If the gravity is currently overridden
var mIsGravityOverridden: bool = false

## Gravity override value, replaces PhysicsSystem::GetGravity() when mIsGravityOverridden is true
var mGravityOverride: Vector3 = Vector3.ZERO

## Local space forward vector for the vehicle
var mForward: Vector3

## Local space up vector for the vehicle
var mUp: Vector3

## Vector indicating the world space up direction (used to limit vehicle pitch/roll)
var mWorldUp: Vector3

## Wheel states of the vehicle
var mWheels: Array[Wheel]

## Anti rollbars of the vehicle
var mAntiRollBars: Array[AntiRollBar]

## Controls the acceleration / deceleration of the vehicle
var mController: VehicleController

## If this constraint is active
var mIsActive: bool = false

## Number of simulation steps between wheel collision tests when the vehicle is active
var mNumStepsBetweenCollisionTestActive: int = 1

## Number of simulation steps between wheel collision tests when the vehicle is inactive
var mNumStepsBetweenCollisionTestInactive: int = 1

## Current step number, used to determine when to test a wheel
var mCurrentStep: int = 0


# Prevent vehicle from toppling over

## Cos of the max pitch/roll angle
var mCosMaxPitchRollAngle: float

## Cos of the current pitch/roll angle
var mCosPitchRollAngle: float

## Current axis along which to apply torque to prevent the car from toppling over
var mPitchRollRotationAxis: Vector3 = Vector3.UP

 ## Constraint part that prevents the car from toppling over
var mPitchRollPart: AngleConstraintPart

## Class that performs testing of collision for the wheels
var mVehicleCollisionTester: VehicleCollisionTester

# Callbacks

## Returns longitudinal and lateral friction quantity, has the following signature:
## (wheel_index: int, longitudinal_friction: float, lateral_friction: float, body: PhysicsBody3D, shape_id: int) -> Vector2
var combine_friction: Callable = _default_combine_friction

## Called at the beginning of _intgrate_forces, accepts the VehicleBase as the only argument
var pre_step_callback: Callable

## Called after wheel collision is calculated, accepts the VehicleBase as the only argument
var post_collide_callback: Callable

## Called after the controller's PostCollide method is called, accepts the VehicleBase as the only argument
var post_step_callback: Callable


@warning_ignore('unused_parameter')
func _default_combine_friction(
        inWheelIndex: int,
        ioLongitudinalFriction: float,
        ioLateralFriction: float,
        inBody2: PhysicsBody3D,
        inSubShapeID2: int
) -> Vector2:
    var body_friction: float = PhysicsServer3D.body_get_param(inBody2.get_rid(), PhysicsServer3D.BODY_PARAM_FRICTION)

    ioLongitudinalFriction = sqrt(ioLongitudinalFriction * body_friction)
    ioLateralFriction = sqrt(ioLateralFriction * body_friction)
    return Vector2(ioLongitudinalFriction, ioLateralFriction)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    # Callback to higher-level systems. We do it before PreCollide, in case steering changes.
    if pre_step_callback:
        pre_step_callback.call(self)

    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

    if mIsGravityOverridden:
        # If gravity is overridden, we replace the normal gravity calculations
        # if (mBody->IsActive())
        if not sleeping:
            # MotionProperties *mp = mBody->GetMotionProperties();
            # No equivalence

            # mp->SetGravityFactor(0.0f);
            gravity_scale = 0.0

            # mBody->AddForce(mGravityOverride / mp->GetInverseMass());
            state.apply_central_force(mGravityOverride / state.inverse_mass)

        # And we calculate the world up using the custom gravity
        # mWorldUp = (-mGravityOverride).NormalizedOr(mWorldUp);
        if not is_zero_approx(mGravityOverride.length_squared()):
            mWorldUp = (-mGravityOverride).normalized()
    else:
        # Calculate new world up vector by inverting gravity
        # mWorldUp = (-inContext.mPhysicsSystem->GetGravity()).NormalizedOr(mWorldUp);
        if not is_zero_approx(state.total_gravity.length_squared()):
            mWorldUp = (-state.total_gravity).normalized()

    # Callback on our controller
    # mController->PreCollide(inContext.mDeltaTime, *inContext.mPhysicsSystem);
    mController.PreCollide(state.step, space)

    # Calculate if this constraint is active by checking if our main vehicle body is active or any of the bodies we touch are active
    # mIsActive = mBody->IsActive();
    mIsActive = not sleeping

    # Test how often we need to update the wheels
    # uint num_steps_between_collisions = mIsActive? mNumStepsBetweenCollisionTestActive : mNumStepsBetweenCollisionTestInactive;
    var num_steps_between_collisions: int
    if mIsActive:
        num_steps_between_collisions = mNumStepsBetweenCollisionTestActive
    else:
        num_steps_between_collisions = mNumStepsBetweenCollisionTestInactive

    # RMat44 body_transform = mBody->GetWorldTransform();
    var body_transform: Transform3D = state.transform

    # Test collision for wheels
    # for (uint wheel_index = 0; wheel_index < mWheels.size(); ++wheel_index)
    for wheel_index in range(mWheels.size()):
        var wheel: Wheel = mWheels[wheel_index]
        var settings: WheelSettings = wheel.mSettings

        # Calculate suspension origin and direction
        var ws_origin: Vector3 = body_transform * settings.position

        # Vec3 ws_direction = body_transform.Multiply3x3(settings->mSuspensionDirection);
        var ws_direction: Vector3 = body_transform.basis * settings.suspension_direction

        # Test if we need to update this wheel
        if (num_steps_between_collisions == 0
            || (mCurrentStep + wheel_index) % num_steps_between_collisions != 0):
            # Simplified wheel contact test
            # if (!w->mContactBodyID.IsInvalid())
            if is_instance_id_valid(wheel._contact_body_id):
                # Test if the body is still valid
                # w->mContactBody = inContext.mPhysicsSystem->GetBodyLockInterfaceNoLock().TryGetBody(w->mContactBodyID);
                # if (w->mContactBody == nullptr)
                if not is_instance_valid(wheel._contact_body):
                    # It's not, forget the contact
                    # w->mContactBodyID = BodyID();
                    wheel._contact_body_id = 0
                    # w->mContactSubShapeID = SubShapeID();
                    wheel._contact_shape_idx = -1
                    # w->mSuspensionLength = settings->mSuspensionMaxLength;
                    wheel._suspension_length = settings.suspension_max_length
                else:
                    # Extrapolate the wheel contact properties
                    # mVehicleCollisionTester->PredictContactProperties(*inContext.mPhysicsSystem, *this, wheel_index, ws_origin, ws_direction, mBody->GetID(), w->mContactBody, w->mContactSubShapeID, w->mContactPosition, w->mContactNormal, w->mSuspensionLength);
                    mVehicleCollisionTester.PredictContactProperties(
                            space,
                            self,
                            wheel_index,
                            ws_origin,
                            ws_direction,
                            get_rid(),
                            wheel
                    )
        else:
            # Full wheel contact test, start by resetting the contact data
            # w->mContactBodyID = BodyID();
            wheel._contact_body_id = 0

            # w->mContactBody = nullptr;
            wheel._contact_body = null

            # w->mContactSubShapeID = SubShapeID();
            wheel._contact_shape_idx = -1

            # w->mSuspensionLength = settings->mSuspensionMaxLength;
            wheel._suspension_length = settings.suspension_max_length

            # Test collision to find the floor
            # if (mVehicleCollisionTester->Collide(*inContext.mPhysicsSystem, *this, wheel_index, ws_origin, ws_direction, mBody->GetID(), w->mContactBody, w->mContactSubShapeID, w->mContactPosition, w->mContactNormal, w->mSuspensionLength))
            if mVehicleCollisionTester.Collide(
                    space,
                    self,
                    wheel_index,
                    ws_origin,
                    ws_direction,
                    get_rid(),
                    wheel
            ):
                # Store ID (pointer is not valid outside of the simulation step)
                # w->mContactBodyID = w->mContactBody->GetID();
                wheel._contact_body_id = wheel._contact_body.get_instance_id()

        # if (w->mContactBody != nullptr)
        if wheel._contact_body:
            # Store contact velocity, cache this as the contact body may be removed
            # w->mContactPointVelocity = w->mContactBody->GetPointVelocity(w->mContactPosition);
            var body_state: PhysicsDirectBodyState3D = \
                    PhysicsServer3D.body_get_direct_state(wheel._contact_body.get_rid())
            wheel._contact_point_velocity = \
                    body_state.get_velocity_at_local_position(
                        wheel._contact_point - body_state.transform.origin
                    )

            # Determine plane constant for axle contact plane
            #w->mAxlePlaneConstant = RVec3(w->mContactNormal).Dot(ws_origin + w->mSuspensionLength * ws_direction);
            wheel._axle_plane_constant = wheel._contact_normal.dot(ws_origin + wheel._suspension_length * ws_direction)

            # Check if body is active, if so the entire vehicle should be active
            # mIsActive |= w->mContactBody->IsActive();
            mIsActive = mIsActive || !body_state.sleeping

            # Determine world space forward using steering angle and body rotation
            # Vec3 forward, up, right;
            # GetWheelLocalBasis(w, forward, up, right);
            var wheel_basis: Dictionary
            GetWheelLocalBasis(wheel, wheel_basis)

            # forward = body_transform.Multiply3x3(forward);
            var forward: Vector3 = body_transform.basis * wheel_basis.forward

            # right = body_transform.Multiply3x3(right);
            var right: Vector3 = body_transform.basis * wheel_basis.right

            # The longitudinal axis is in the up/forward plane
            # w->mContactLongitudinal = w->mContactNormal.Cross(right);
            wheel._contact_longitudinal = wheel._contact_normal.cross(right)

            # Make sure that the longitudinal axis is aligned with the forward axis
            # if (w->mContactLongitudinal.Dot(forward) < 0.0f)
            if wheel._contact_longitudinal.dot(forward) < 0.0:
                # w->mContactLongitudinal = -w->mContactLongitudinal;
                wheel._contact_longitudinal = -wheel._contact_longitudinal;

            # Normalize it
            # w->mContactLongitudinal = w->mContactLongitudinal.NormalizedOr(w->mContactNormal.GetNormalizedPerpendicular());
            var n: Vector3
            if not is_zero_approx(wheel._contact_longitudinal.length_squared()):
                n = wheel._contact_longitudinal.normalized()
            else:
                # code from Jolt Vec3::GetNormalizedPerpendicular:
                # if (abs(mF32[0]) > abs(mF32[1]))
                # {
                #     float len = sqrt(mF32[0] * mF32[0] + mF32[2] * mF32[2]);
                #     return Vec3(mF32[2], 0.0f, -mF32[0]) / len;
                # }
                # else
                # {
                #     float len = sqrt(mF32[1] * mF32[1] + mF32[2] * mF32[2]);
                #     return Vec3(0.0f, mF32[2], -mF32[1]) / len;
                # }
                n = wheel._contact_normal
                if absf(n.x) > absf(n.y):
                    var length: float = sqrt(n.x * n.x + n.z * n.z)
                    n = Vector3(n.z, 0.0, -n.x) / length
                else:
                    var length: float = sqrt(n.y * n.y + n.z * n.z)
                    n = Vector3(0.0, n.z, -n.y) / length
            wheel._contact_longitudinal = n

            # The lateral axis is perpendicular to contact normal and longitudinal axis
            # w->mContactLateral = w->mContactLongitudinal.Cross(w->mContactNormal).Normalized();
            wheel._contact_lateral = wheel._contact_longitudinal.cross(wheel._contact_normal).normalized()

    # Callback to higher-level systems. We do it immediately after wheel collision.
    if post_collide_callback:
        post_collide_callback.call(self)

    # Calculate anti-rollbar impulses
    # for (const VehicleAntiRollBar &r : mAntiRollBars)
    for r in mAntiRollBars:
        assert(r.mStiffness >= 0.0)

        var lw: Wheel = mWheels[r.mLeftWheel]
        var rw: Wheel = mWheels[r.mRightWheel]

        # if (lw->mContactBody != nullptr && rw->mContactBody != nullptr)
        if lw._contact_body and rw._contact_body:
            # Calculate the impulse to apply based on the difference in suspension length
            # float difference = rw->mSuspensionLength - lw->mSuspensionLength;
            var difference: float = rw._suspension_length - lw._suspension_length

            # float impulse = difference * r.mStiffness * inContext.mDeltaTime;
            var impulse: float = difference * r.mStiffness * state.step

            # lw->mAntiRollBarImpulse = -impulse;
            lw._anti_roll_bar_impulse = -impulse

            # rw->mAntiRollBarImpulse = impulse;
            rw._anti_roll_bar_impulse = impulse
        else:
            # When one of the wheels is not on the ground we don't apply any impulses
            # lw->mAntiRollBarImpulse = rw->mAntiRollBarImpulse = 0.0f;
            lw._anti_roll_bar_impulse = 0.0
            rw._anti_roll_bar_impulse = 0.0

    # Callback on our controller
    # mController->PostCollide(inContext.mDeltaTime, *inContext.mPhysicsSystem);
    mController.PostCollide(state.step, space)

    # Callback to higher-level systems. We do it before the sleep section, in case velocities change.
    if post_step_callback:
        post_step_callback.call(self)

    # If the wheels are rotating, we don't want to go to sleep yet
    # if (mBody->GetAllowSleeping())
    if can_sleep:
        # bool allow_sleep = mController->AllowSleep();
        var allow_sleep: bool = mController.AllowSleep()
        if allow_sleep:
            # for (const Wheel *w : mWheels)
            for wheel in mWheels:
                if abs(wheel.angular_speed) > deg_to_rad(10.0):
                    allow_sleep = false
                    break
        if not allow_sleep:
            # mBody->ResetSleepTimer();
            # NOTE: this specific line will call the same ResetSleepTimer() method above
            #       under the Jolt physics system
            state.sleeping = false

    # Increment step counter
    mCurrentStep += 1

func GetWheelLocalBasis(wheel: Wheel, out: Dictionary) -> void:
    # const WheelSettings *settings = inWheel->mSettings;
    var settings = wheel.mSettings

    # Quat steer_rotation = Quat::sRotation(settings->mSteeringAxis, inWheel->mSteerAngle);
    var steer_rotation = Quaternion(settings.steering_axis, wheel.angle)

    # outUp = steer_rotation * settings->mWheelUp;
    out.up = steer_rotation * settings.up_local

    # outForward = steer_rotation * settings->mWheelForward;
    out.forward = steer_rotation * settings.forward_local

    # outRight = outForward.Cross(outUp).Normalized();
    out.right = out.forward.cross(out.up).normalized()

    # outForward = outUp.Cross(outRight).Normalized();
    out.forward = out.up.cross(out.right).normalized()

# TODO: Investigate if we can use only the Transform3D to do this.
#       pretty sure you can but I don't feel like checking to make sure the
#       results are equivalent, especially with the transpose in the middle
func GetWheelLocalTransform(inWheelIndex: int, inWheelRight: Vector3, inWheelUp: Vector3) -> Transform3D:
    assert(inWheelIndex < mWheels.size())

    # const Wheel *wheel = mWheels[inWheelIndex];
    var wheel: Wheel = mWheels[inWheelIndex]

    # const WheelSettings *settings = wheel->mSettings;
    var settings: WheelSettings = wheel.mSettings

    # Use the two vectors provided to calculate a matrix that takes us from wheel model space to X = right, Y = up, Z = forward (the space where we will rotate the wheel)
    # Mat44 wheel_to_rotational = Mat44(Vec4(inWheelRight, 0), Vec4(inWheelUp, 0), Vec4(inWheelUp.Cross(inWheelRight), 0), Vec4(0, 0, 0, 1)).Transposed();
    var forward: Vector3 = inWheelUp.cross(inWheelRight)
    var wheel_to_rotational: Mat44 = Mat44.create(
            Vector4(inWheelRight.x, inWheelRight.y, inWheelRight.z, 0),
            Vector4(inWheelUp.x, inWheelUp.y, inWheelUp.z, 0),
            Vector4(forward.x, forward.y, forward.z, 0),
            Vector4(0, 0, 0, 1)
    ).transposed()

    # Calculate the matrix that takes us from the rotational space to vehicle local space
    # Vec3 local_forward, local_up, local_right;
    var local: Dictionary

    # GetWheelLocalBasis(wheel, local_forward, local_up, local_right);
    GetWheelLocalBasis(wheel, local)

    # Vec3 local_wheel_pos = settings->mPosition + settings->mSuspensionDirection * wheel->mSuspensionLength;
    var pos: Vector3 = settings.position + settings.suspension_direction * wheel._suspension_length

    # Mat44 rotational_to_local(Vec4(local_right, 0), Vec4(local_up, 0), Vec4(local_forward, 0), Vec4(local_wheel_pos, 1));
    var rotational_to_local: Mat44 = Mat44.from_transform(
            Transform3D(local.right, local.up, local.forward, pos)
    )

    # Calculate transform of rotated wheel
    # return rotational_to_local * Mat44::sRotationX(wheel->mAngle) * wheel_to_rotational;
    return rotational_to_local.mult(Mat44.rotation_x(wheel.angle)).mult(wheel_to_rotational).to_transform()

func GetWheelWorldTransform(inWheelIndex: int, inWheelRight: Vector3, inWheelUp: Vector3) -> Transform3D:
    # return mBody->GetWorldTransform() * GetWheelLocalTransform(inWheelIndex, inWheelRight, inWheelUp);
    return global_transform * GetWheelLocalTransform(inWheelIndex, inWheelRight, inWheelUp)
