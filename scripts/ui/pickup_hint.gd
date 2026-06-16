class_name PickupHint
extends CanvasLayer

var _label:     Label  = null
var _avatar:    Avatar = null
var _msg_timer: float  = 0.0
var _msg_text:  String = ""


func setup(avatar: Avatar) -> void:
	_avatar = avatar


## Show a transient message for 3 seconds (overrides the normal hint).
func show_message(text: String) -> void:
	_msg_text  = text
	_msg_timer = 3.0


func _ready() -> void:
	layer = 60

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_bottom = -72   # clear the belt strip (which ends 64 px above bottom)
	anchor.offset_top    = -112
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


func _process(delta: float) -> void:
	if _avatar == null:
		return

	# Transient fight-response message takes priority over everything.
	if _msg_timer > 0.0:
		_msg_timer -= delta
		_label.text    = _msg_text
		_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
		_label.visible = true
		return

	# Monster nearby → show F hint with species name.
	var nearby_monster := _avatar.get_nearby_monster()
	if nearby_monster != null:
		_label.text    = "F  fight  " + nearby_monster.species
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		_label.visible = true
		return

	# NPC interaction takes priority over chest/pickup.
	if _avatar.get_interactable_npc() != null:
		_label.text    = "E  talk"
		_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
		_label.visible = true
		return
	# Chest interaction takes priority over item pickup.
	if _avatar.get_interactable_chest() != null:
		_label.text    = "E  open"
		_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		_label.visible = true
		return
	var nearby      := _avatar.get_nearest_pickable_name()
	var nearby_type := _avatar.get_nearest_pickable_type()
	if nearby.is_empty():
		_label.visible = false
	elif not _avatar.inventory.has_space(nearby_type):
		_label.text    = "Inventory full"
		_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		_label.visible = true
	else:
		_label.text    = "E  pick up  " + nearby
		_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		_label.visible = true
