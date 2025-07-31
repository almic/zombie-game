class_name HUD extends Control

@onready var score_value: Label = %score_value
@onready var health_bar: ProgressBar = %health_bar

func update_score(score: int) -> void:
    score_value.text = str(score)

func update_health(health: float) -> void:
    health_bar.value = health
