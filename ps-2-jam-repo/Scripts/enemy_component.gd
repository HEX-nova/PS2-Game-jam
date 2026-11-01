extends Node3D

@export_group("Enemy Stats")
@export var health: float = 100.0
@export var max_health: float = 100.0
var alive: bool = true

func take_damage(damage: float):
	health -= damage
	if health <= 0.0:
		alive = false
