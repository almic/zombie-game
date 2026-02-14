class_name BehaviorMindNew


static func update(state: BehaviorMindState) -> void:

    # Tick senses
    var vision: BehaviorSenseVisionSettings = state.settings.sense_vision
    if vision and not vision.disabled:
        BehaviorSenseVision.update(state, vision)
