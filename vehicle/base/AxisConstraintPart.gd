# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT


class_name AxisConstraintPart extends Resource

const STATIC = PhysicsServer3D.BodyMode.BODY_MODE_STATIC
const DYNAMIC = PhysicsServer3D.BodyMode.BODY_MODE_RIGID
const KINEMATIC = PhysicsServer3D.BodyMode.BODY_MODE_KINEMATIC


var _r1PlusUxAxis: Vector3
var _r2xAxis: Vector3

var _invI1_R1PlusUxAxis: Vector3
var _invI2_R2xAxis: Vector3

var _effective_mass: float = 0.0
var _spring_part: SpringPart

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_NO_EDITOR)
var total_lambda: float = 0.0


## Internal helper function to update velocities of bodies after Lagrange multiplier is calculated
func ApplyVelocityStep(
        Type1: PhysicsServer3D.BodyMode,
        Type2: PhysicsServer3D.BodyMode,
        ioMotionProperties1: PhysicsDirectBodyState3D,
        inInvMass1: float,
        ioMotionProperties2: PhysicsDirectBodyState3D,
        inInvMass2: float,
        inWorldSpaceAxis: Vector3,
        inLambda: float
) -> bool:
    # Apply impulse if delta is not zero
    if inLambda != 0.0:
        if Type1 == DYNAMIC:
            # ioMotionProperties1->SubLinearVelocityStep((inLambda * inInvMass1) * inWorldSpaceAxis);
            ioMotionProperties1.linear_velocity -= (inLambda * inInvMass1) * inWorldSpaceAxis

            # ioMotionProperties1->SubAngularVelocityStep(inLambda * Vec3::sLoadFloat3Unsafe(mInvI1_R1PlusUxAxis));
            ioMotionProperties1.angular_velocity -= inLambda * _invI1_R1PlusUxAxis

        if Type2 == DYNAMIC:
            # ioMotionProperties2->AddLinearVelocityStep((inLambda * inInvMass2) * inWorldSpaceAxis);
            ioMotionProperties2.linear_velocity += (inLambda * inInvMass2) * inWorldSpaceAxis

            # ioMotionProperties2->AddAngularVelocityStep(inLambda * Vec3::sLoadFloat3Unsafe(mInvI2_R2xAxis));
            ioMotionProperties2.angular_velocity += inLambda * _invI2_R2xAxis

        return true

    return false

## Templated form of SolveVelocityConstraint with the motion types baked in, part 1: get the total lambda
func TemplatedSolveVelocityConstraintGetTotalLambda(
        Type1: PhysicsServer3D.BodyMode,
        Type2: PhysicsServer3D.BodyMode,
        ioMotionProperties1: PhysicsDirectBodyState3D,
        ioMotionProperties2: PhysicsDirectBodyState3D,
        inWorldSpaceAxis: Vector3
) -> float:
    # Calculate jacobian multiplied by linear velocity
    var jv: float
    if Type1 != STATIC and Type2 != STATIC:
        # jv = inWorldSpaceAxis.Dot(ioMotionProperties1->GetLinearVelocity() - ioMotionProperties2->GetLinearVelocity());
        jv = inWorldSpaceAxis.dot(ioMotionProperties1.linear_velocity - ioMotionProperties2.linear_velocity)
    elif Type1 != STATIC:
        # jv = inWorldSpaceAxis.Dot(ioMotionProperties1->GetLinearVelocity());
        jv = inWorldSpaceAxis.dot(ioMotionProperties1.linear_velocity);
    elif Type2 != STATIC:
        # jv = inWorldSpaceAxis.Dot(-ioMotionProperties2->GetLinearVelocity());
        jv = inWorldSpaceAxis.dot(-ioMotionProperties2.linear_velocity)
    else:
        assert(false) # Static vs static is nonsensical!

    # Calculate jacobian multiplied by angular velocity
    if Type1 != STATIC:
        # jv += Vec3::sLoadFloat3Unsafe(mR1PlusUxAxis).Dot(ioMotionProperties1->GetAngularVelocity());
        jv += _r1PlusUxAxis.dot(ioMotionProperties1.angular_velocity)
    if Type2 != STATIC:
        # jv -= Vec3::sLoadFloat3Unsafe(mR2xAxis).Dot(ioMotionProperties2->GetAngularVelocity());
        jv -= _r2xAxis.dot(ioMotionProperties2.angular_velocity)

    # Lagrange multiplier is:
    #
    # lambda = -K^-1 (J v + b)
    var lambda: float = _effective_mass * (jv - _spring_part.GetBias(total_lambda))

    # Return the total accumulated lambda
    return total_lambda + lambda

## Templated form of SolveVelocityConstraint with the motion types baked in, part 2: apply new lambda
func TemplatedSolveVelocityConstraintApplyLambda(
        Type1: PhysicsServer3D.BodyMode,
        Type2: PhysicsServer3D.BodyMode,
        ioMotionProperties1: PhysicsDirectBodyState3D,
        inInvMass1: float,
        ioMotionProperties2: PhysicsDirectBodyState3D,
        inInvMass2: float,
        inWorldSpaceAxis: Vector3,
        inTotalLambda: float
) -> bool:
    var delta_lambda: float = inTotalLambda - total_lambda # Calculate change in lambda
    total_lambda = inTotalLambda # Store accumulated impulse

    return ApplyVelocityStep(
            Type1, Type2,
            ioMotionProperties1, inInvMass1,
            ioMotionProperties2, inInvMass2,
            inWorldSpaceAxis,
            delta_lambda
    )


## Templated form of SolveVelocityConstraint with the motion types baked in
func TemplatedSolveVelocityConstraint(
        Type1: PhysicsServer3D.BodyMode,
        Type2: PhysicsServer3D.BodyMode,
        ioMotionProperties1: PhysicsDirectBodyState3D,
        inInvMass1: float,
        ioMotionProperties2: PhysicsDirectBodyState3D,
        inInvMass2: float,
        inWorldSpaceAxis: Vector3,
        inMinLambda: float,
        inMaxLambda: float
) -> bool:
    var lambda: float = TemplatedSolveVelocityConstraintGetTotalLambda(
            Type1, Type2,
            ioMotionProperties1,
            ioMotionProperties2,
            inWorldSpaceAxis
    )

    # Clamp impulse to specified range
    lambda = clampf(lambda, inMinLambda, inMaxLambda)

    return TemplatedSolveVelocityConstraintApplyLambda(
            Type1, Type2,
            ioMotionProperties1, inInvMass1,
            ioMotionProperties2, inInvMass2,
            inWorldSpaceAxis,
            lambda
    )

func SolveVelocityConstraint(
        ioBody1: PhysicsBody3D,
        ioBody2: PhysicsBody3D,
        inWorldSpaceAxis: Vector3,
        inMinLambda: float,
        inMaxLambda: float
) -> bool:
    # EMotionType motion_type1 = ioBody1.GetMotionType();
    var motion_type1: PhysicsServer3D.BodyMode = PhysicsServer3D.body_get_mode(ioBody1.get_rid())

    # MotionProperties *motion_properties1 = ioBody1.GetMotionPropertiesUnchecked();
    var motion_properties1: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(ioBody1.get_rid())

    # EMotionType motion_type2 = ioBody2.GetMotionType();
    var motion_type2: PhysicsServer3D.BodyMode = PhysicsServer3D.body_get_mode(ioBody2.get_rid())

    # MotionProperties *motion_properties2 = ioBody2.GetMotionPropertiesUnchecked();
    var motion_properties2: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(ioBody2.get_rid())

    # Dispatch to the correct templated form
    match motion_type1:
        DYNAMIC:
            match motion_type2:
                DYNAMIC:
                    return TemplatedSolveVelocityConstraint(
                            DYNAMIC, DYNAMIC,
                            motion_properties1,
                            motion_properties1.inverse_mass,
                            motion_properties2,
                            motion_properties2.inverse_mass,
                            inWorldSpaceAxis,
                            inMinLambda,
                            inMaxLambda
                    )
                KINEMATIC:
                    return TemplatedSolveVelocityConstraint(
                            DYNAMIC, KINEMATIC,
                            motion_properties1,
                            motion_properties1.inverse_mass,
                            motion_properties2,
                            0.0, # Unused
                            inWorldSpaceAxis,
                            inMinLambda,
                            inMaxLambda
                    )

                STATIC:
                    return TemplatedSolveVelocityConstraint(
                        DYNAMIC, STATIC,
                        motion_properties1,
                        motion_properties1.inverse_mass,
                        motion_properties2,
                        0.0, # Unused
                        inWorldSpaceAxis,
                        inMinLambda,
                        inMaxLambda
                )

                _:
                    assert(false)

        KINEMATIC:
            assert(motion_type2 == DYNAMIC)
            return TemplatedSolveVelocityConstraint(
                    KINEMATIC, DYNAMIC,
                    motion_properties1,
                    0.0, # Unused
                    motion_properties2,
                    motion_properties2.inverse_mass,
                    inWorldSpaceAxis,
                    inMinLambda,
                    inMaxLambda
            )

        STATIC:
            assert(motion_type2 == DYNAMIC)
            return TemplatedSolveVelocityConstraint(
                    STATIC, DYNAMIC,
                    motion_properties1,
                    0.0,
                    motion_properties2,
                    motion_properties2.inverse_mass,
                    inWorldSpaceAxis,
                    inMinLambda,
                    inMaxLambda
            )

        _:
            assert(false)

    return false
