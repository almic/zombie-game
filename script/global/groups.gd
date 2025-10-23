## Maps group names to unique indexes, help reduce processing time and memory
## for systems that track group names. Instead they can just pass around IDs.

## Maps names to their id
static var name_to_id: Dictionary[StringName, int]
## Maps ids to their name
static var id_to_name: Dictionary[int, StringName]


static func _static_init() -> void:
    ## All groups that have unique ids. Stored as a temporary to somewhat reduce
    ## memory usage.
    var names: Array[StringName] = [
        &'zombie',
        &'zombie_target',
        &'gunshot',
        &'character_move',
        &'player_move',
        &'zombie_move',
    ]

    for i in range(names.size()):
        var name: StringName = names[i]
        name_to_id.set(name, i)
        id_to_name.set(i, name)


static func get_group_id(group_name: StringName) -> int:
    return name_to_id.get(group_name, -1)


static func get_group_name(group_id: int) -> StringName:
    return id_to_name.get(group_id, &'')
