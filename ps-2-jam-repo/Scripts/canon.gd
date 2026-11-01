
extends Node3D

@export_group("Weapon")
@export var damage: float = 25.0
@export var shoot_range: float = 100.0
@export var fire_rate: float = 0.25
@export var energy_cost: float = 20.0

@export_group("Weapon Effects")
@export var recoil_distance: float = 0.12
@export var recoil_speed: float = 12.0
@export var flash_duration: float = 0.06

var camera: Camera3D
var cooldown: float = 0.0

var original_position: Vector3
var recoil_position: Vector3 = Vector3.ZERO

@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@export var impact_scene: PackedScene


func _ready() -> void:
	print("================================")
	print("CANNON READY!")
	print("================================")

	original_position = position
	muzzle_flash.visible = false

	camera = get_viewport().get_camera_3d()

	if camera:
		print("CAMERA FOUND: ", camera.name)
	else:
		push_error("NO ACTIVE CAMERA FOUND!")


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	#recoil here
	recoil_position = recoil_position.lerp(
		Vector3.ZERO,
		minf(recoil_speed * delta, 1.0)
	)
	position = original_position + recoil_position
	# Shooting input.
	if Input.is_action_just_pressed("fire") and cooldown <= 0.0 and GameManager.energy >= energy_cost:
		GameManager.energy -= energy_cost
		shoot()


func shoot() -> void:
	if camera == null:
		return

	cooldown = fire_rate

	print("PEW!")

	weapon_effects()

	# Camera center raycast.
	var center := get_viewport().get_visible_rect().size / 2.0

	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * shoot_range
	)

	# Exclude the player.
	var node: Node = camera

	while node != null and not (node is CharacterBody3D):
		node = node.get_parent()

	if node is CollisionObject3D:
		query.exclude = [node.get_rid()]

	# Perform raycast.
	var space := get_world_3d().direct_space_state
	var result := space.intersect_ray(query)

	if not result.is_empty():
		print("HIT: ", result.collider.name)
		spawn_impact(result.position, result.normal)

		var collider = result.collider
		var enemy_comp = null

		# Since DamageDetector and EnemyComponent are siblings under Turret, 
		# we check the parent of the collider to find the EnemyComponent!
		var parent = collider.get_parent()
		if parent and parent.has_node("EnemyComponent"):
			enemy_comp = parent.get_node("EnemyComponent")

		# If we found it, deal damage!
		if enemy_comp and enemy_comp.has_method("take_damage"):
			enemy_comp.take_damage(damage)
			print("Dealt damage! Current health: ", enemy_comp.health)
			
			if enemy_comp.health <= 0.0:
				parent.queue_free() # Vaporize the Turret root!
				print("Turret destroyed!")
	else:
		print("HIT NOTHING!")

func weapon_effects() -> void:
	# recoil back
	recoil_position.z = recoil_distance
	# flash
	muzzle_flash.visible = true
	await get_tree().create_timer(flash_duration).timeout
	muzzle_flash.visible = false

func spawn_impact(hit_position: Vector3, hit_normal: Vector3) -> void:
	if impact_scene == null:
		return
	var particles := impact_scene.instantiate() as GPUParticles3D
	get_tree().current_scene.add_child(particles)
	particles.global_position = hit_position + hit_normal * 0.02
	particles.emitting = true
	await particles.finished
	particles.queue_free()
