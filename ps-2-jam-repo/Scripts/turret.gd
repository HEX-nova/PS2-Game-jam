
extends Node3D

@export var rotation_speed: float = 5.0
@export var lightning_scene: PackedScene
@export var lightning_damage: int = 20

@onready var axis: Node3D = $Axis
@onready var barrel: Node3D = $Axis/Barrel
@onready var detection_area: Area3D = $Area3D
@onready var lightning_spawn: Marker3D = $"Axis/Barrel/Lightning Spawn"

var target_player: Node3D = null
@export var fire_interval: float = 1.5
var fire_timer: float = 0.0

func _process(delta: float) -> void:
	if not target_player:
		return

	var target_pos := target_player.global_position

	# YAW: Rotate toward the player.
	var horizontal_target := Vector3(
		target_pos.x,
		axis.global_position.y,
		target_pos.z
	)

	axis.look_at(horizontal_target, Vector3.UP)
	axis.rotate_y(-PI / 2.0)

	# PITCH: Aim barrel vertically.
	var local_pos := barrel.to_local(target_pos)
	var target_pitch := atan2(local_pos.y, -local_pos.z)

	barrel.rotation.x = lerp_angle(
		barrel.rotation.x,
		target_pitch,
		rotation_speed * delta
	)
	# Lock unwanted rotation axes.
	barrel.rotation.x = 0.0
	barrel.rotation.z = 0.0
	
	fire_timer -= delta
	if fire_timer <= 0:
		fire_lightning()
		fire_timer = fire_interval


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		target_player = body
		print("Target acquired: Player spotted!")


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == target_player:
		target_player = null
		print("Target lost!")


func fire_lightning() -> void:
	print("FIRING LIGHTNING!")

	if not target_player:
		print("NO TARGET!")
		return

	if lightning_scene == null:
		print("NO LIGHTNING SCENE ASSIGNED!")
		return

	var bolt = lightning_scene.instantiate()
	get_tree().current_scene.add_child(bolt)

	bolt.strike(
		lightning_spawn.global_position,
		target_player.global_position
	)
	GameManager.take_damage(lightning_damage)
