class_name World extends Node3D


@export_category("Input Mapping")
@export var global_context: GUIDEMappingContext
@export var camera_context: GUIDEMappingContext
@export var first_person: GUIDEMappingContext
@export var vehicle_context: GUIDEMappingContext

@export_group("Global Actions", 'act')
@export var act_pause: GUIDEAction
@export var act_focus_log: GUIDEAction
@export var act_toggle_log: GUIDEAction
@export var act_toggle_zombie_targeting: GUIDEAction


@export_category("Zombies")

## If zombies should spawn
@export var enable_spawning: bool = true

## If zombies should do targeting
@export var enable_targeting: bool = true:
    set = set_zombie_targeting

## The target number of zombies to have in the world
@export var target_spawn_count: int = 50:
    set(value):
        if value < 1:
            value = 1
        target_spawn_count = value
        compute_spawn_power()

## Additional count allowed after reaching target, the effective maximum. Must
## be greater than zero.
@export var spawn_count_extra: int = 10:
    set(value):
        if value < 1:
            value = 1
        spawn_count_extra = value
        compute_spawn_power()

## The effective spawn chance at the target count, used to create a falloff in
## the spawn rate. See this graph on Desmos for an interactive way to pick this
## value: https://www.desmos.com/calculator/zninz1mgp1
@export_range(0.0001, 0.9999, 0.0001)
var spawn_rate_at_target: float = 0.5:
    set(value):
        spawn_rate_at_target = value
        compute_spawn_power()

var _spawn_rate_power: float = 1

@export_group("Spawn Timer", "spawn_timer")

## Maximum number of seconds between spawns
@export_range(0.1, 30.0, 0.01, 'or_greater')
var spawn_timer_maximum: float = 10.0

## Minimum number of seconds between spawns
@export_range(0.1, 1.0, 0.01, 'or_greater')
var spawn_timer_minimum: float = 0.25

var _spawn_timer: float = 0


@export_group("Zombies", "zomb")

## The zombie to spawn
@export var zomb_basic_zombie: PackedScene

## Rate (in seconds) at which to update active zombie list
@export_range(1.0, 10.0, 0.1, 'or_greater')
var zomb_active_update_rate: float = 5.0


@onready var pause_menu: Control = %ui_pause
@onready var gameover_screen: GameoverScreen = %ui_gameover
@onready var text_log: TextLog = %ui_log


var is_gameover: bool = false

var _zombies: Array[Zombie] = []
var _zombies_update_timer: float = 0.0
var _zombies_updated_this_tick: bool = false
var _zombies_alive: int = 0
var _spawn_points: Array[SpawnPoint] = []


func _ready() -> void:
    GUIDE.enable_mapping_context(global_context)
    GUIDE.enable_mapping_context(first_person)
    GUIDE.enable_mapping_context(camera_context)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    text_log.is_writable = true
    GlobalWorld.Log = text_log

    # Engine.time_scale = 0.25
    spawn_rate_at_target = spawn_rate_at_target
    _spawn_timer = spawn_timer_minimum

    update_spawn_points()

func _process(_delta: float) -> void:

    handle_pause()

    handle_text_log()

    if act_toggle_zombie_targeting.is_triggered():
        enable_targeting = !enable_targeting

    if get_tree().paused:
        return

func _physics_process(delta: float) -> void:

    if enable_spawning:
        spawn_zombie(delta)

    _zombies_update_timer += delta
    if _zombies_update_timer >= zomb_active_update_rate:
        update_zombie_counts()


func handle_pause() -> void:
    if is_gameover or not act_pause.is_triggered():
        return

    # If the text log has input focus, ignore pause inputs
    if text_log.is_input_active:
        return

    if get_tree().paused:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        get_tree().paused = false
        pause_menu.visible = false
    else:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_tree().paused = true
        pause_menu.visible = true

func handle_gameover() -> void:
    if is_gameover:
        return

    is_gameover = true

    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    gameover_screen.process_mode = Node.PROCESS_MODE_INHERIT
    gameover_screen.visible = true
    gameover_screen.play_gameover()

func handle_text_log() -> void:
    if act_toggle_log.is_triggered():
        if not text_log.is_expanded:
            text_log.is_expanded = true
        # Ignore during input, unless ESCAPE is pressed
        # TODO: see if there is a way to get the exact key input that triggered the action
        #       then, check if it is a typable key, and if not then accept it.
        elif not text_log.is_input_active or GUIDE._input_state.is_key_pressed(Key.KEY_ESCAPE):
            text_log.is_expanded = false

        return

    if act_focus_log.is_triggered():
        if not text_log.is_expanded:
            text_log.is_expanded = true
            text_log.is_input_active = true
            # TODO: focus input on text log, and only on the first open (don't refocus)
        return

    # Accept generic escape key press to get out of input mode
    if text_log.is_input_active and GUIDE._input_state.is_key_pressed(Key.KEY_ESCAPE):
        text_log.is_input_active = false


func spawn_zombie(delta: float) -> void:
    _spawn_timer -= delta
    if _spawn_timer > 0:
        return

    #print("Running zombie spawn")
    var chance: float = clampf(compute_spawn_chance(), 0.0, 1.0)

    _spawn_timer = spawn_timer_minimum + ((spawn_timer_maximum - spawn_timer_minimum) * (1.0 - chance))
    #print("Next timer: " + str(_spawn_timer))
    #print("Chance: " + str(chance))

    if chance <= 0:
        #print("Zero chance")
        return

    if randf() > chance:
        #print("Random fail")
        return

    # Spawn a zombie
    var spawn_point: Vector3 = select_zombie_spawn()

    # No spawn point
    if not spawn_point.is_finite():
        #print("No suitable spawn point")
        return

    #print("Spawning zombie: " + str(spawn_point))
    var zombie: Node3D = zomb_basic_zombie.instantiate()
    add_child(zombie)

    zombie.global_position = spawn_point + (0.01 * Vector3.UP)
    zombie.add_to_group('zombie')

    if zombie is Zombie:
        zombie.attack_damage = 20

        var mind: BehaviorMind = zombie.mind
        if enable_targeting:
            for sense in mind.senses:
                if sense is BehaviorSenseVision:
                    if not sense.target_groups.has('zombie_target'):
                        sense.target_groups.append('zombie_target')
                elif sense is BehaviorSenseHearing:
                    if not sense.target_groups.has('zombie_target'):
                        sense.target_groups.append('zombie_target')
        else:
            for sense in mind.senses:
                if sense is BehaviorSenseVision:
                    if sense.target_groups.has('zombie_target'):
                        sense.target_groups.erase('zombie_target')
                elif sense is BehaviorSenseHearing:
                    if sense.target_groups.has('zombie_target'):
                        sense.target_groups.erase('zombie_target')


func update_spawn_points() -> void:
    _spawn_points.assign(get_tree().get_nodes_in_group('zombie_spawn'))

func update_zombie_counts() -> void:
    if _zombies_updated_this_tick:
        return

    _zombies_update_timer = 0.0
    _zombies_updated_this_tick = true
    _zombies.assign(get_tree().get_nodes_in_group('zombie'))

    var alive: int = 0
    for zomb in _zombies:
        if zomb.is_alive():
            alive += 1

    _zombies_alive = alive
    #print("Zombie count: " + str(_zombies_alive))

func compute_spawn_power() -> void:
    _spawn_rate_power = (
            log(1 - spawn_rate_at_target)
            /
            (log(target_spawn_count) - log(target_spawn_count + spawn_count_extra))
    )

func compute_spawn_chance() -> float:
    var limit: int = target_spawn_count + spawn_count_extra
    if _zombies_alive >= limit:
        return 0

    return -pow((float(_zombies_alive) / float(limit)), _spawn_rate_power) + 1.0

func select_zombie_spawn() -> Vector3:
    var spawns: Array[SpawnPoint] = _spawn_points.duplicate()

    while len(spawns) > 0:
        var spawn: SpawnPoint = spawns.pick_random() as SpawnPoint
        spawns.erase(spawn)

        if not spawn.can_spawn:
            continue

        # Check that no zombie is too close to the spawn position
        var good: bool = true
        for zomb in _zombies:
            if not zomb.is_alive():
                continue

            if zomb.global_position.distance_squared_to(spawn.global_position) <= 1.0:
                # Say that we used this spawn so it cannot be tried again for some time
                spawn.use()
                good = false
                break

        if not good:
            continue

        # Good point
        spawn.use()
        return spawn.global_position

    return Vector3(INF, INF, INF)

func on_player_death() -> void:
    handle_gameover()

func on_enter_vehicle() -> void:
    GUIDE.disable_mapping_context(first_person)
    GUIDE.enable_mapping_context(vehicle_context)

func on_exit_vehicle() -> void:
    GUIDE.disable_mapping_context(vehicle_context)
    GUIDE.enable_mapping_context(first_person)

func set_zombie_targeting(enabled: bool) -> void:
    enable_targeting = enabled

    if enable_targeting:
        for zomb in _zombies:
            var mind := zomb.mind
            for sense in mind.senses:
                if sense is BehaviorSenseVision:
                    if not sense.target_groups.has('zombie_target'):
                        sense.target_groups.append('zombie_target')
                elif sense is BehaviorSenseHearing:
                    if not sense.target_groups.has('zombie_target'):
                        sense.target_groups.append('zombie_target')
                # TODO: add other primary senses
    else:
        for zomb in _zombies:
            var mind := zomb.mind
            for sense in mind.senses:
                if sense is BehaviorSenseVision:
                    if sense.target_groups.has('zombie_target'):
                        sense.target_groups.erase('zombie_target')
                elif sense is BehaviorSenseHearing:
                    if sense.target_groups.has('zombie_target'):
                        sense.target_groups.erase('zombie_target')
                # TODO: add other primary senses
