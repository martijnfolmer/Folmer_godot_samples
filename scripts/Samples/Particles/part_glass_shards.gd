extends GPUParticles2D
"""
	Shards when the player is set
"""


@export var wall_push_offset: float = 6.0
@export var tex1: Texture2D
@export var tex2: Texture2D
@export var tex3: Texture2D


func _ready() -> void:
	one_shot = true
	emitting = false


func setup_impact(impact_global_pos: Vector2, away_from_surface: Vector2) -> void:
	var away_dir := away_from_surface.normalized()
	if away_dir.length_squared() == 0.0:
		away_dir = Vector2.RIGHT

	global_position = impact_global_pos + away_dir * wall_push_offset
	rotation = away_dir.angle()

	var built = _build_shard_atlas()
	if built != null:
		texture = built.texture
		#var h_frames = maxi(1, built.frames)
		#var v_frames = 1

	var mat := process_material as ParticleProcessMaterial
	if mat != null:
		mat.spread = 180.0
		mat.angle_min = 0.0
		mat.angle_max = 360.0
		mat.anim_speed_min = 0.0
		mat.anim_speed_max = 0.0
		mat.anim_offset_min = 0.0
		mat.anim_offset_max = 0.999
		mat.scale_min = 0.02
		mat.scale_max = 0.07

	restart()
	emitting = true


class ShardAtlas:
	var texture: Texture2D
	var frames: int


func _build_shard_atlas() -> Variant:
	var src_tex: Array[Texture2D] = []
	if tex1 != null:
		src_tex.append(tex1)
	if tex2 != null:
		src_tex.append(tex2)
	if tex3 != null:
		src_tex.append(tex3)
	if src_tex.is_empty():
		return null

	var images: Array[Image] = []
	var cell_w := 0
	var cell_h := 0
	for t in src_tex:
		var im := t.get_image()
		if im == null:
			continue
		if im.get_format() != Image.FORMAT_RGBA8:
			im = im.duplicate()
			im.convert(Image.FORMAT_RGBA8)
		cell_w = maxi(cell_w, im.get_width())
		cell_h = maxi(cell_h, im.get_height())
		images.append(im)

	if images.is_empty():
		return null

	var n := images.size()
	var atlas_im := Image.create(cell_w * n, cell_h, false, Image.FORMAT_RGBA8)
	atlas_im.fill(Color(0, 0, 0, 0))

	for i in n:
		var im := images[i]
		if im.get_format() != Image.FORMAT_RGBA8:
			im = im.duplicate()
			im.convert(Image.FORMAT_RGBA8)
		var sw := im.get_width()
		var sh := im.get_height()
		var fit_scale: float = minf(float(cell_w) / float(sw), float(cell_h) / float(sh))
		var scaled_w: int = maxi(1, int(floor(sw * fit_scale)))
		var scaled_h: int = maxi(1, int(floor(sh * fit_scale)))
		var piece := im.duplicate()
		piece.resize(scaled_w, scaled_h, Image.INTERPOLATE_BILINEAR)
		var ox := (cell_w - scaled_w) / 2.0
		var oy := (cell_h - scaled_h) / 2.0
		atlas_im.blit_rect(piece, Rect2i(0, 0, scaled_w, scaled_h), Vector2i(i * cell_w + ox, oy))

	var out := ShardAtlas.new()
	out.texture = ImageTexture.create_from_image(atlas_im)
	out.frames = n
	return out
