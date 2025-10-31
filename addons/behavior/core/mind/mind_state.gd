class_name BehaviorMindState extends Resource


var settings: BehaviorMindSettings
var agent: Object


func _init(agent: Object, settings: BehaviorMindSettings) -> void:
    self.agent = agent
    self.settings = settings


func act(action: BehaviorAction) -> void:
    agent.on_behavior_action(action)
