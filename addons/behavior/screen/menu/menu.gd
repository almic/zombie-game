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

## Emitted when traveling to project behavior settings
signal goto_settings()


var _variants: Dictionary
var _created_type: Resource
var _created_type_name: String


func _ready() -> void:
    # Setup menu
    %ButtonCreate.pressed.connect(show_create_menu)
    %ButtonSettings.pressed.connect(show_settings_menu)
    %ButtonBack.pressed.connect(show_menu)

    # Setup create menu
    %TypeSelection.item_selected.connect(on_type_selected)
    %VariantSelection.item_selected.connect(on_variant_selected)
    %ButtonCreateNew.pressed.connect(on_create_new_pressed)
    %NameEditCreate.text_submitted.connect(func(_s): on_create_new_pressed())

    # Start on menu
    show_menu()

func reset() -> void:
    %Menu.visible = false
    %Create.visible = false
    %ButtonBack.visible = false

    %ButtonCreateNew.disabled = true
    _created_type = null
    _created_type_name = ''
    %NameEditCreate.text = ''
    %NameEditCreate.editable = false

    %VariantSelection.flat = true
    %VariantSelection.disabled = true

    %TypeSelection.select(0)
    %VariantSelection.select(0)


func show_menu() -> void:
    reset()

    %Menu.visible = true
    %Label.text = 'Open a Behavior resource, create a new one, or edit project Behavior settings'

func show_create_menu() -> void:
    reset()

    %Create.visible = true
    %Label.text = 'Create a new Behavior resource'
    %ButtonBack.visible = true

func show_settings_menu() -> void:
    goto_settings.emit()


func on_type_selected(type: int) -> void:
    %ButtonCreateNew.disabled = true
    _created_type = null
    _created_type_name = ''
    %NameEditCreate.text = ''
    %NameEditCreate.editable = false

    %VariantSelection.flat = false
    %VariantSelection.disabled = false

    for i in range(%VariantSelection.item_count - 1, 0, -1):
        %VariantSelection.remove_item(i)

    _variants = TYPE_VARIANTS.get(type)
    if not _variants:
        return

    _variants = _variants.duplicate()
    _variants.sort()
    var i: int = 0
    for v in _variants:
        %VariantSelection.add_item(v, i + 1)
        i += 1

    if type == Type.MIND:
        _created_type_name = 'mind'
    elif type == Type.GOAL:
        _created_type_name = 'goal'
    else:
        _created_type_name = ''

    # Select nothing
    %VariantSelection.select(0)


func on_variant_selected(variant: int) -> void:
    if not _variants or variant < 1 or variant > _variants.size():
        return

    var created_name = _variants.keys()[variant - 1]
    _created_type = _variants.get(created_name).new()
    %ButtonCreateNew.disabled = false

    # Build file name
    created_name = 'new_' + created_name.to_lower()
    if _created_type_name:
        created_name += '_' + _created_type_name
    created_name += '_settings'

    %NameEditCreate.text = created_name
    %NameEditCreate.editable = true

func on_create_new_pressed() -> void:
    _created_type.resource_name = %NameEditCreate.text

    var dialog: EditorFileDialog = EditorFileDialog.new()
    dialog.access = EditorFileDialog.ACCESS_RESOURCES
    dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    dialog.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
    dialog.current_file = %NameEditCreate.text + '.tres'
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
