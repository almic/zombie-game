class_name BehaviorSenseCuriosityTargetSettings extends Resource

## Target group name
@export var group_name: StringName = &""

## Base interest for this group. If a node has multiple groups, the highest
## base interest will be selected.
@export_range(1, 100, 1, 'or_greater')
var base_interest: int = 1

## Maximum interest contribution for an individual node, when reached the
## interest must decay to zero before more interest can be generated
@export_range(0, 100, 1, 'or_greater')
var threshold: int = 20

## Interest unit decay per second. Interest always decays, but this can be
## thought of as the initial delay period when the threshold is reached.
@export_range(0.01, 2.0, 0.01, 'or_greater', 'suffix:/s')
var decay_rate: float = 1.0

## Time period after interest decays to zero, when it has previously exceeded
## the threshold, for an individual node, during which that node cannot add
## any interest. This prevents interest instantly regenerating in a stimulus
## rich environment.
@export_range(0, 60, 1, 'or_greater', 'suffix:sec')
var refractory_period: int = 30
