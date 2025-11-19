class_name Accelerator extends RefCounted


var accel: float
var deccel: float
var stop_time: float
var limit: float

## Current velocity, the sign encodes the direction
var velocity: float = 0.0


@warning_ignore("shadowed_variable")
func _init(
        accel: float,
        deccel: float = 0.0,
        stop_time: float = 0.0,
        limit: float = 0.0,
) -> void:
    self.accel = accel
    self.deccel = deccel
    self.stop_time = stop_time
    self.limit = limit

## Updates the rate value using the delta time in seconds, and the current offset
## from the desired value. The offset value should be calculated on each call.
func update(delta: float, offset: float) -> float:
    var rate: float = 0
    if is_zero_approx(velocity):
        # Simply accelerate
        rate = accel
    elif not is_equal_approx(signf(offset), signf(velocity)):
        # Going the wrong way, use decceleration speed
        rate = deccel
    else:
        # 1. Can we start deccelerating now and still reach the target, and
        # 2. if we did, will we reach it in no more than "stop" seconds?
        var time: float = absf(velocity) / deccel
        var time_needed: float = ((2 * offset) / velocity) * delta

        if stop_time > 0 and time >= time_needed and time_needed <= stop_time:
            # start slowing down
            rate = -deccel
        else:
            rate = accel

    # Accelerate to top speed
    velocity += (rate * delta * signf(offset))
    if limit > 0:
        velocity = clampf(velocity, -limit, limit)

    return velocity
