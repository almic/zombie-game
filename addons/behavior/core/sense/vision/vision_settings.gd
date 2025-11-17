@tool
class_name BehaviorSenseVisionSettings extends BehaviorSenseSettings


## Groups that can be seen
@export_custom(PROPERTY_HINT_ARRAY_TYPE, 'StringName', PROPERTY_USAGE_STORAGE)
var target_groups: Array[StringName] = []

@export_custom(PROPERTY_HINT_RANGE, '1,180,1,suffix:°', PROPERTY_USAGE_STORAGE)
var fov: float = 100.0:
    set(value):
        fov = value
        _fov_changed = true

## Range of vision in meters
@export_custom(PROPERTY_HINT_RANGE, '1,50,0.1,or_greater,suffix:m', PROPERTY_USAGE_STORAGE)
var vision_range: float = 50.0

## Mask of physics layers that block vision
@export_custom(PROPERTY_HINT_LAYERS_3D_PHYSICS, '', PROPERTY_USAGE_STORAGE)
var mask: int = 16


## Cosine of the half-angle FOV
var fov_cos_half: float:
    get():
        if _fov_changed:
            fov_cos_half = cos(deg_to_rad(fov) * 0.5)
            _fov_changed = false
        return fov_cos_half

var _fov_changed: bool = true
