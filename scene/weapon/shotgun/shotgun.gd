extends WeaponScene

const INTO_UNLOAD_RELOAD = &'into_unload_reload'
const OUT_UNLOAD_RELOAD = &'out_unload_reload'

func can_aim() -> bool:
    var state: StringName = anim_state.get_current_node()
    return (
           state == WALK
        or state == IDLE
        or state == FIRE
        or state == CHARGE
        or state == OUT_UNLOAD_RELOAD
    )

func goto_reload() -> bool:
    var state: StringName = anim_state.get_current_node()
    if (
           state == WALK
        or state == IDLE
        or state == UNLOAD
        or state == INTO_UNLOAD_RELOAD
        or state == OUT_UNLOAD_RELOAD
    ):
        travel(RELOAD)
        return true
    return false

func goto_unload() -> bool:
    var state: StringName = anim_state.get_current_node()
    if (
           state == WALK
        or state == IDLE
        or state == RELOAD
        or state == INTO_UNLOAD_RELOAD
        or state == OUT_UNLOAD_RELOAD
    ):
        travel(UNLOAD)
        return true
    return false
