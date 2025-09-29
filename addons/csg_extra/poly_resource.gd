## Custom resource purely to transform a PackedVector2Array into a reusable
## resource that can be shared between CSGPolygon3D types
@tool
class_name Polygon2DResource extends Resource

## Polygon data
@export var polygon: PackedVector2Array:
    set(value):
        polygon = value
        emit_changed()
