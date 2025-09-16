# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

## Basic settings object for interface that controls acceleration / deceleration of the vehicle
class_name VehicleControllerSettings extends Resource

## Create an instance of the vehicle controller class
@warning_ignore('unused_parameter')
func ConstructController(vehicle: VehicleBase) -> VehicleController:
    return null
