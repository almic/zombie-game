@tool

## Manages child GPUParticles3D nodes to activate and deactivate as a
## group when this node is activated. Also supports dynamic lights.
class_name ParticleSystem extends Node3D


## If the system is emitting
@export var emitting: bool = false:
    set(value):
        if emitting and value:
            _restart()
        else:
            emitting = value
            _update_emitting()

# Track if child emitters will turn off in the future
var _is_all_oneshot: bool = false

## In seconds, turn child light nodes off (visible = false) after emission starts.
## Zero disables flash, lights will be visible while emitting.
@export var flash_lights: float = 0.0

var _light_time: float = 0.0

## When `flash_lights` is enabled, modulate light's energy with this curve.
## By default, lights are simply turned on and off.
@export var fade_lights: Curve

# For fading lights
var _light_energy: PackedFloat32Array = []


func _ready() -> void:
    _update_emitting(true)

func _process(delta: float) -> void:
    if not emitting:
        return

    if _light_time > 0:
        _light_time = max(0.0, _light_time - delta)

        if fade_lights:
            var index: int = 0
            var mult: float = fade_lights.sample_baked(
                clampf((flash_lights - _light_time) / flash_lights, 0.0, 1.0)
            )
            var disable_lights: bool = is_zero_approx(mult)

            for child in get_children():
                if child is Light3D:
                    if disable_lights:
                        child.visible = false
                    else:
                        child.light_energy = mult * _light_energy[index]
                        index += 1
        elif is_zero_approx(_light_time):
            for child in get_children():
                if child is Light3D:
                    child.visible = false

    if _is_all_oneshot:
        var any_emitting: bool = false
        for child in get_children():
            if child is GPUParticles3D:
                if child.emitting:
                    any_emitting = true
                    break
        if not any_emitting:
            emitting = false

func _update_emitting(cache_lights: bool = false) -> void:
    if emitting:
        _light_time = flash_lights
        _is_all_oneshot = true

    if cache_lights:
        _light_energy.clear()

    var toggle_lights: bool = is_zero_approx(flash_lights)
    for child in get_children():
        if child is GPUParticles3D:
            if not child.one_shot:
                _is_all_oneshot = false

            if emitting and child.one_shot:
                # Always reset one_shot as they can fail to play
                child.restart()
            else:
                child.emitting = emitting

        elif toggle_lights and child is Light3D:
            child.visible = emitting
            if cache_lights:
                _light_energy.append(child.light_energy)

func _restart() -> void:
    _is_all_oneshot = true
    _light_time = flash_lights

    var reset_lights: bool = is_zero_approx(flash_lights)
    var light_index: int = 0

    for child in get_children():
        if child is GPUParticles3D:
            child.restart()
            if not child.one_shot:
                _is_all_oneshot = false
        elif child is Light3D:
            child.visible = true
            if reset_lights:
                child.light_energy = _light_energy[light_index]
                light_index += 1
