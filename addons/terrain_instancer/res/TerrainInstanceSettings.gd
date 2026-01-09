class_name TerrainInstanceSettings extends Resource

@export_range(-1, 10, 1, 'or_greater')
var id: int = -1

@export var enabled: bool = true

## Expected count per 256 sq. meters, or 16x16 meter area
@export_range(0.01, 10.0, 0.01, 'or_greater')
var density: float = 1.0

## Standard deviation in density, used to randomly seed areas with slightly
## more or less instances
@export_range(0.01, 10.0, 0.01, 'or_greater')
var density_deviation: float = 2.0

@export_custom(
    PROPERTY_HINT_DICTIONARY_TYPE,
    '2/1:-1,10,1,or_greater;3/1:0.1,10.0,0.1,or_greater'
)
var minimum_distances: Dictionary
