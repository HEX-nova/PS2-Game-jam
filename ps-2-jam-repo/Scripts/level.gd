extends Node3D

@export_group("Dungeon")
@export var size: Vector2i = Vector2i(10, 10)
@export_range(1, 1000) var target_tiles: int = 35
@export var generate_on_ready: bool = true

@export_group("Enemies")
@export var turret_scene: PackedScene

@export_group("Scenes")
@export var tile_scene: PackedScene
@export var wall_scene: PackedScene
@export var pillar_scene: PackedScene

@export_group("Player")
@export var player_scene: PackedScene
@export var player_spawn_height: float = 0.5
var player_instance: CharacterBody3D
var player_spawn_position: Vector3

var start_cell: Vector2i

const TILE_SIZE := 2.0

# Directions in grid coordinates.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

var dungeon: Dictionary = {}
var generated_root: Node3D


func _ready() -> void:
	add_to_group("DungeonManager")

	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)

	if generate_on_ready:
		generate_dungeon()

func generate_dungeon() -> void:
	if size.x <= 0 or size.y <= 0:
		return

	if tile_scene == null or wall_scene == null or pillar_scene == null:
		push_error("Assign all three dungeon scenes!")
		return

	if is_instance_valid(generated_root):
		generated_root.queue_free()

	generated_root = Node3D.new()
	generated_root.name = "GeneratedDungeon"
	add_child(generated_root)

	dungeon.clear()

	generate_layout()
	build_dungeon()
	spawn_player()
	spawn_enemies()


# --------------------------------------------------
# RANDOM WALK
# --------------------------------------------------

func generate_layout() -> void:
	start_cell = Vector2i(size.x / 2, size.y / 2)
	var current := start_cell

	dungeon[start_cell] = true

	var max_tiles := mini(target_tiles, size.x * size.y)

	while dungeon.size() < max_tiles:
		var direction: Vector2i = DIRECTIONS.pick_random()
		var next: Vector2i = current + direction

		# Stay inside the exported generation bounds.
		if next.x < 0 or next.x >= size.x:
			continue

		if next.y < 0 or next.y >= size.y:
			continue

		current = next
		dungeon[current] = true


# --------------------------------------------------
# BUILD
# --------------------------------------------------

func build_dungeon() -> void:
	var placed_pillars: Dictionary = {}

	for cell: Vector2i in dungeon:

		var world_pos := Vector3(
			cell.x * TILE_SIZE,
			0.0,
			cell.y * TILE_SIZE
		)

		# FLOOR
		var tile := tile_scene.instantiate() as Node3D
		generated_root.add_child(tile)
		tile.position = world_pos

		# NEIGHBOURS
		var north := cell + Vector2i.UP
		var south := cell + Vector2i.DOWN
		var west := cell + Vector2i.LEFT
		var east := cell + Vector2i.RIGHT

		# WALLS
		# North and south walls run along local X.
		if not dungeon.has(north):
			place_wall(
				world_pos + Vector3(0, 0, -1),
				0.0
			)

		if not dungeon.has(south):
			place_wall(
				world_pos + Vector3(0, 0, 1),
				0.0
			)

		# East and west walls run along local Z.
		if not dungeon.has(west):
			place_wall(
				world_pos + Vector3(-1, 0, 0),
				PI / 2.0
			)

		if not dungeon.has(east):
			place_wall(
				world_pos + Vector3(1, 0, 0),
				PI / 2.0
			)

		# PILLARS
		# Four corners, shared between neighbouring tiles.
		var corners: Array[Vector2i] = [
			Vector2i(cell.x * 2 - 1, cell.y * 2 - 1),
			Vector2i(cell.x * 2 + 1, cell.y * 2 - 1),
			Vector2i(cell.x * 2 - 1, cell.y * 2 + 1),
			Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		]

		for corner: Vector2i in corners:
			if placed_pillars.has(corner):
				continue

			placed_pillars[corner] = true

			var pillar := pillar_scene.instantiate() as Node3D
			generated_root.add_child(pillar)

			pillar.position = Vector3(
				corner.x,
				1.25,
				corner.y
			)


# --------------------------------------------------
# WALL PLACEMENT
# --------------------------------------------------

func place_wall(pos: Vector3, rotation_y: float) -> void:
	var wall := wall_scene.instantiate() as Node3D
	generated_root.add_child(wall)

	wall.position = pos + Vector3(0, 1.25, 0)
	wall.rotation.y = rotation_y + PI / 2.0


# --------------------------------------------------
# SPAWNS (PLAYER & ENEMIES)
# --------------------------------------------------

func spawn_player() -> void:
	if player_scene == null:
		push_error("Assign a player scene!")
		return

	player_instance = player_scene.instantiate() as CharacterBody3D

	# Remember the original spawn position.
	player_spawn_position = to_global(Vector3(
		start_cell.x * TILE_SIZE,
		player_spawn_height,
		start_cell.y * TILE_SIZE
	))

	player_instance.global_position = player_spawn_position
	player_instance.scale = Vector3(0.5, 0.5, 0.5)

	add_child(player_instance)

func spawn_enemies() -> void:
	if turret_scene == null:
		return

	# Grab all generated tiles
	var available_cells: Array = dungeon.keys()
	
	# Remove the player's start cell so the turret doesn't spawn right on top of them
	available_cells.erase(start_cell)

	if available_cells.is_empty():
		return

	# Pick a random tile from the remaining ones
	var turret_cell: Vector2i = available_cells.pick_random()

	var turret := turret_scene.instantiate() as Node3D
	generated_root.add_child(turret)

	turret.position = Vector3(
		turret_cell.x * TILE_SIZE,
		0.0,
		turret_cell.y * TILE_SIZE
	)

func _on_player_died() -> void:
	print("PLAYER DIED! RESPAWNING...")

	# Give the player a moment before respawning.
	await get_tree().create_timer(1.5).timeout

	if not is_instance_valid(player_instance):
		return

	# Return player to original spawn position.
	player_instance.global_position = player_spawn_position

	# Reset movement velocity.
	player_instance.velocity = Vector3.ZERO

	# Restore health.
	GameManager.respawn()
	print("PLAYER RESPAWNED!")
