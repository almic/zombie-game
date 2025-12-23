class_name TerrainInstanceRegionSettings extends Resource


class InstanceSettings extends Resource:
    @export_range(0, 10, 1, 'or_greater')
    var id: int = -1

    @export var enabled: bool = true

    @export_range(0.01, 10.0, 0.01, 'or_greater')
    var density: float = 1.0


@export
var instances: Array[InstanceSettings]
