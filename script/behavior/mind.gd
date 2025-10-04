## Container for a memory bank, goals, actions, and senses
class_name BehaviorMind extends Resource


@export var senses: Array[BehaviorSense] = []
@export var goals: Array[BehaviorGoal] = []


var parent: CharacterBase
var memory_bank: BehaviorMemoryBank
var delta_time: float

var is_action_phase: bool = false

var _priority_list: Dictionary


func _init() -> void:
    memory_bank = BehaviorMemoryBank.new()
    _priority_list = {}


## Retrieve a sense by name. If two senses are the same type, returns the first one.
func get_sense(name: StringName) -> BehaviorSense:
    for sense in senses:
        if name == sense.name():
            return sense
    return null

## Retrieve a goal by name. If two goals are the same type, returns the first one.
func get_goal(name: StringName) -> BehaviorGoal:
    for goal in goals:
        if name == goal.name():
            return goal
    return null

## Call during the physics frame to do behavior stuff
func update(delta: float) -> void:
    delta_time = delta

    # Process senses to update memories
    memory_bank.locked = false
    for sense in senses:
        if sense.tick():
            sense.on_sense.emit(sense)
            sense.sense(self)
    memory_bank.decay_memories(delta_time)
    memory_bank.locked = true

    # Get goal call order
    var priority: int
    for goal in goals:
        priority = goal.update_priority(self)
        if priority < 1:
            continue

        if not _priority_list.has(priority):
            _priority_list.set(priority, goal)
            continue

        var value: Variant = _priority_list.get(priority)
        if value is Array:
            value.append(goal)
            continue

        _priority_list.set(priority, [value, goal])

    # Perform goals
    _priority_list.sort()
    var tasks: Array[Variant] = _priority_list.values()
    var task: Variant
    is_action_phase = true
    for i in range(tasks.size() - 1, -1, -1):
        task = tasks[i]
        if task is Array:
            for t in task:
                (t as BehaviorGoal).perform_actions(self)
        else:
            (task as BehaviorGoal).perform_actions(self)
    is_action_phase = false
    _priority_list.clear()


## Called by goals during the action phase. Calling from outside of a goal's
## 'perform_action()' method is an error.
func act(action: BehaviorAction) -> void:
    # NOTE: for development, should be removed
    if not is_action_phase:
        push_error('BehaviorMind can only `act()` during the goal action phase! Investigate!')
        return

    if parent and parent._handle_action(action):
        return

    # Default action behaviors
    # TODO
