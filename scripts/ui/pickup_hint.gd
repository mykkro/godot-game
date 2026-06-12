class_name PickupHint
extends CanvasLayer

var _label:  Label = null
var _avatar: Avatar = null


func setup(avatar: Avatar) -> void:
	_avatar = avatar


func _ready() -> void:
	layer = 60

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_bottom = -32
	anchor.offset_top    = -72
	add_child(anchor)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color",       Color(1.0, 0.95, 0.5))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	anchor.add_child(_label)


func _process(_delta: float) -> void:
	if _avatar == null:
		return
	var nearby := _avatar.get_nearest_pickable_name()
	if nearby.is_empty():
		_label.visible = false
	elif not _avatar.inventory.has_space():
		_label.text    = "Inventory full"
		_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		_label.visible = true
	else:
		_label.text    = "E  pick up  " + nearby
		_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		_label.visible = true
