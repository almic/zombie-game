class_name VehicleBase extends VehicleBody3D


## Apply positive acceleration
func do_accelerate() -> void:
    pass

## Apply braking force
func do_brake() -> void:
    pass

## Apply negative acceleration
func do_reverse() -> void:
    pass

## Steer wheels to target angle
func do_steer(target: float) -> void:
    pass
