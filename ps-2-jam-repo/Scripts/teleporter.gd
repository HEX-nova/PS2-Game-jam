extends Area3D

@export var level: PackedScene
@onready var vis: Sprite3D = $Sprite3D
@export var spin: float = 2.0

func _process(delta: float) -> void:
	vis.rotation.z += spin * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		get_tree().change_scene_to_packed(level)
