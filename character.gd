class_name Character extends CharacterBody3D

@onready var camera_3d: Camera3D = %Camera3D



@export_category("Movement")
@export var gravity: float = 9.81
@export var jump_power: float = 5
@export var look_speed: float = 0.55

@export_subgroup("Movement", "move")
@export var move_accel: float = 20
@export var move_top_speed: float = 4.8
@export var move_friction: float = 15
@export var move_air_ctl: float = 0.25
@export var move_turn_speed_keep: float = 0.67

@export_subgroup("Controls")
@export var jump: GUIDEAction
@export var look: GUIDEAction
@export var move: GUIDEAction

func _process(_delta: float) -> void:
    rotation_degrees.y -= look.value_axis_2d.x * look_speed
    camera_3d.rotation_degrees.x = clampf(
        camera_3d.rotation_degrees.x - look.value_axis_2d.y * look_speed,
        -89, 89
    )

func _physics_process(delta: float) -> void:
    var move_length: float = move.value_axis_3d.length()
    var stationary: bool = is_zero_approx(move_length)
    
    var move_direction
    var move_dot: float = -2 # -2 is a signal value
    var movement: Vector3
    
    if !stationary:
        move_direction = move.value_axis_3d / move_length
        movement = basis * move_direction
        move_direction = Vector2(movement.x, movement.z) # true direction
        movement *= move_accel * delta
    else:
        movement = Vector3.ZERO
    
    if not is_on_floor():
        # Less control in air
        movement *= move_air_ctl
        
        # Gravity
        velocity.y -= gravity * delta
    else:
        # Jumping
        if jump.is_triggered() or jump.is_ongoing():
            velocity.y += jump_power
            
        # Apply ground friction opposite to direction and movement
        if velocity.length_squared() > 0:
            if stationary:
                # No movement, full friction
                velocity.x -= velocity.x * move_friction * delta
                velocity.z -= velocity.z * move_friction * delta
            else:
                # Friction opposite to movement
                var friction: Vector2 = Vector2(velocity.x, velocity.z)
                var speed: float = friction.length()
                var current_direction: Vector2 = friction / speed
                move_dot = clampf(
                    current_direction.dot(move_direction),
                    -1, 1
                )
                
                if !is_equal_approx(move_dot, 1):
                    # More friction in similar directions, reduce slidey feel when
                    # strafing parallel to main direction
                    var inv_power = move_dot
                    if inv_power > 0:
                        inv_power *= inv_power
                        
                    var friction_accel: float = (1 - inv_power) * move_friction * delta
                    friction *= friction_accel
                    velocity.x -= friction.x
                    velocity.z -= friction.y
                    
                    # Retain some speed when turning
                    var loss: float = speed * friction_accel
                    
                    # Allow counter-strafing at "half" the normal rate, reduce
                    # jumping feel for perfect counter-strafing
                    if inv_power <= 0:
                        loss *= move_turn_speed_keep
                        
                    velocity.x += loss * move_turn_speed_keep * move_direction.x
                    velocity.z += loss * move_turn_speed_keep * move_direction.y
    
    # Accelerate up to top speed, deccel whichever way
    if !stationary:
        # For later, if wanted
        #if move_dot < -1:
            #move_dot = clampf(
                #Vector2(velocity.x, velocity.z)
                        ## .normalized() # not wanted
                        #.dot(move_direction),
                #-1, 1
            #)
        
        movement.x += velocity.x
        movement.z += velocity.z
        
        # Enforce maximum additional speed
        var len_sqr: float = movement.length_squared()
        if len_sqr > move_top_speed ** 2:
            movement = (movement / sqrt(len_sqr)) * move_top_speed
            
        velocity.x = movement.x
        velocity.z = movement.z
    
    # Update position
    move_and_slide()
