## Hears things
class_name BehaviorSenseHearing extends BehaviorSense


const NAME = &"sound"

func name() -> StringName:
    return NAME


## Groups that can be heard
@export var target_groups: Array[StringName]

## Quietest sound that can be heard
@export_range(0.0, 40.0, 1.0, 'or_less', 'or_greater')
var min_loudness: float = 10.0

@export_range(100.0, 1000.0, 1.0, 'or_less', 'or_greater')
var max_distance: float = 200.0


@export_subgroup("Debug", "debug")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, '')
var debug_enabled: bool = false


## Location to hear from, relative to the character
var ear_pos: Vector3 = Vector3.ZERO


func sense(mind: BehaviorMind) -> void:

    var me: CharacterBase = mind.parent
    var sounds: Array[Dictionary] = GlobalWorld.get_sounds_played(
            mind.delta_time * frequency,
            me.global_position + ear_pos,
            target_groups,
            min_loudness,
            max_distance,
    )

    if sounds.is_empty():
        return

    var memory: BehaviorMemorySensory = mind.memory_bank.get_memory_reference(BehaviorMemorySensory.NAME)
    if not memory:
        memory = BehaviorMemorySensory.new()

    for sound in sounds:
        # NOTE: all the processing is done for us, just saving to memory
        var event: PackedByteArray = memory.start_event(BehaviorMemorySensory.Type.SOUND)

        memory.event_set_expire(event, 10.0)
        memory.event_add_game_time(event)
        memory.event_add_time_of_day(event)
        memory.event_add_travel(event, sound.direction, sound.distance)
        memory.event_add_location(event, me.global_position, me.global_basis.z)
        memory.event_add_groups(event, sound.groups)

        if sound.source:
            memory.event_add_node_path(event, sound.source.get_path())

        memory.finish_event(event)
        mind.memory_bank.save_memory_reference(memory)
        activated = true
