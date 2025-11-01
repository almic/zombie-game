@tool
extends Control



## Emitted when traveling to the resource editor
signal goto_editor(res: Resource)

## Emitted when traveling to project behavior settings
signal goto_settings()


var _variants: Dictionary
var _created_type: Resource
var _created_type_name: String


func _ready() -> void:
    # Setup menu
    %ButtonEditor.pressed.connect(goto_editor.emit.bind(null))
    %ButtonCreate.pressed.connect(show_create_menu)
    %ButtonSettings.pressed.connect(goto_settings.emit)

    %Create.new_resource.connect(goto_editor.emit)
    %Create.canceled.connect(show_menu)

    # Start on menu
    show_menu()

func show_menu() -> void:
    %Create.visible = false

    %Menu.visible = true
    %Label.text = 'Open a Behavior resource, create a new one, or edit project Behavior settings'

func show_create_menu() -> void:
    %Menu.visible = false

    %Create.visible = true
    %Label.text = 'Create a new Behavior resource'
