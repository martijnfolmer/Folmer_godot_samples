extends Node2D


@export var sprite_1 : Texture2D
@export var sprite_2 : Texture2D
@export var sprite_3 : Texture2D


# TODO: scale, movement, off off edge, creatoin of this and setting sprite_1,2,3
# TODO: add to debris group

var sprite


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	_set_debris_sprite()		# create the sprite for the debris from options
	
	pass # Replace with function body.

func _set_debris_sprite() -> void:
	# get the sprite2D
	sprite = $Sprite2D

	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)

	# edge case if we set no sprites
	if sprite_1 == null and sprite_2 == null and sprite_3 == null:
		return
	
	# choose a random sprite from the texture 2D	
	sprite.texture = sprite_1
	
	var all_sprites = []
	if sprite_1!= null:
		all_sprites.append(sprite_1)
	if sprite_2 != null:
		all_sprites.append(sprite_2)
	if sprite_3 != null:
		all_sprites.append(sprite_3)
	
	var choice_index = randi() % all_sprites.size()
	sprite.texture = all_sprites[choice_index]
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
