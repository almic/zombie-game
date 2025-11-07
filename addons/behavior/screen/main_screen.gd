@tool
extends Control


const SECTION_MAIN = &'Main'


func _ready() -> void:
    %Menu.goto_settings.connect(show_settings)
    %Menu.goto_editor.connect(edit)

    %Settings.goto_menu.connect(show_menu)

    %Editor.goto_menu.connect(show_menu)

    show_menu()


func save_state(config: ConfigFile) -> void:
    config.set_value(SECTION_MAIN, 'Menu', %Menu.visible)
    config.set_value(SECTION_MAIN, 'Settings', %Settings.visible)
    config.set_value(SECTION_MAIN, 'Editor', %Editor.visible)

    %Editor.save_state(config)

func load_state(config: ConfigFile) -> void:
    if config.get_value(SECTION_MAIN, 'Menu', false):
        show_menu()
    elif config.get_value(SECTION_MAIN, 'Settings', false):
        show_settings()
    elif config.get_value(SECTION_MAIN, 'Editor', false):
        show_editor()
    else:
        show_menu()

    %Editor.load_state(config)

func get_unsaved_status() -> String:
    var unsaved: PackedStringArray
    if not %Settings.is_saved():
        unsaved.append('Behavior has unsaved project settings.')
    if not %Editor.is_saved():
        if unsaved.is_empty():
            unsaved.append('Behavior has unsaved resources:')
        else:
            unsaved.append('There are also unsaved resources:')
        unsaved.append_array(%Editor.get_unsaved())

    if not unsaved.is_empty():
        return ('\n'.join(unsaved)) + '\n\nWould you like to save everything?'

    return ''

func save_all() -> void:
    %Settings.save_all()
    %Editor.save_all()

func is_saved() -> bool:
    return %Settings.is_saved() and %Editor.is_saved()

func edit(res: Resource) -> void:
    %Settings.visible = false
    %Menu.visible = false

    %Editor.visible = true

    if res:
        %Editor.edit(res)


func show_editor() -> void:
    %Settings.visible = false
    %Menu.visible = false

    %Editor.visible = true


func show_settings() -> void:
    %Editor.visible = false
    %Menu.visible = false

    %Settings.visible = true


func show_menu() -> void:
    %Editor.visible = false
    %Settings.visible = false

    %Menu.visible = true
