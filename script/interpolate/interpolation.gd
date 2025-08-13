class_name Interpolation extends RefCounted


## If the transition duration has elapsed
var is_done: bool = true

## If the target has been set
var is_target_set: bool

## Current value of the interpolation
var current: Variant:
    set(value):
        current = value
        if current == null:
            print('stop!')
## Target value of the interpolation, useful to check for target changes
var target: Variant
## Elapsed time of the interpolation
var elapsed: float
## Total duration of the interpolation
var duration: float

## Transition function
var transition: Tween.TransitionType
## Easing function
var easing: Tween.EaseType

var _initial: Variant
var _delta: Variant


@warning_ignore('shadowed_variable')
func _init(
        duration: float = 0.0,
        transition: Tween.TransitionType = Tween.TRANS_LINEAR,
        easing: Tween.EaseType = Tween.EASE_IN_OUT
) -> void:
    self.duration = duration
    self.transition = transition
    self.easing = easing


@warning_ignore('shadowed_variable')
func set_target_delta(target: Variant, delta: Variant, initial: Variant = current) -> void:
    var type: int = typeof(target)
    if initial == null:
        match type:
            TYPE_FLOAT:
                initial = 0.0
            TYPE_QUATERNION:
                initial = Quaternion.IDENTITY
            TYPE_TRANSFORM3D:
                initial = Transform3D.IDENTITY
            TYPE_BASIS:
                initial = Basis.IDENTITY
            TYPE_VECTOR3:
                initial = Vector3.ZERO
            TYPE_VECTOR2:
                initial = Vector2.ZERO

    elapsed = 0
    is_done = false
    self.target = target
    is_target_set = true
    _initial = initial
    _delta = delta


func update(delta: float) -> Variant:
    if not is_target_set:
        return null

    if is_done:
        return current

    elapsed = minf(elapsed + delta, duration)

    current = Tween.interpolate_value(
            _initial,
            _delta,
            elapsed,
            duration,
            transition,
            easing
    )

    if elapsed >= duration:
        is_done = true
        current = target

    return current

func reset(value: Variant = null) -> void:
    is_done = true
    elapsed = 0
    current = value
    target = value
    _initial = null
    _delta = null
