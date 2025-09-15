# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name SpringPart extends Resource

var mBias: float = 0.0
var mSoftness: float = 0.0

func CalculateSpringPropertiesHelper(
        inDeltaTime: float,
        inInvEffectiveMass: float,
        inBias: float,
        inC: float,
        inStiffness: float,
        inDamping: float
) -> float:
    mSoftness = 1.0 / (inDeltaTime * (inDamping + inDeltaTime * inStiffness))
    mBias = inBias + inDeltaTime * inStiffness * mSoftness * inC;
    return 1.0 / (inInvEffectiveMass + mSoftness)


## Turn off the spring and set a bias only
func CalculateSpringPropertiesWithBias(inBias: float) -> void:
    mSoftness = 0.0
    mBias = inBias

## Calculate spring properties based on frequency and damping ratio
##
## @param inDeltaTime Time step
## @param inInvEffectiveMass Inverse effective mass K
## @param inBias Bias term (b) for the constraint impulse: lambda = J v + b
## @param inC Value of the constraint equation (C). Set to zero if you don't want to drive the constraint to zero with a spring.
## @param inFrequency Oscillation frequency (Hz). Set to zero if you don't want to drive the constraint to zero with a spring.
## @param inDamping Damping factor (0 = no damping, 1 = critical damping). Set to zero if you don't want to drive the constraint to zero with a spring.
## @param outEffectiveMass On return, this contains the new effective mass K^-1
func CalculateSpringPropertiesWithFrequencyAndDamping(
        inDeltaTime: float,
        inInvEffectiveMass: float,
        inBias: float,
        inC: float,
        inFrequency: float,
        inDamping: float
) -> float:
    var outEffectiveMass = 1.0 / inInvEffectiveMass

    if inFrequency > 0.0:
        # Calculate angular frequency
        var omega: float = 2.0 * PI * inFrequency

        # Calculate spring stiffness k and damping constant c (page 45)
        var k: float = outEffectiveMass * omega * omega
        var c: float = 2.0 * outEffectiveMass * inDamping * omega

        outEffectiveMass = CalculateSpringPropertiesHelper(inDeltaTime, inInvEffectiveMass, inBias, inC, k, c)
    else:
        CalculateSpringPropertiesWithBias(inBias)

    return outEffectiveMass

##  Calculate spring properties with spring Stiffness (k) and damping (c), this is based on the spring equation: F = -k * x - c * v
##
## @param inDeltaTime Time step
## @param inInvEffectiveMass Inverse effective mass K
## @param inBias Bias term (b) for the constraint impulse: lambda = J v + b
## @param inC Value of the constraint equation (C). Set to zero if you don't want to drive the constraint to zero with a spring.
## @param inStiffness Spring stiffness k. Set to zero if you don't want to drive the constraint to zero with a spring.
## @param inDamping Spring damping coefficient c. Set to zero if you don't want to drive the constraint to zero with a spring.
## @param outEffectiveMass On return, this contains the new effective mass K^-1
func CalculateSpringPropertiesWithStiffnessAndDamping(
        inDeltaTime: float,
        inInvEffectiveMass: float,
        inBias: float,
        inC: float,
        inStiffness: float,
        inDamping: float
) -> float:
    var outEffectiveMass: float

    if inStiffness > 0.0:
        outEffectiveMass = CalculateSpringPropertiesHelper(inDeltaTime, inInvEffectiveMass, inBias, inC, inStiffness, inDamping)
    else:
        outEffectiveMass = 1.0 / inInvEffectiveMass
        CalculateSpringPropertiesWithBias(inBias)

    return outEffectiveMass

## Returns if this spring is active
func IsActive() -> bool:
    return mSoftness != 0.0

## Get total bias b, including supplied bias and bias for spring: lambda = J v + b
func GetBias(inTotalLambda: float) -> float:
    return mSoftness * inTotalLambda + mBias
