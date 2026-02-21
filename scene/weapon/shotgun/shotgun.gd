extends WeaponScene

const INTO_UNLOAD_RELOAD = &'into_unload_reload'
const OUT_UNLOAD_RELOAD = &'out_unload_reload'

func can_aim() -> bool:
    return (
           is_idle()
        or state == FIRE
        or state == CHARGE
        or state == OUT_UNLOAD_RELOAD
    )

func goto_reload() -> bool:
    if (
           is_idle()
        or state == UNLOAD
        or state == INTO_UNLOAD_RELOAD
        or state == OUT_UNLOAD_RELOAD
    ):
        travel(RELOAD)
        return true
    return false

func goto_unload() -> bool:
    if (
           is_idle()
        or state == RELOAD
        or state == INTO_UNLOAD_RELOAD
        or state == OUT_UNLOAD_RELOAD
    ):
        travel(UNLOAD)
        return true
    return false
