class_name HUD extends Control

@onready var score_value: Label = %score_value

@onready var health_bar: ProgressBar = %health_bar

@onready var ammo_load: Label = %ammo_load
@onready var ammo_stock: Label = %ammo_stock


func update_score(score: int) -> void:
    score_value.text = str(score)

func update_health(health: float) -> void:
    health_bar.value = health

func update_ammo(load: int, stock: int) -> void:
    ammo_load.text = str(load)
    ammo_stock.text = str(stock)
