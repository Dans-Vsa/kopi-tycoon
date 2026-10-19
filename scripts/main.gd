extends Control
## Tampilan utama Kopi Tycoon. Node UI disusun di scene main.tscn,
## script ini memperbarui teks, mengatur fitur yang terkunci/terbuka,
## dan menangani klik tombol.

const GOLD := Color("f2c14e")
const LOCKED_ICON_COLOR := Color(0, 0, 0, 0.85)
const UPGRADE_UNLOCK_EARNED := 25.0
const PRESTIGE_UNLOCK_EARNED := 250_000.0

# --- Tata letak responsif (lihat DESIGN.md) ---
## Ukuran logis layar: lanskap untuk desktop, potret untuk ponsel.
## Dengan stretch aspect "expand", sisi yang lain menyesuaikan bentuk layar.
const LANDSCAPE_SIZE := Vector2i(1152, 648)
const PORTRAIT_SIZE := Vector2i(552, 960)
## [path node, ukuran font lanskap, ukuran font potret]
const FONT_SIZES := [
	["Margin/Columns/Left/Header/Title", 36, 26],
	["Margin/Columns/Left/Header/CoinPanel/CoinRow/CoinsLabel", 28, 30],
	["Margin/Columns/Left/RateLabel", 15, 19],
	["Margin/Columns/Left/BottomRow/ClickArea/ClickValueLabel", 15, 20],
	["Margin/Columns/Left/BottomRow/Actions/InfoLabel", 14, 18],
	["Margin/Columns/GeneratorPanel/Right/GeneratorTitle", 24, 28],
	["Margin/Columns/GeneratorPanel/Right/BottomBar/ResetButton", 14, 20],
	["Margin/Columns/GeneratorPanel/Right/BottomBar/SoundToggle", 14, 20],
	["UnlockBanner/BannerLabel", 20, 24],
]
## [path node, ukuran minimum lanskap, ukuran minimum potret]
const MIN_SIZES := [
	["Margin/Columns/Left/Header/CoinPanel/CoinRow/CoinIcon", Vector2(36, 36), Vector2(44, 44)],
	["Margin/Columns/Left/BottomRow/ClickArea/ClickButton", Vector2(150, 140), Vector2(180, 168)],
	["Margin/Columns/Left/BottomRow/Actions/ClickUpgradeButton", Vector2(0, 62), Vector2(0, 78)],
	["Margin/Columns/Left/BottomRow/Actions/PrestigeButton", Vector2(0, 62), Vector2(0, 78)],
	["Margin/Columns/GeneratorPanel/Right/BottomBar/ResetButton", Vector2.ZERO, Vector2(0, 56)],
	["Margin/Columns/GeneratorPanel/Right/BottomBar/SoundToggle", Vector2.ZERO, Vector2(0, 56)],
]
const GENERATOR_BUTTON_HEIGHT := [66.0, 92.0]
const THEME_FONT_SIZE := [16, 22]
const THEME_ICON_WIDTH := [52, 60]

@onready var coins_label: Label = %CoinsLabel
@onready var rate_label: Label = %RateLabel
@onready var click_button: TextureButton = %ClickButton
@onready var click_value_label: Label = %ClickValueLabel
@onready var click_upgrade_button: Button = %ClickUpgradeButton
@onready var prestige_button: Button = %PrestigeButton
@onready var info_label: Label = %InfoLabel
@onready var generator_list: VBoxContainer = %GeneratorList
@onready var floating_texts: Control = %FloatingTexts
@onready var unlock_banner: PanelContainer = %UnlockBanner
@onready var banner_label: Label = %BannerLabel
@onready var prestige_dialog: ConfirmationDialog = %PrestigeDialog
@onready var sound_toggle: Button = %SoundToggle
@onready var reset_button: Button = %ResetButton
@onready var reset_dialog: ConfirmationDialog = %ResetDialog
@onready var cafe_view: Control = %CafeView
@onready var sfx_click: AudioStreamPlayer = %SfxClick
@onready var sfx_buy: AudioStreamPlayer = %SfxBuy
@onready var sfx_upgrade: AudioStreamPlayer = %SfxUpgrade
@onready var sfx_prestige: AudioStreamPlayer = %SfxPrestige
@onready var music: AudioStreamPlayer = %Music

var generator_buttons: Array[Button] = []
var _unlocked := {} # Fitur yang sudah terbuka, untuk mendeteksi unlock baru.
var _banner_queue: Array[String] = []
var _banner_showing := false
var _portrait := false


func _ready() -> void:
	music.finished.connect(music.play) # Ulangi musik latar terus-menerus.
	sound_toggle.toggled.connect(_on_sound_toggled)
	click_button.pressed.connect(_on_click)
	click_button.mouse_entered.connect(_scale_cup.bind(1.06))
	click_button.mouse_exited.connect(_scale_cup.bind(1.0))
	click_upgrade_button.pressed.connect(_on_click_upgrade)
	prestige_button.pressed.connect(_on_prestige_pressed)
	prestige_dialog.confirmed.connect(_on_prestige_confirmed)
	reset_button.pressed.connect(_popup_dialog.bind(reset_dialog))
	reset_dialog.confirmed.connect(_on_reset_confirmed)

	# Urutan tombol di GeneratorList harus sama dengan GameState.GENERATORS.
	for i in generator_list.get_child_count():
		var button := generator_list.get_child(i) as Button
		button.pressed.connect(_on_buy_generator.bind(i))
		generator_buttons.append(button)

	get_window().size_changed.connect(_update_layout)
	_update_layout(true)

	# Fitur yang sudah terbuka dari data save tidak perlu diumumkan lagi.
	_unlocked = _unlock_states()

	if GameState.offline_earnings > 0.0:
		info_label.text = "Selamat datang kembali! Selama offline kamu mendapat %s koin." \
				% GameState.format_number(GameState.offline_earnings)


func _process(_delta: float) -> void:
	coins_label.text = "%s Koin" % GameState.format_number(GameState.coins)
	rate_label.text = "%s koin/detik   |   Biji Emas: %d (x%.1f)" % [
		GameState.format_number(GameState.income_per_second()),
		GameState.golden_beans,
		GameState.multiplier(),
	]
	click_value_label.text = "+%s koin / seduhan" % GameState.format_number(GameState.click_value())

	var states := _unlock_states()
	_check_new_unlocks(states)

	var upgrade_cost := GameState.click_upgrade_cost()
	click_upgrade_button.visible = states["Upgrade Seduhan"]
	# Di potret labelnya dipersingkat agar muat di samping cangkir.
	var upgrade_name := "Upgrade Lv %d" if _portrait else "Upgrade Seduhan (Lv %d)"
	click_upgrade_button.text = (upgrade_name + "\nHarga: %s") % [
		GameState.click_level, GameState.format_number(upgrade_cost)]
	click_upgrade_button.disabled = GameState.coins < upgrade_cost

	var gain := GameState.prestige_gain()
	prestige_button.visible = states["Prestige"]
	prestige_button.text = "Prestige\n+%d Biji Emas" % gain
	prestige_button.disabled = gain < 1

	for i in generator_buttons.size():
		_update_generator_button(i)


## Generator terbuka jika generator sebelumnya sudah dibeli. Generator
## terkunci pertama ditampilkan sebagai "???" agar pemain punya tujuan.
func _update_generator_button(i: int) -> void:
	var button := generator_buttons[i]
	var unlocked := _is_generator_unlocked(i)
	var is_teaser := not unlocked and _is_generator_unlocked(i - 1)
	button.visible = unlocked or is_teaser

	if unlocked:
		var cost := GameState.generator_cost(i)
		button.text = "%s  (x%d)\n+%s/detik   -   Harga: %s" % [
			GameState.GENERATORS[i]["name"],
			GameState.owned[i],
			GameState.format_number(GameState.generator_rate(i)),
			GameState.format_number(cost),
		]
		button.disabled = GameState.coins < cost
		button.remove_theme_color_override("icon_disabled_color")
	elif is_teaser:
		button.text = "???  (terkunci)\nBeli %s untuk membuka" % GameState.GENERATORS[i - 1]["name"]
		button.disabled = true
		button.add_theme_color_override("icon_disabled_color", LOCKED_ICON_COLOR)


func _is_generator_unlocked(i: int) -> bool:
	return i == 0 or GameState.owned[i - 1] > 0


func _unlock_states() -> Dictionary:
	var states := {
		"Upgrade Seduhan": GameState.click_level > 0 or GameState.total_earned >= UPGRADE_UNLOCK_EARNED,
		"Prestige": GameState.golden_beans > 0 or GameState.total_earned >= PRESTIGE_UNLOCK_EARNED,
	}
	for i in range(1, GameState.GENERATORS.size()):
		states[GameState.GENERATORS[i]["name"]] = _is_generator_unlocked(i)
	return states


func _check_new_unlocks(states: Dictionary) -> void:
	for feature in states:
		if states[feature] and not _unlocked.get(feature, false):
			_show_banner("BARU TERBUKA: %s!" % feature)
	_unlocked = states


# --- Tata letak responsif ---

## Layar lebih tinggi daripada lebar (ponsel) memakai tata letak potret satu kolom
## dengan teks dan tombol yang lebih besar; selain itu memakai tata letak desktop.
func _update_layout(force := false) -> void:
	var window_size := get_window().size
	var portrait := window_size.y > window_size.x
	if portrait == _portrait and not force:
		return
	_portrait = portrait
	var mode := 1 if portrait else 0

	get_window().content_scale_size = PORTRAIT_SIZE if portrait else LANDSCAPE_SIZE

	# Tema dipakai bersama oleh semua tombol dan dialog, jadi cukup diubah sekali.
	theme.default_font_size = THEME_FONT_SIZE[mode]
	theme.set_constant("icon_max_width", "Button", THEME_ICON_WIDTH[mode])

	var margin := $Margin as MarginContainer
	var gutter_x := 16 if portrait else 24
	var gutter_y := 16 if portrait else 20
	margin.add_theme_constant_override("margin_left", gutter_x)
	margin.add_theme_constant_override("margin_right", gutter_x)
	margin.add_theme_constant_override("margin_top", gutter_y)
	margin.add_theme_constant_override("margin_bottom", gutter_y)

	var columns := $Margin/Columns as BoxContainer
	columns.vertical = portrait
	columns.add_theme_constant_override("separation", 12 if portrait else 28)
	($Margin/Columns/Left as BoxContainer).alignment = \
			BoxContainer.ALIGNMENT_BEGIN if portrait else BoxContainer.ALIGNMENT_CENTER

	# Bingkai kafe (gambar 500px) memakai bantalan tipis di potret agar muat di lebar layar.
	var cafe_frame := $Margin/Columns/Left/CafeFrame as PanelContainer
	if portrait:
		var frame_style := cafe_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		frame_style.set_content_margin_all(6)
		cafe_frame.add_theme_stylebox_override("panel", frame_style)
	else:
		cafe_frame.remove_theme_stylebox_override("panel")

	for entry in FONT_SIZES:
		(get_node(entry[0]) as Control).add_theme_font_size_override("font_size", entry[1 + mode])
	for entry in MIN_SIZES:
		(get_node(entry[0]) as Control).custom_minimum_size = entry[1 + mode]
	for button in generator_buttons:
		button.custom_minimum_size.y = GENERATOR_BUTTON_HEIGHT[mode]

	# Di potret, tombol Reset dan Suara dibagi rata selebar panel.
	for button: Control in [reset_button, sound_toggle]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL


func _popup_dialog(dialog: ConfirmationDialog) -> void:
	var width := 500 if _portrait else 460
	dialog.popup_centered(Vector2i(width, 0))


# --- Efek visual ---

func _show_banner(text: String) -> void:
	_banner_queue.append(text)
	if not _banner_showing:
		_show_next_banner()


func _show_next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_showing = false
		unlock_banner.visible = false
		return
	_banner_showing = true
	banner_label.text = _banner_queue.pop_front()
	sfx_upgrade.play()

	unlock_banner.visible = true
	unlock_banner.modulate.a = 0.0
	unlock_banner.pivot_offset = unlock_banner.size / 2.0
	unlock_banner.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(unlock_banner, "modulate:a", 1.0, 0.25)
	tween.tween_property(unlock_banner, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.8)
	tween.chain().tween_property(unlock_banner, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(_show_next_banner)


func _scale_cup(target: float) -> void:
	click_button.pivot_offset = click_button.size / 2.0
	create_tween().tween_property(click_button, "scale", Vector2.ONE * target, 0.12)


func _spawn_floating_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color("3b2417"))
	label.add_theme_constant_override("outline_size", 8)
	label.position = floating_texts.get_local_mouse_position() + Vector2(randf_range(-30, 10), -30)
	floating_texts.add_child(label)

	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 90, 0.9) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


# --- Event tombol ---

func _on_click() -> void:
	GameState.click()
	sfx_click.pitch_scale = randf_range(0.9, 1.15)
	sfx_click.play()
	_spawn_floating_text("+" + GameState.format_number(GameState.click_value()))
	click_button.pivot_offset = click_button.size / 2.0
	var tween := create_tween()
	tween.tween_property(click_button, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(click_button, "scale", Vector2(1.06, 1.06), 0.1)


func _on_click_upgrade() -> void:
	if GameState.buy_click_upgrade():
		sfx_upgrade.play()


func _on_buy_generator(index: int) -> void:
	if GameState.buy_generator(index):
		sfx_buy.play()


func _on_sound_toggled(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	sound_toggle.text = "Suara: OFF" if muted else "Suara: ON"


func _on_reset_confirmed() -> void:
	GameState.reset_game()
	cafe_view.clear_customers()
	_banner_queue.clear()
	info_label.text = "Data berhasil direset. Klik cangkir kopi untuk mulai lagi!"


func _on_prestige_pressed() -> void:
	_popup_dialog(prestige_dialog)


func _on_prestige_confirmed() -> void:
	var gain := GameState.prestige_gain()
	if GameState.prestige():
		sfx_prestige.play()
		info_label.text = "Prestige berhasil! +%d Biji Emas." % gain
