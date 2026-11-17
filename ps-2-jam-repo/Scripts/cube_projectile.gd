extends Area3D

@export var speed: float = 10.0
var travel_direction: Vector3 = Vector3.FORWARD
var shooter: CollisionObject3D
var spent: bool = false


func _ready() -> void:
	collision_mask |= 1
	monitoring = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	await get_tree().create_timer(5.0).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	if spent:
		return

	var start := global_position
	var end := start - global_transform.basis.z * speed * delta

	var excluded: Array[RID] = []
	if is_instance_valid(shooter):
		excluded.append(shooter.get_rid())

	var query := PhysicsRayQueryParameters3D.create(
		start,
		end,
		collision_mask,
		excluded
	)

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		_on_body_entered(hit["collider"])
	else:
		global_position = end


func _on_body_entered(body: Node3D) -> void:
	if spent or body == shooter:
		return

	spent = true

	if body.is_in_group("Player"):
		GameManager.take_damage(10)

	queue_free()
		
func set_shooter(body: CollisionObject3D) -> void:
	shooter = body
