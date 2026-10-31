
extends Node

# ==========================================
# SIGNALS
# ==========================================

signal health_changed(current: float, maximum: float)
signal points_changed(new_amount: int)
signal coins_changed(new_amount: int)
signal experience_changed(new_amount: int)
signal player_died


# ==========================================
# PLAYER STATS
# ==========================================

@export_group("Health")

var max_health: float = 100.0
var health: float = 100.0

var is_dead: bool = false
var invulnerability_timer: float = 0.0

# ==========================================
# PLAYER RESOURCES
# ==========================================

@export_group("Resources")

var points: int = 0
var coins: int = 0
var experience: int = 0


# ==========================================
# HEALTH FUNCTIONS
# ==========================================

func take_damage(amount: float) -> void:
	if is_dead or invulnerability_timer > 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)

	print("PLAYER DAMAGE: ", amount)
	print("HEALTH: ", health, "/", max_health)

	if health <= 0.0:
		is_dead = true
		player_died.emit()
		print("PLAYER DIED!")

func heal(amount: float) -> void:
	if is_dead:
		return

	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)

func increase_max_health(amount: float) -> void:
	max_health += amount
	health = minf(health + amount, max_health)

	health_changed.emit(health, max_health)

func respawn() -> void:
	health = max_health
	is_dead = false

	health_changed.emit(health, max_health)

# ==========================================
# POINTS
# ==========================================

func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)

	print("POINTS: ", points)

# ==========================================
# COINS
# ==========================================

func add_coins(amount: int) -> void:
	if amount <= 0:
		return

	coins += amount
	coins_changed.emit(coins)

	print("COINS: ", coins)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false

	coins -= amount
	coins_changed.emit(coins)

	print("COINS: ", coins)
	return true

# ==========================================
# EXPERIENCE
# ==========================================

func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	experience += amount
	experience_changed.emit(experience)

	print("EXPERIENCE: ", experience)

# ==========================================
# RESET
# ==========================================

func reset_run() -> void:
	health = max_health
	is_dead = false

	points = 0
	coins = 0
	experience = 0

	health_changed.emit(health, max_health)
	points_changed.emit(points)
	coins_changed.emit(coins)
	experience_changed.emit(experience)

	print("NEW RUN STARTED!")

func _process(delta: float) -> void:
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
