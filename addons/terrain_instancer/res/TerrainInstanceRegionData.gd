class_name TerrainInstanceRegionData extends Resource


@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var vertices: PackedInt32Array

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_STORAGE)
var indexes: PackedInt32Array

func clear() -> void:
    vertices.clear()
    indexes.clear()
