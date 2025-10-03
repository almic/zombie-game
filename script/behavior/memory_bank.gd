## Container of memories
class_name BehaviorMemoryBank extends Resource


var memories: Dictionary[StringName, BehaviorMemory] = {}
var locked: bool = false


## Returns a copy of a memory. If changed, the memory must be saved back using
## the 'save_memory()' method.
func get_memory(name: StringName) -> BehaviorMemory:
    var memory: BehaviorMemory = memories.get(name)
    if not memory:
        return null
    return memory.duplicate(true)

## Returns a memory. If changed, the memory is modified here.
func get_memory_reference(name: StringName) -> BehaviorMemory:
    return memories.get(name)

## Saves a copy of the memory for later access.
func save_memory(memory: BehaviorMemory) -> void:
    # NOTE: for development, should be removed
    if locked:
        push_error("Cannot save memories on a locked BehaviorMemoryBank! Is a goal modifying memories? Investigate!")
        return
    memories.set(memory.name(), memory.duplicate(true))

## Saves a memory for later access. If modified after saving, it is also modified here.
func save_memory_reference(memory: BehaviorMemory) -> void:
    # NOTE: for development, should be removed
    if locked:
        push_error("Cannot save memories on a locked BehaviorMemoryBank! Is a goal modifying memories? Investigate!")
        return
    memories.set(memory.name(), memory)

## Runs a decay function on all memories that support decay
func decay_memories(delta: float) -> void:
    # NOTE: for development, should be removed
    if locked:
        push_error("Cannot decay memories on a locked BehaviorMemoryBank! Only the Mind should be decaying memories. Investigate!")
        return

    for memory in memories.values():
        if (memory as BehaviorMemory).can_decay():
            (memory as BehaviorMemory).decay(delta)
