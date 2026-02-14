class_name BehaviorMindState extends Resource


signal act(action: BehaviorAction)


@export
var settings: BehaviorMindSettings

var agent: Node3D
var delta: float


func _init(agent: Node3D, settings: BehaviorMindSettings) -> void:
    self.agent = agent
    self.settings = settings
    setup()

func setup() -> void:
    pass

func tick(delta_time: float) -> void:
    self.delta = delta_time
    BehaviorMindNew.update(self)
