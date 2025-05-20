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

@export_group("Debug", "debug")

## Forces lights to be visible
@export var debug_lights: bool = false:
    set(value):
        debug_lights = value
        if debug_lights:
            _update_emitting(true) # cache light energies
            if is_node_ready():
                for child in get_children():
                    if child is Light3D:
                        child.visible = true
        else:
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

## If child MeshIntance3D's should be cached and animated. This REQUIRES each
## child to have a shader material with a `time` parameter.
@export var enable_mesh_animation: bool = false:
    set(value):
        enable_mesh_animation = value
        if value:
            _mesh_instances.clear()
            get_mesh_children(self)

## Mesh animation time
@export_range(0.001, 0.5, 0.0001, 'or_greater')
var mesh_animation_time: float = 0.1

var _mesh_instances: Array[MeshInstance3D] = []
var _mesh_tween: Tween
var _mesh_time: float = 0.0:
    set(value):
        _mesh_time = value
        var hide_mesh: bool = value > 0.998
        for mesh in _mesh_instances:
            if hide_mesh:
                mesh.visible = false
            else:
                mesh.visible = true
                mesh.set_instance_shader_parameter("time", _mesh_time)


func _ready() -> void:
    _update_emitting(true)

    if enable_mesh_animation:
        get_mesh_children(self)

func _process(delta: float) -> void:
    if not emitting:
        return

    if _light_time > 0 and not debug_lights:
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
                        child.visible = true
                        child.light_energy = mult * _light_energy[index]
                        index += 1
        elif is_zero_approx(_light_time):
            for child in get_children():
                if child is Light3D:
                    child.visible = false

    # Track lights to one-shots
    if _is_all_oneshot and (_mesh_tween and not _mesh_tween.is_running()):
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

    var toggle_lights: bool = is_zero_approx(flash_lights) and not debug_lights
    var light_index: int = 0
    for child in get_children():
        if child is GPUParticles3D:
            if not child.one_shot:
                _is_all_oneshot = false

            if emitting and child.one_shot:
                # Always reset one_shot as they can fail to play
                child.restart()
            else:
                child.emitting = emitting
        elif child is Light3D:
            if cache_lights:
                _light_energy.append(child.light_energy)
            if toggle_lights:
                child.visible = emitting
            elif _light_energy.size() > 0:
                # reset light energies
                child.light_energy = _light_energy[light_index]
                light_index += 1

    update_mesh_tween()

func _restart() -> void:
    _is_all_oneshot = true
    _light_time = flash_lights

    var reset_lights: bool = not is_zero_approx(flash_lights)
    var light_index: int = 0

    for child in get_children():
        if child is GPUParticles3D:
            child.restart()
            if not child.one_shot:
                _is_all_oneshot = false
        elif child is Light3D:
            if reset_lights:
                # Turn off so next curve sample can turn on
                child.visible = false
                child.light_energy = _light_energy[light_index]
                light_index += 1
            else:
                # Turn on immediately
                child.visible = true

func update_mesh_tween() -> void:
    if _mesh_tween:
        _mesh_tween.kill()

    if not emitting:
        return

    # Set random noise offsets on children
    for mesh in _mesh_instances:
        mesh.set_instance_shader_parameter("noise_offset", Vector2(randf(), randf()))

    # Start animation
    _mesh_tween = create_tween()
    _mesh_tween.tween_property(self, "_mesh_time", 1.0, mesh_animation_time).from(0.0)
    _mesh_tween.play()

func get_mesh_children(parent: Node3D) -> void:
    for child in parent.get_children():
        if child is MeshInstance3D:
            _mesh_instances.append(child)
            # Reset values so they don't get left with random stuff
            child.set_instance_shader_parameter("time", 0.0)
            child.set_instance_shader_parameter("noise_offset", Vector2(0.0, 0.0))
            child.visible = false
            if child.get_child_count() > 0:
                get_mesh_children(child)
