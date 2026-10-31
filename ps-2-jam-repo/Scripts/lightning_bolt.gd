
extends MeshInstance3D

@export_group("Lightning Shape")
@export var segment_length: float = 0.5
@export var jaggedness: float = 0.35
@export var bolt_width: float = 0.035

@export_group("Lightning Effects")
@export var duration: float = 0.15
@export var lightning_material: Material


func strike(start_pos: Vector3, end_pos: Vector3) -> void:
	# Reset transform so vertices use world coordinates.
	global_transform = Transform3D.IDENTITY

	var points: Array[Vector3] = []
	points.append(start_pos)

	var direction := (end_pos - start_pos).normalized()
	var distance := start_pos.distance_to(end_pos)

	# Find two perpendicular directions for the zigzags.
	var side := direction.cross(Vector3.UP).normalized()

	if side.length_squared() < 0.01:
		side = direction.cross(Vector3.RIGHT).normalized()

	var other_side := direction.cross(side).normalized()

	# Calculate the number of segments from distance.
	var segment_count := maxi(
		1,
		ceili(distance / maxf(segment_length, 0.01))
	)

	# Generate fixed-spacing zigzag points.
	for i in range(1, segment_count):
		var t := float(i) / float(segment_count)

		var point := start_pos.lerp(end_pos, t)

		point += side * randf_range(-jaggedness, jaggedness)
		point += other_side * randf_range(-jaggedness, jaggedness)

		points.append(point)

	points.append(end_pos)

	# Build the 3D lightning mesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if lightning_material:
		st.set_material(lightning_material)

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]

		var segment_direction := (b - a).normalized()

		var axis_a := segment_direction.cross(Vector3.UP).normalized()

		if axis_a.length_squared() < 0.01:
			axis_a = segment_direction.cross(Vector3.RIGHT).normalized()

		var axis_b := segment_direction.cross(axis_a).normalized()

		var r := bolt_width * 0.5

		var a1 := a + axis_a * r
		var a2 := a - axis_a * r
		var a3 := a + axis_b * r
		var a4 := a - axis_b * r

		var b1 := b + axis_a * r
		var b2 := b - axis_a * r
		var b3 := b + axis_b * r
		var b4 := b - axis_b * r

		# Four-sided 3D lightning segment.
		add_quad(st, a1, a3, b3, b1)
		add_quad(st, a3, a2, b2, b3)
		add_quad(st, a2, a4, b4, b2)
		add_quad(st, a4, a1, b1, b4)

	st.generate_normals()
	mesh = st.commit()

	# Remove lightning after its lifetime.
	await get_tree().create_timer(duration).timeout
	queue_free()


func add_quad(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)

	st.set_uv(Vector2.RIGHT)
	st.add_vertex(b)

	st.set_uv(Vector2.ONE)
	st.add_vertex(c)

	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)

	st.set_uv(Vector2.ONE)
	st.add_vertex(c)

	st.set_uv(Vector2.DOWN)
	st.add_vertex(d)
