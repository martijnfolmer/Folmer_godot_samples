extends GPUParticles2D
"""
	Particle effect that spawns wall shards when the wall is destroyed.
"""

# How far to push the particle emitter away from the wall surface,
# so the shards appear slightly in front of the impact point.
@export var wall_push_offset: float = 6.0

# Optional shard textures that will be combined into a atlas
# and used by the particle system.
@export var tex1: Texture2D
@export var tex2: Texture2D
@export var tex3: Texture2D


func _ready() -> void:
	# Configure the particle system to play only once per trigger.
	one_shot = true

	# Do not emit particles immediately when the node enters the scene.
	emitting = false


func setup_impact(impact_global_pos: Vector2, away_from_surface: Vector2) -> void:
	# Normalize the direction pointing away from the wall/glass surface
	# This direction is used both for positioning and orienting the emitter
	var away_dir := away_from_surface.normalized()

	# If the input direction was zero, fall back to pointing right
	if away_dir.length_squared() == 0.0:
		away_dir = Vector2.RIGHT

	global_position = impact_global_pos + away_dir * wall_push_offset

	# local orientation towards kick angle
	rotation = away_dir.angle()

	# shard atlas for multiple textures in the particle system
	var built = _build_shard_atlas()
	if built != null:
		texture = built.texture

	# Access the particle process material so we can tune how shards behave.
	var mat := process_material as ParticleProcessMaterial
	if mat != null:
		# Spread particles
		mat.spread = 90

		# Allow particles to start at any visual angle.
		mat.angle_min = 0.0
		mat.angle_max = 360.0

		# Randomize shard size
		mat.scale_min = 0.02 * 0.3
		mat.scale_max = 0.07 * 0.3

	# Restart the particle system so it emits from a clean state.
	restart()

	# Start emission now that the impact has been configured.
	emitting = true


# Small helper class used to return both the generated atlas texture
# and the number of frames it contains.
class ShardAtlas:
	var texture: Texture2D
	var frames: int


func _build_shard_atlas() -> Variant:
	# Collect all non-null source textures into an array
	var src_tex: Array[Texture2D] = []
	if tex1 != null:
		src_tex.append(tex1)
	if tex2 != null:
		src_tex.append(tex2)
	if tex3 != null:
		src_tex.append(tex3)

	# If no textures were provided, there is nothing to build
	if src_tex.is_empty():
		return null

	# This array will hold the source images extracted from the textures
	var images: Array[Image] = []

	# Track the maximum width and height of all source images, each cell uses max size
	var cell_w := 0
	var cell_h := 0

	for t in src_tex:
		# Convert the texture into an Image so we can process pixels directly
		var im := t.get_image()
		if im == null:
			continue

		# Ensure the image is in RGBA8 format, which is suitable for atlas creation
		if im.get_format() != Image.FORMAT_RGBA8:
			im = im.duplicate()
			im.convert(Image.FORMAT_RGBA8)

		# Expand the target cell size to fit the largest source image seen so far
		cell_w = maxi(cell_w, im.get_width())
		cell_h = maxi(cell_h, im.get_height())

		# Store the processed image
		images.append(im)

	# If all textures failed to produce valid images, return null
	if images.is_empty():
		return null

	# Number of shard images we store in the atlas
	var n := images.size()

	# Create an empty atlas image wide enough to store all frames in one row
	var atlas_im := Image.create(cell_w * n, cell_h, false, Image.FORMAT_RGBA8)

	# Fill it with transparent pixels so unused space stays invisible
	atlas_im.fill(Color(0, 0, 0, 0))

	# Copy each source image into its own cell in the atlas
	for i in n:
		var im := images[i]

		# Double-check format consistency before further processing
		if im.get_format() != Image.FORMAT_RGBA8:
			im = im.duplicate()
			im.convert(Image.FORMAT_RGBA8)

		# Original source size
		var sw := im.get_width()
		var sh := im.get_height()

		# Compute a uniform scale so the image fits inside the target cell
		# while preserving aspect ratio.
		var fit_scale: float = minf(float(cell_w) / float(sw), float(cell_h) / float(sh))

		# Calculate the resized dimensions, ensuring neither becomes 0
		var scaled_w: int = maxi(1, int(floor(sw * fit_scale)))
		var scaled_h: int = maxi(1, int(floor(sh * fit_scale)))

		# Duplicate and resize the image to fit into the atlas cell.
		var piece := im.duplicate()
		piece.resize(scaled_w, scaled_h, Image.INTERPOLATE_BILINEAR)

		# Center the resized shard inside its atlas cell.
		var ox := (cell_w - scaled_w) / 2.0
		var oy := (cell_h - scaled_h) / 2.0

		# Copy the resized shard into the correct horizontal slot in the atlas.
		atlas_im.blit_rect(
			piece,
			Rect2i(0, 0, scaled_w, scaled_h),
			Vector2i(int(i * cell_w + ox), int(oy))
		)

	# Package the atlas texture and frame count into a helper object.
	var out := ShardAtlas.new()
	out.texture = ImageTexture.create_from_image(atlas_im)
	out.frames = n

	return out
