@tool
extends Control


func _ready() -> void:
    %Menu.new_resource.connect(edit)
    %Menu.goto_settings.connect(show_settings)
    %Menu.visible = true

    %Editor.visible = false
    %Settings.visible = false


func edit(res: Resource) -> void:
    %Settings.visible = false
    %Menu.visible = false

    %Editor.visible = true
    %Editor.edit(res)


func show_settings() -> void:
    %Editor.visible = false
    %Menu.visible = false

    %Settings.visible = true
    %Settings.refresh_groups()
