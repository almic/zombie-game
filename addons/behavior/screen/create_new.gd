@tool
extends Control


enum Type {
    MIND = 1,
    SENSE = 2,
    GOAL = 3,
}


const TYPE_VARIANTS = {
    Type.MIND: {
        'Empty' = preload("uid://br3s0fowwjlu3"),
    },
    Type.SENSE: {
        'Vision' = preload("uid://beflq8u4bpx5x"),
        'Hearing' = preload("uid://25owkc0pke7d"),
    },
    Type.GOAL: {
        'Attack' = preload("uid://6j7mmrum8s6y"),
    }
}


## Emitted when creating a new resource
signal new_resource(res: Resource)


@onready var type_selection: OptionButton = %TypeSelection
@onready var variant_selection: OptionButton = %VariantSelection
@onready var create: Button = %Create


var _variants: Dictionary
var _created_type: Resource
var _created_type_name: String


func _ready() -> void:
    type_selection.item_selected.connect(on_type_selected)
    variant_selection.item_selected.connect(on_variant_selected)
    create.pressed.connect(on_create_pressed)
    %NameEdit.text_submitted.connect(func(_s): on_create_pressed())


func on_type_selected(type: int) -> void:
    create.disabled = true
    _created_type = null
    _created_type_name = ''
    %NameEdit.text = ''
    %NameEdit.editable = false

    variant_selection.flat = false
    variant_selection.disabled = false

    for i in range(variant_selection.item_count - 1, 0, -1):
        variant_selection.remove_item(i)

    _variants = TYPE_VARIANTS.get(type)
    if not _variants:
        return

    _variants = _variants.duplicate()
    _variants.sort()
    var i: int = 0
    for v in _variants:
        variant_selection.add_item(v, i + 1)
        i += 1

    if type == Type.MIND:
        _created_type_name = 'mind'
    elif type == Type.GOAL:
        _created_type_name = 'goal'
    else:
        _created_type_name = ''

    # Select nothing
    variant_selection.select(0)


func on_variant_selected(variant: int) -> void:
    if not _variants or variant < 1 or variant > _variants.size():
        return

    var created_name = _variants.keys()[variant - 1]
    _created_type = _variants.get(created_name).new()
    create.disabled = false

    # Build file name
    created_name = 'new_' + created_name.to_lower()
    if _created_type_name:
        created_name += '_' + _created_type_name
    created_name += '_settings'

    %NameEdit.text = created_name
    %NameEdit.editable = true

func on_create_pressed() -> void:
    _created_type.resource_name = %NameEdit.text

    var dialog: EditorFileDialog = EditorFileDialog.new()
    dialog.access = EditorFileDialog.ACCESS_RESOURCES
    dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    dialog.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
    dialog.current_file = %NameEdit.text + '.tres'
    dialog.file_selected.connect(on_create_file, CONNECT_ONE_SHOT)
    dialog.popup()

func on_create_file(path: String) -> void:
    _created_type.take_over_path(path)
    var err: Error = ResourceSaver.save(_created_type)
    _created_type = null

    if err:
        push_error('Error saving new file "' + path + '": ' + str(err))
        return

    new_resource.emit(ResourceLoader.load(path, '', ResourceLoader.CACHE_MODE_REPLACE_DEEP))
