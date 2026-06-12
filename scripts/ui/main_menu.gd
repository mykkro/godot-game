extends Control

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _btn_continue: Button = $VBox/BtnContinue
@onready var _btn_new:      Button = $VBox/BtnNew
@onready var _btn_quit:     Button = $VBox/BtnQuit


func _ready() -> void:
	# "Continue" is only enabled when a save exists.
	_btn_continue.disabled = not SaveManager.has_save()

	_btn_new.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_quit.pressed.connect(_on_quit)


func _on_new_game() -> void:
	SaveManager.wipe()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_continue() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_quit() -> void:
	get_tree().quit()
