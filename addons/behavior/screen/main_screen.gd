@tool
extends Control


func _ready() -> void:
    %Menu.new_resource.connect(edit)
    %Menu.goto_settings.connect(show_settings)
    %Menu.goto_editor.connect(show_editor)

    %Settings.goto_menu.connect(show_menu)

    %Editor.goto_menu.connect(show_menu)

    show_menu()


func edit(res: Resource) -> void:
    %Settings.visible = false
    %Menu.visible = false

    %Editor.visible = true
    %Editor.edit(res)


func show_editor() -> void:
    %Settings.visible = false
    %Menu.visible = false

    %Editor.visible = true


func show_settings() -> void:
    %Editor.visible = false
    %Menu.visible = false

    %Settings.visible = true
    %Settings.refresh_groups()


func show_menu() -> void:
    %Editor.visible = false
    %Settings.visible = false

    %Menu.visible = true
