@tool

class_name Pickup extends Marker3D


## The resource that identifies this item type
@export var item_type: PickupResource

## How much of the item exists
@export var item_count: int = 0


@export_group("Visual", "item")

## Scene spawned to display the item in game
@export var item_scene: PackedScene:
    set(value):
        item_scene = value
        _load_item()

## Offset for the display item
@export var item_scene_offset: Vector3 = Vector3.UP

## Rotation of displayed item
@export_custom(PROPERTY_HINT_NONE, '-360, 360, 0.1, or_less, or_greater, radians_as_degrees')
var item_scene_rotation: Vector3 = Vector3.ZERO


var item: Node3D
var area: Area3D:
    set(value):
        area = value
        prepare_area()


func _ready() -> void:
    prepare_node.call_deferred(self)

    _load_item()


func _process(_delta: float) -> void:
    if not item:
        if Engine.is_editor_hint() and item_scene:
            _load_item()
        return

    item.position = item_scene_offset
    item.rotation = item_scene_rotation


func _load_item() -> void:
    if item:
        remove_child(item)
        item.queue_free()
        item = null

    if not item_scene:
        return

    item = item_scene.instantiate() as Node3D

    if not item:
        push_warning('Item pickup scene is not a Node3D!')
        return

    add_child(item)

    item.position = item_scene_offset
    item.rotation = item_scene_rotation


func on_body_entered(body: Node3D) -> void:
    var player: Player = body as Player

    if not player:
        return

    player.pickup_item(self)


func prepare_area() -> void:
    area.monitorable = false
    area.monitoring = true

    # TODO: I don't like these being hardcoded like this.
    # find a better, non-magic-number, way
    area.collision_layer = 0
    area.collision_mask = 1

    area.body_entered.connect(on_body_entered)


static func prepare_node(pickup: Pickup) -> void:
    for child in pickup.get_children():
        if child is Area3D:
            pickup.area = child
            break

    if not pickup.area:
        pickup.area = Area3D.new()
        pickup.add_child(pickup.area, true)
        pickup.area.owner = pickup.owner

    for child in pickup.area.get_children():
        if child is CollisionShape3D:
            return

    var area_collision = CollisionShape3D.new()
    area_collision.debug_color = Color(0.35, 0.866, 0.152, 0.757)
    pickup.area.add_child(area_collision, true)
    area_collision.owner = pickup.owner
