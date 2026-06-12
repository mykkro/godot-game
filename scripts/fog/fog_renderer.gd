class_name FogRenderer
extends Node2D

## Mirror chunk constants for readability.
const CHUNK_SIZE       := ChunkData.CHUNK_SIZE
const CHUNK_PIXEL_SIZE := ChunkData.CHUNK_PIXEL_SIZE

## RGBA8 pixel values [R, G, B, A] for each fog level (0-3).
## The image is 16x16 and stretched to 1024x1024 with LINEAR filter,
## so Godot blends between adjacent levels automatically, producing
## smooth circular fog gradients at no extra cost.
const _FOG_PIXEL: Array = [
	[0, 0, 10, 242],  # 0 – UNEXPLORED : near-black, 95 % opaque
	[0, 0, 10, 153],  # 1 – DIM        : dark,       60 % opaque
	[0, 0, 10,  64],  # 2 – PARTIAL    : medium,     25 % opaque
	[0, 0,  0,   0],  # 3 – VISIBLE    : transparent
]

var _image:   Image        = null
var _texture: ImageTexture = null


func _ready() -> void:
	# Enable bilinear filtering so the 16x16 fog scales smoothly to 1024x1024.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Call once immediately after adding this node to the scene tree.
func initialize(fog_data: FogData) -> void:
	_image = Image.create(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	_rebuild_image(fog_data)
	_texture = ImageTexture.create_from_image(_image)
	queue_redraw()


## Call whenever the underlying FogData has changed; pushes the update to GPU.
func refresh(fog_data: FogData) -> void:
	if _image == null or _texture == null:
		initialize(fog_data)
		return
	_rebuild_image(fog_data)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture,
			Rect2(Vector2.ZERO, Vector2(CHUNK_PIXEL_SIZE, CHUNK_PIXEL_SIZE)), false)


# ── Private ──────────────────────────────────────────────────────────────────

func _rebuild_image(fog_data: FogData) -> void:
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var level := fog_data.get_level(x, y)
			var p: Array = _FOG_PIXEL[level]
			_image.set_pixel(x, y, Color8(p[0], p[1], p[2], p[3]))
