@tool
class_name CSGCurveBox3D extends CSGCurve3D


## Width and height of the box
@export var size: Vector2 = Vector2(1.0, 1.0):
    set(value):
        size = value
        update_shape()

func _ready() -> void:
    super._ready()
    update_shape()

func update_shape() -> void:
    if not is_node_ready():
        return

    var w: float = size.x * 0.5
    var h: float = size.y * 0.5

    polygon_resource = Polygon2DResource.new()
    var p: PackedVector2Array = polygon_resource.polygon
    if p.size() != 4:
        p.clear()
        p.resize(4)

    p[0] = Vector2(-w, -h)
    p[1] = Vector2(-w,  h)
    p[2] = Vector2( w,  h)
    p[3] = Vector2( w, -h)

    polygon_resource.polygon = p
