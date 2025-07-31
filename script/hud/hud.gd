class_name HUD extends Control

@onready var score_value: Label = %score_value

func update_score(score: int) -> void:
    score_value.text = str(score)
