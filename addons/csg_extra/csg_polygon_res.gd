## Custom CSGPolygon3D that uses a resource-type polygon, so many CSGPolygon3Ds
## can share a single polygon shape
@tool
class_name CSGPolygonResource3D extends CSGPolygon3D

@export var polygon_resource: Polygon2DResource = Polygon2DResource.new():
    set(value):
        if polygon_resource and polygon_resource.changed.is_connected(apply_polygon):
            polygon_resource.changed.disconnect(apply_polygon)
        polygon_resource = value
        if polygon_resource:
            if not polygon_resource.changed.is_connected(apply_polygon):
                polygon_resource.changed.connect(apply_polygon)
            apply_polygon()

func _ready() -> void:
    # AGAGAHHHHHH
    polygon_resource = polygon_resource

@warning_ignore('unused_parameter')
func _set(property: StringName, value: Variant) -> bool:
    if property == "polygon":
        push_warning("CSGPolygonResource3D polygon can only be changed through the resource. Ignoring this change.")
        return true
    return false

func apply_polygon() -> void:
    polygon = polygon_resource.polygon.duplicate()
