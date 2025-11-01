class_name BehaviorMindState extends Resource


var settings: BehaviorMindSettings
var agent: Object

var delta: float


func _init(agent: Object, settings: BehaviorMindSettings) -> void:
    self.agent = agent
    self.settings = settings
    setup()


func setup() -> void:
    if not settings.initialized:
        settings.init_from_base()


func tick(delta_time: float) -> void:
    self.delta = delta_time
    BehaviorMindNew.update(self)


func act(action: BehaviorAction) -> void:
    agent.on_behavior_action(action)
