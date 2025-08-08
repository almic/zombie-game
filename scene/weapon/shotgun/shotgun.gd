extends WeaponScene

func can_aim() -> bool:
    var state: StringName = anim_state.get_current_node()
    return (
           state == WALK
        or state == IDLE
        or state == FIRE
        or state == CHARGE
        or state == &'in_unload_reload'
        or state == &'out_unload_reload'
    )
