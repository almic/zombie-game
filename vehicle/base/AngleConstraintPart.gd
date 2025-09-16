# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name AngleConstraintPart extends Resource


var mInvI1_Axis: Vector3
var mInvI2_Axis: Vector3
var mEffectiveMass: float = 0.0
var mSpringPart: SpringPart
var mTotalLambda: float = 0.0
