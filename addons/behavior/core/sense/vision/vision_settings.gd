@tool
class_name BehaviorSenseVisionSettings extends BehaviorSenseSettings


## Groups that can be seen
@export_custom(PROPERTY_HINT_ARRAY_TYPE, 'StringName', PROPERTY_USAGE_STORAGE)
var target_groups: Array[StringName] = []

@export_custom(PROPERTY_HINT_RANGE, '1,180,1,suffix:°', PROPERTY_USAGE_NONE)
var fov: float:
    get = get_fov, set = set_fov

## Cosine of the half-angle FOV
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var fov_cos_half: float = cos(deg_to_rad(100.0) * 0.5)

## Range of vision in meters
@export_custom(PROPERTY_HINT_RANGE, '1,50,0.1,or_greater,suffix:m', PROPERTY_USAGE_STORAGE)
var vision_range: float = 50.0

## Mask of physics layers that block vision
@export_custom(PROPERTY_HINT_LAYERS_3D_PHYSICS, '', PROPERTY_USAGE_STORAGE)
var mask: int = 16


func get_fov() -> float:
    return rad_to_deg(acos(fov_cos_half) * 2.0)

func set_fov(degrees: float) -> void:
    fov_cos_half = cos(deg_to_rad(degrees * 0.5))
