extends WeaponScene

# NOTE: There is no reason to unload the rifle, so it is disabled
func goto_unload() -> bool:
    return false

func goto_unload_continue() -> bool:
    return false
