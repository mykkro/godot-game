class_name BattleDialog
extends CanvasLayer

signal battle_won(monster: MonsterNode)
signal battle_lost(monster: MonsterNode)
signal battle_fled

const LOG_MAX   := 6    # visible log lines kept
const FLEE_ODDS := 0.50 # probability of successful flee

enum _State { CHOOSING, WIN, LOSE, FLED }

var _hero:         HeroStats   = null
var _monster:      MonsterNode = null
var _defend_bonus: bool        = false
var _perks:        CharacterPerks = null
var _state:        _State      = _State.CHOOSING

## UI nodes
var _overlay:       Control       = null
var _mon_sprite:    TextureRect   = null
var _mon_name:      Label         = null
var _mon_hp_bar:    ProgressBar   = null
var _mon_hp_lbl:    Label         = null
var _log_vbox:      VBoxContainer = null
var _hero_hp_bar:   ProgressBar   = null
var _hero_hp_lbl:   Label         = null
var _hero_mp_bar:   ProgressBar   = null
var _hero_mp_lbl:   Label         = null
var _btn_attack:    Button        = null
var _btn_defend:    Button        = null
var _btn_flee:      Button        = null
var _result_lbl:    Label         = null
var _ok_btn:        Button        = null


func _ready() -> void:
	layer        = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func open(monster: MonsterNode, hero: HeroStats, perks: CharacterPerks) -> void:
	_hero          = hero
	_monster       = monster
	_perks         = perks
	_defend_bonus  = false
	_state         = _State.CHOOSING

	_mon_sprite.texture = TextureCache.get_being_texture(monster.species)
	_mon_name.text      = monster.species

	_mon_hp_bar.max_value = monster.max_hp
	_mon_hp_bar.value     = monster.current_hp

	_hero_hp_bar.max_value = hero.max_hp
	_hero_mp_bar.max_value = hero.max_mana

	_clear_log()
	_add_log("A %s appears!" % monster.species)

	_set_action_ui(true)
	_result_lbl.visible = false
	_ok_btn.visible     = false
	_refresh_bars()
	_overlay.visible    = true
	get_tree().paused   = true


func close() -> void:
	_overlay.visible  = false
	get_tree().paused = false


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_attack() -> void:
	_set_action_ui(false)
	_defend_bonus = false
	var eff_atk := _hero.attack
	if _perks != null:
		var berk_lv := _perks.get_level(PerkDef.ID.BERSERKER)
		if berk_lv > 0 and float(_hero.current_hp) / float(_hero.max_hp) < 0.30:
			var bonus := PerkDef.get_berserker_bonus(berk_lv)
			eff_atk += bonus
			_add_log("Berserker rage!  +%d attack." % bonus)
	var dmg := _calc_damage(eff_atk, _monster.defense)
	_monster.current_hp = maxi(0, _monster.current_hp - dmg)
	_add_log("You strike %s for %d damage." % [_monster.species, dmg])
	_refresh_bars()
	if _monster.current_hp <= 0:
		_finish(_State.WIN)
		return
	_monster_turn()


func _on_defend() -> void:
	_set_action_ui(false)
	_defend_bonus = true
	_add_log("You brace yourself.")
	_monster_turn()


func _on_flee() -> void:
	_set_action_ui(false)
	if randf() < FLEE_ODDS:
		_add_log("You flee successfully!")
		_finish(_State.FLED)
	else:
		_add_log("You can't escape!")
		_monster_turn()


func _monster_turn() -> void:
	var eff_def := _hero.defense * (2 if _defend_bonus else 1)
	var dmg     := _calc_damage(_monster.attack, eff_def)
	_hero.take_damage(dmg)
	_add_log("%s hits you for %d damage." % [_monster.species, dmg])
	_defend_bonus = false
	_refresh_bars()
	if _hero.is_dead():
		_finish(_State.LOSE)
	else:
		_set_action_ui(true)


static func _calc_damage(atk: int, def: int) -> int:
	var base := maxi(1, atk - def)
	return int(round(float(base) * randf_range(0.85, 1.15)))


func _finish(state: _State) -> void:
	_state = state
	match state:
		_State.WIN:
			if _perks != null:
				var vamp_lv := _perks.get_level(PerkDef.ID.VAMPIRIC)
				if vamp_lv > 0:
					var heal := PerkDef.get_vampiric_heal(vamp_lv)
					_hero.heal(heal)
					_add_log("You drain %d HP." % heal)
			_result_lbl.text = "Victory!  +%d XP" % _monster.xp_reward
			_result_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4))
		_State.LOSE:
			_result_lbl.text                   = "You were defeated..."
			_result_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_State.FLED:
			_result_lbl.text                   = "You fled!"
			_result_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_result_lbl.visible = true
	_ok_btn.visible     = true
	_ok_btn.grab_focus()


func _on_ok() -> void:
	close()
	match _state:
		_State.WIN:
			battle_won.emit(_monster)
		_State.LOSE:
			battle_lost.emit(_monster)
		_State.FLED:
			battle_fled.emit()


# ── Log helpers ───────────────────────────────────────────────────────────────

func _clear_log() -> void:
	for c in _log_vbox.get_children():
		c.queue_free()


func _add_log(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	_log_vbox.add_child(lbl)
	# remove_child first so get_child_count() drops immediately, then free
	while _log_vbox.get_child_count() > LOG_MAX:
		var oldest := _log_vbox.get_child(0)
		_log_vbox.remove_child(oldest)
		oldest.queue_free()


# ── Bar updates ───────────────────────────────────────────────────────────────

func _refresh_bars() -> void:
	if _monster != null:
		_mon_hp_bar.value = _monster.current_hp
		_mon_hp_lbl.text  = "%d / %d" % [_monster.current_hp, _monster.max_hp]
	if _hero != null:
		_hero_hp_bar.value = _hero.current_hp
		_hero_hp_lbl.text  = "%d / %d" % [_hero.current_hp, _hero.max_hp]
		_hero_mp_bar.value = _hero.current_mana
		_hero_mp_lbl.text  = "%d / %d" % [_hero.current_mana, _hero.max_mana]


func _set_action_ui(visible_flag: bool) -> void:
	_btn_attack.visible = visible_flag
	_btn_defend.visible = visible_flag
	_btn_flee.visible   = visible_flag
	if visible_flag:
		_btn_attack.grab_focus()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(center)

	var panel := _make_panel()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚔  BATTLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
	vbox.add_child(title)
	vbox.add_child(_hsep())

	# Monster row
	var mon_row := HBoxContainer.new()
	mon_row.add_theme_constant_override("h_separation", 14)
	vbox.add_child(mon_row)

	_mon_sprite = TextureRect.new()
	_mon_sprite.custom_minimum_size     = Vector2(56, 56)
	_mon_sprite.expand_mode             = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_mon_sprite.stretch_mode            = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon_row.add_child(_mon_sprite)

	var mon_info := VBoxContainer.new()
	mon_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mon_row.add_child(mon_info)

	_mon_name = Label.new()
	_mon_name.add_theme_font_size_override("font_size", 18)
	_mon_name.add_theme_color_override("font_color", Color(1.0, 0.55, 0.40))
	mon_info.add_child(_mon_name)

	var mon_hp_row := HBoxContainer.new()
	mon_hp_row.add_theme_constant_override("h_separation", 8)
	mon_info.add_child(mon_hp_row)

	var mon_hp_tag := Label.new()
	mon_hp_tag.text = "HP"
	mon_hp_tag.add_theme_font_size_override("font_size", 13)
	mon_hp_tag.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	mon_hp_row.add_child(mon_hp_tag)

	_mon_hp_bar = _make_bar(Color(0.90, 0.20, 0.15))
	_mon_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mon_hp_bar.custom_minimum_size   = Vector2(0, 14)
	mon_hp_row.add_child(_mon_hp_bar)

	_mon_hp_lbl = Label.new()
	_mon_hp_lbl.add_theme_font_size_override("font_size", 12)
	_mon_hp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_mon_hp_lbl.custom_minimum_size = Vector2(52, 0)
	_mon_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mon_hp_row.add_child(_mon_hp_lbl)

	vbox.add_child(_hsep())

	# Combat log
	var log_label := Label.new()
	log_label.text = "COMBAT LOG"
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.62))
	log_label.uppercase = true
	vbox.add_child(log_label)

	var log_bg := PanelContainer.new()
	log_bg.custom_minimum_size = Vector2(0, 88)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.05, 0.06, 0.10, 0.85)
	log_style.set_content_margin_all(6)
	log_bg.add_theme_stylebox_override("panel", log_style)
	vbox.add_child(log_bg)

	_log_vbox = VBoxContainer.new()
	_log_vbox.add_theme_constant_override("separation", 2)
	log_bg.add_child(_log_vbox)

	vbox.add_child(_hsep())

	# Hero stats row
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("h_separation", 16)
	vbox.add_child(hero_row)

	_build_hero_bar_col(hero_row, "HP", Color(0.20, 0.85, 0.30),
			func() -> ProgressBar: return _hero_hp_bar,
			func() -> Label:       return _hero_hp_lbl,
			func(b: ProgressBar) -> void: _hero_hp_bar = b,
			func(l: Label)       -> void: _hero_hp_lbl = l)

	_build_hero_bar_col(hero_row, "MP", Color(0.25, 0.55, 0.95),
			func() -> ProgressBar: return _hero_mp_bar,
			func() -> Label:       return _hero_mp_lbl,
			func(b: ProgressBar) -> void: _hero_mp_bar = b,
			func(l: Label)       -> void: _hero_mp_lbl = l)

	vbox.add_child(_hsep())

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("h_separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_btn_attack = _make_btn("⚔  Attack",  Color(0.90, 0.30, 0.20))
	_btn_defend = _make_btn("🛡  Defend",  Color(0.25, 0.55, 0.90))
	_btn_flee   = _make_btn("💨  Flee",    Color(0.55, 0.55, 0.55))
	_btn_attack.pressed.connect(_on_attack)
	_btn_defend.pressed.connect(_on_defend)
	_btn_flee.pressed.connect(_on_flee)
	btn_row.add_child(_btn_attack)
	btn_row.add_child(_btn_defend)
	btn_row.add_child(_btn_flee)

	# Result label + OK button
	_result_lbl = Label.new()
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.add_theme_font_size_override("font_size", 18)
	_result_lbl.visible = false
	vbox.add_child(_result_lbl)

	_ok_btn = _make_btn("  OK  ", Color(0.40, 0.80, 0.50))
	_ok_btn.visible = false
	_ok_btn.pressed.connect(_on_ok)
	_ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_ok_btn)

	_overlay.visible = false


func _build_hero_bar_col(
		parent: HBoxContainer,
		tag: String,
		color: Color,
		_get_bar: Callable,
		_get_lbl: Callable,
		set_bar: Callable,
		set_lbl: Callable,
) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	parent.add_child(col)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.add_theme_font_size_override("font_size", 12)
	tag_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.72))
	col.add_child(tag_lbl)

	var bar := _make_bar(color)
	bar.custom_minimum_size = Vector2(0, 14)
	col.add_child(bar)
	set_bar.call(bar)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	col.add_child(val_lbl)
	set_lbl.call(val_lbl)


# ── Style helpers ─────────────────────────────────────────────────────────────

static func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color         = Color(0.06, 0.06, 0.11, 0.97)
	s.border_color     = Color(0.50, 0.35, 0.20, 0.90)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	return p


static func _make_bar(fill_color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.18)
	bg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill",       fill)
	pb.add_theme_stylebox_override("background", bg)
	return pb


static func _make_btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(110, 36)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	var normal := StyleBoxFlat.new()
	normal.bg_color = col.darkened(0.4)
	normal.border_color = col
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = col.darkened(0.2)
	var pressed_s := normal.duplicate() as StyleBoxFlat
	pressed_s.bg_color = col
	b.add_theme_stylebox_override("normal",   normal)
	b.add_theme_stylebox_override("hover",    hover)
	b.add_theme_stylebox_override("pressed",  pressed_s)
	b.add_theme_stylebox_override("focus",    hover)
	return b


static func _hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
	return s
