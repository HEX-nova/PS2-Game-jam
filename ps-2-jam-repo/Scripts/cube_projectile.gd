extends Area3D

@export var speed: float = 10.0
var travel_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	if GameManager.current_level >= 6:
		collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# Auto-destroy after 5 seconds so it doesn't leak memory
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _process(delta: float) -> void:
	# Move forward along its local orientation
	transform.origin -= transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		GameManager.take_damage(10)
		queue_free()
	else:
		queue_free()
