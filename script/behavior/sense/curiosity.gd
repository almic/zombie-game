class_name BehaviorSenseCuriosity extends BehaviorSense


const NAME = &"curiosity"

func name() -> StringName:
    return NAME


class BehaviorSenseCuriosityTargetSettings extends Resource:

    ## Target group name
    @export var group_name: StringName = &""

    ## Base interest for this group. If a node has multiple groups, the highest
    ## base interest will be selected.
    @export_range(1, 100, 1, 'or_greater', 'hide_slider')
    var base_interest: int = 1

    ## Maximum interest contribution for an individual node, when reached the
    ## interest must decay to zero before more interest can be generated
    @export_range(0, 100, 1, 'or_greater', 'hide_slider')
    var threshold: int = 20

    ## Interest unit decay per second. Interest always decays, but this can be
    ## thought of as the initial delay period when the threshold is reached.
    @export_range(0.01, 2.0, 0.01, 'or_greater', 'suffix:/s')
    var decay_rate: float = 1.0

    ## Time period after interest decays to zero, when it has previously exceeded
    ## the threshold, for an individual node, during which that node cannot add
    ## any interest. This prevents interest instantly regenerating in a stimulus
    ## rich environment.
    @export_range(0, 60, 1, 'or_greater', 'hide_slider', 'suffix:sec')
    var refractory_period: int = 30


## How sensitive the curiosity sense is, multiplier to all interest events, after
## falloff curves are applied.
@export_range(0.0, 1.5, 0.01, 'or_greater')
var curiosity: float = 1.0

## Total interest that can be generated from all sources. This simply acts as
## a bound when reporting total interest to goals. If this is lower than any
## goal's interest threshold, that goal will never run.
@export_range(0, 100, 1, 'or_greater', 'hide_slider')
var maximum_curiosity: int = 100

## How much to multiply interest by based on distance. It is assumed that events
## further than the max_domain of the curve will be out of distance range and no
## longer create interest, even if the final point is greater than zero.
@export var distance_falloff: Curve

## How much to multiply interest by based on age of event. It is assumed that
## events older than the max_domain of the curve will be out of time range and
## no longer create interest, even if the final point is greater than zero.
@export var time_falloff: Curve

## Interesting group names with their base interest and interest threshold. If
## a node has multiple groups, the highest values will be used. The first number
## is the base interest, before falloff and curiosity multipliers. The second
## number is a maximum threshold, after which an individual node cannot
@export var target_groups: Array[BehaviorSenseCuriosityTargetSettings]


func _init() -> void:
    target_groups = target_groups.duplicate(true)


func sense(mind: BehaviorMind) -> void:
    pass
