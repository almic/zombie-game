# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## An anti rollbar is a stiff spring that connects two wheels to reduce the
## amount of roll the vehicle makes in sharp corners
## See: https://en.wikipedia.org/wiki/Anti-roll_bar
class_name AntiRollBar extends Resource

## Index (in mWheels) that represents the left wheel of this anti-rollbar
@export_range(0, 1, 1, 'or_greater', 'hide_slider')
var mLeftWheel: int = 0

## Index (in mWheels) that represents the right wheel of this anti-rollbar
@export_range(0, 1, 1, 'or_greater', 'hide_slider')
var mRightWheel: int = 1

## Stiffness (spring constant in N/m) of anti rollbar, can be 0 to disable the anti-rollbar
@export_range(0.0, 10000.0, 0.1, 'or_greater', 'suffix:N/m')
var mStiffness: float = 1000.0
