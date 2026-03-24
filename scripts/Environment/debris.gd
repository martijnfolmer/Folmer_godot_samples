extends Node2D

@export_enum("wall", "glass") var cat = 0

@export_group("wall textures")
@export var sprite_wall_1 : Texture2D
@export var sprite_wall_2 : Texture2D
@export var sprite_wall_3 : Texture2D

@export_group("glass textures")
@export var sprite_glass_1 : Texture2D
@export var sprite_glass_2 : Texture2D
@export var sprite_glass_3 : Texture2D

@export_group("visual")
## the initial scale of the debris
@export var ini_scale : float = 1.0
## The friction with which it stops moving
@export var friction : float = 0.9

'''
todo:
	- scale (done)
	- glass and wall textures (done)
	- add to debris group (done)
	- initial rotation (done)
	
	- fall of the edge (non collision perhaps)
	- give impulse (velocity added to current velocity, and a bit of rotation)
	- update movement as well
	- rotation update when we are moving

	- initialization of the glass and wall
	-- looking partially like it is part of the class
	-- etending y scale as we are 'falling'
	-- overall scale goes down, so it looks like we are falling on the ground
'''


var sprite
var texture_1 : Texture2D
var texture_2 : Texture2D
var texture_3 : Texture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("debris")

	_create_debris_sprite()		# create the sprite for the debris from options
	_set_scale(ini_scale)	# the initial scale of the debris
	rotation = randf() * 2 * PI	#random initial roation
	

func _create_debris_sprite() -> void:
	# get the sprite2D
	sprite = $Sprite2D

	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
	
	_set_debris_sprite()

func _set_debris_sprite() -> void:
	
	if cat ==0:
		texture_1 = sprite_wall_1
		texture_2 = sprite_wall_2
		texture_3 = sprite_wall_3
	else:
		texture_1 = sprite_glass_1
		texture_2 = sprite_glass_2
		texture_3 = sprite_glass_3
	
	
	# edge case if we set no sprites
	if texture_1 == null and texture_2 == null and texture_3 == null:
		return
	
	# choose a random sprite from the texture 2D	
	sprite.texture = texture_1
	
	var all_sprites = []
	if texture_1!= null:
		all_sprites.append(texture_1)
	if texture_2 != null:
		all_sprites.append(texture_2)
	if texture_3 != null:
		all_sprites.append(texture_3)
	
	var choice_index = randi() % all_sprites.size()
	sprite.texture = all_sprites[choice_index]

## Set the scale of the sprite to the 	
func _set_scale(_scale) -> void:
	sprite.scale.x = _scale
	sprite.scale.y = _scale


	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
