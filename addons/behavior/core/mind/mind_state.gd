class_name BehaviorMind extends Resource


signal act(action: BehaviorAction)


@export
var settings: BehaviorMindSettings


var agent: Node3D
var delta: float


## Queue of sensory events to process
var sensory_events: Dictionary


func _init(agent: Node3D, settings: BehaviorMindSettings) -> void:
    self.agent = agent
    self.settings = settings
    setup()

func setup() -> void:
    pass

func tick(delta_time: float) -> void:
    self.delta = delta_time

    # Tick senses
    var vision: BehaviorSenseVisionSettings = settings.sense_vision
    if vision and not vision.disabled:
        BehaviorSenseVision.update(self, vision)

    # Process sensory queue
    # TODO

    # Update active goal
    # TODO

    # Execute goals
    # TODO


func has_sense_event(type: StringName, node: NodePath) -> bool:
    if not sensory_events.has(type):
        return false
    var events: Array[Dictionary] = sensory_events.get(type)
    for ev in events:
        if ev.node == node:
            return true
    return false

func add_sense_event(type: StringName, node: NodePath, data: Variant) -> void:
    var events: Array[Dictionary]
    var ev: Dictionary = {
            &'node': node,
            &'data': data,
    }
    if sensory_events.has(type):
        events = sensory_events.get(type)
        events.append(ev)
    else:
        events.append(ev)
        sensory_events.set(type, events)
