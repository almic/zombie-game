@tool
class_name Photobooth extends SubViewport


@onready var camera_3d: Camera3D = %Camera3D


@export var filename: String = 'image'

@export var save_image: bool = false:
    set(value):
        if not value:
            save_image = false
            return

        save_image = true
        var filepath: String = 'res://scene/photobooth/' + filename + '.png'
        get_texture().get_image().save_png(filepath)
        save_image = false
