# Ported from Jolt by almic

# Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
# SPDX-FileCopyrightText: 2021 Jorrit Rouwe
# SPDX-License-Identifier: MIT

class_name SpringSettings extends Resource

enum Mode {
    ## Frequency and damping are specified
    FrequencyAndDamping = 0,

    ## Stiffness and damping are specified
    StiffnessAndDamping = 1
}

@export var mode: Mode = Mode.FrequencyAndDamping:
    set(value):
        if value != mode:
            mode = value
            notify_property_list_changed()

## If frequency > 0 the constraint will be soft and frequency specifies the oscillation frequency in Hz.
## If frequency <= 0, damping is ignored and the constraint will have hard limits
@export_range(0.0, 30.0, 0.01, 'or_greater', 'suffix:Hz')
var frequency: float = 0.0

## If stiffness > 0 the constraint will be soft and stiffness specifies the
## stiffness (k) in the spring equation F = -k * x - c * v
## If stiffness <= 0, damping is ignored and the constraint will have hard limits
##
## To calculate a ballpark value for the needed stiffness you can use:
## stiffness = mass * gravity / delta_spring_length * 0.001.
##
## So if your object weighs 1500 kg and the spring compresses by 2 meters, you
## need a stiffness in the order of 1500 * 9.81 / 2 * 0.001 ~ 75 N/mm.
@export_range(0.0, 100.0, 0.01, 'or_greater', 'suffix:N/mm')
var stiffness: float = 0.0:
    set(value):
        stiffness = value
        _stiffness_meters = value * 1000.0

var _stiffness_meters: float

## When mode = FrequencyAndDamping, damping is the damping ratio (0 = no damping, 1 = critical damping).
## When mode = StiffnessAndDamping, damping is the damping (c) in the spring equation:
## F = -k * x - c * v
##
## Note that if you set damping = 0, you will not get an infinite oscillation.
## Because we integrate physics using an explicit Euler scheme, there is always energy loss.
## This is done to keep the simulation from exploding, because with a damping of 0 and even the
## slightest rounding error, the oscillation could become bigger and bigger.
@export var damping: float = 0.0


@warning_ignore('shadowed_variable')
func _init(mode: Mode, frequency_or_stiffness: float, damping: float) -> void:
    self.mode = mode
    if self.mode == Mode.FrequencyAndDamping:
        frequency = frequency_or_stiffness
    else:
        stiffness = frequency_or_stiffness
    self.damping = damping

func _validate_property(property: Dictionary) -> void:
    if property.name == 'frequency':
        if mode != Mode.FrequencyAndDamping:
            property.usage = PROPERTY_USAGE_NO_EDITOR
    elif property.name == 'stiffness':
        if mode != Mode.StiffnessAndDamping:
            property.usage = PROPERTY_USAGE_NO_EDITOR
