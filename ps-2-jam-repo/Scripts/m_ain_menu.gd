extends Node2D

@export var start_scene: PackedScene

@onready var start_button: Button = $CanvasLayer/Start
@onready var exit_button: Button = $CanvasLayer/Exit

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	if start_scene:
		get_tree().change_scene_to_packed(start_scene)
	else:
		push_error("No start scene assigned in the inspector!")

func _on_exit_pressed() -> void:
	get_tree().quit()
