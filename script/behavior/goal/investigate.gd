class_name BehaviorGoalInvestigate extends BehaviorGoal


const NAME = &"investigate"

func name() -> StringName:
    return NAME


func update_priority(mind: BehaviorMind) -> int:
    return 0

func perform_actions(mind: BehaviorMind) -> void:
    pass
