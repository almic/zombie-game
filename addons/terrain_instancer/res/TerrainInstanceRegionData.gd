class_name TerrainInstanceRegionData extends Resource


## Painted region vertices used for mesh area
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var vertices: PackedInt32Array

## Faces used for terrain population and instance management
@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var indexes: PackedInt32Array

func clear() -> void:
    vertices.clear()
    indexes.clear()
