class_name World extends Node3D


@onready var terrain_nav_region: NavigationRegion3D = %TerrainNavRegion


@export_category("Input Mapping")
@export var first_person: GUIDEMappingContext

@export_group("Global Actions")
@export var pause : GUIDEAction


@export_category("Zombies")

## If zombies should spawn
@export var enable_spawning: bool = true

## If zombies should do targetting
@export var enable_targetting: bool = true

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


@onready var pause_menu: Control = %pause
@onready var gameover_screen: GameoverScreen = %gameover


var is_gameover: bool = false

var _zombies: Array[Zombie] = []
var _zombies_alive: int = 0
var _spawn_points: Array[SpawnPoint] = []

func _ready() -> void:
    GUIDE.enable_mapping_context(first_person)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    # Engine.time_scale = 0.25
    spawn_rate_at_target = spawn_rate_at_target
    _spawn_timer = spawn_timer_minimum

    update_spawn_points()

func _process(delta: float) -> void:

    handle_pause()

    if get_tree().paused:
        return

    if enable_spawning:
        spawn_zombie(delta)


func handle_pause() -> void:
    if is_gameover or not pause.is_triggered():
        return

    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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


func spawn_zombie(delta: float) -> void:
    _spawn_timer -= delta
    if _spawn_timer > 0:
        return

    #print("Running zombie spawn")
    update_zombie_counts()
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
        zombie.target_enabled = enable_targetting
        zombie.target_search_groups.append('zombie_target')

func update_spawn_points() -> void:
    _spawn_points.assign(get_tree().get_nodes_in_group('zombie_spawn'))

func update_zombie_counts() -> void:
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
