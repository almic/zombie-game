class_name BehaviorMindNew


static func update(state: BehaviorMindState) -> void:

    # Tick senses
    var sense_settings: Array[BehaviorSenseSettings] = state.settings.senses

    for sense in sense_settings:
        if sense.disabled:
            continue

        if sense is BehaviorSenseHearingSettings:
            BehaviorSenseHearing.update(state, sense)
        elif sense is BehaviorSenseVisionSettings:
            BehaviorSenseVision.update(state, sense)
