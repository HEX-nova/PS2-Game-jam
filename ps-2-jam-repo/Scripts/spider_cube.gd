extends CharacterBody3D

@export var speed: float = 2.5
@export var rotation_speed: float = 6.0
@export var projectile_scene: PackedScene
@export var shoot_cooldown: float = 2.0

var player: Node3D
var shoot_timer: float = 0.0

@onready var legs: Array[Node3D] = [
	$Legs/Leg1, $Legs/Leg2, $Legs/Leg3,
	$Legs/Leg4, $Legs/Leg5, $Legs/Leg6
]

func _ready() -> void:
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 1. Chase the player on the XZ plane
	var direction = (player.global_position - global_position)
	direction.y = 0.0
	direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()

	# Smoothly rotate to face the player
	if direction.length_squared() > 0.01:
		var target_rotation = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

	# 2. Procedural Leg Swinging (Hexapod Gait via Sine Waves)
	var is_moving = velocity.length_squared() > 0.1
	var time_val = Time.get_ticks_msec() * 0.015 if is_moving else 0.0
	
	for i in range(legs.size()):
		if legs[i]:
			var phase_offset = i * 1.25
			var swing = sin(time_val + phase_offset) * 0.4 if is_moving else 0.0
			legs[i].rotation.x = swing

	# 3. Projectile Shooting Logic
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		shoot_projectile()


func _on_enemy_defeated() -> void:
	queue_free()


func shoot_projectile() -> void:
	if not projectile_scene:
		return

	var proj = projectile_scene.instantiate() as Node3D
	var spawn_node = $ProjectileSpawner if has_node("ProjectileSpawner") else self
	get_tree().current_scene.add_child(proj)
	proj.global_position = spawn_node.global_position

	if is_instance_valid(player):
		var look_dir = (player.global_position - proj.global_position)
		# Prevent look_at crash if vector is zero
		if look_dir.length_squared() > 0.001:
			proj.look_at(proj.global_position + look_dir.normalized(), Vector3.UP)
