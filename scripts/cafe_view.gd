extends Control
## Tampilan interior kafe. Dekorasi muncul sesuai generator yang dimiliki,
## dan pelanggan berdatangan membeli kopi sesuai penghasilan per detik.

const CUSTOMER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/cafe/customer_1.svg"),
	preload("res://assets/cafe/customer_2.svg"),
	preload("res://assets/cafe/customer_3.svg"),
	preload("res://assets/cafe/customer_4.svg"),
]
const CUP_TEXTURE := preload("res://assets/icons/cup.svg")
const GOLD := Color("f2c14e")
const MAX_CUSTOMERS := 5
const WALK_SPEED := 110.0
const CUSTOMER_SIZE := Vector2(54, 80)
const CUSTOMER_Y := 112.0

## Dekorasi untuk tiap generator (urutan sama dengan GameState.GENERATORS):
## [node, jumlah minimum generator agar dekorasi muncul].
@onready var decorations := [
	[[%Barista1, 1], [%Barista2, 5], [%Barista3, 15]],
	[[%Espresso1, 1], [%Espresso2, 10]],
	[[%Cart, 1]],
	[[%Plant1, 1], [%Plant2, 1], [%Lamp1, 1], [%Lamp2, 1]],
	[[%Factory, 1]],
	[[%Plantation, 1]],
]
@onready var customers: Control = %Customers
@onready var hint_label: Label = %HintLabel

var _spawn_timer := 0.0


func _ready() -> void:
	_refresh_decorations(false)


func _process(delta: float) -> void:
	_refresh_decorations(true)

	var income := GameState.income_per_second()
	hint_label.visible = income <= 0.0
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and income > 0.0:
		var interval := _spawn_interval()
		_spawn_timer = interval
		if customers.get_child_count() < MAX_CUSTOMERS:
			# Uang yang "dibayar" pelanggan = penghasilan selama jeda kedatangan.
			_spawn_customer(income * interval)


## Menghapus semua pelanggan yang sedang berada di kafe (dipakai saat reset data).
func clear_customers() -> void:
	for customer in customers.get_children():
		customer.queue_free()
	_spawn_timer = 0.0


## Makin banyak generator, makin sering pelanggan datang.
func _spawn_interval() -> float:
	var total := 0
	for count in GameState.owned:
		total += count
	return clampf(3.0 / sqrt(maxf(total, 1)), 0.7, 3.0)


func _refresh_decorations(animate: bool) -> void:
	for i in decorations.size():
		for entry in decorations[i]:
			var node: Control = entry[0]
			var should_show: bool = GameState.owned[i] >= entry[1]
			if node.visible == should_show:
				continue
			node.visible = should_show
			if should_show and animate:
				_pop_in(node)


func _pop_in(node: Control) -> void:
	node.pivot_offset = Vector2(node.size.x / 2.0, node.size.y)
	node.scale = Vector2.ZERO
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Pelanggan ---

func _spawn_customer(amount: float) -> void:
	var customer := TextureRect.new()
	customer.texture = CUSTOMER_TEXTURES.pick_random()
	customer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	customer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	customer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	customer.size = CUSTOMER_SIZE
	customer.pivot_offset = Vector2(CUSTOMER_SIZE.x / 2.0, CUSTOMER_SIZE.y)
	customer.position = Vector2(size.x + 10.0, CUSTOMER_Y + randf_range(-4.0, 4.0))
	customers.add_child(customer)

	# Animasi berjalan: badan bergoyang kiri-kanan.
	var walk := customer.create_tween().set_loops()
	walk.tween_property(customer, "rotation_degrees", 5.0, 0.16)
	walk.tween_property(customer, "rotation_degrees", -5.0, 0.16)

	var stop_x := randf_range(262.0, 310.0)
	var exit_x := size.x + 10.0
	var steps := customer.create_tween()
	steps.tween_property(customer, "position:x", stop_x, (customer.position.x - stop_x) / WALK_SPEED)
	steps.tween_callback(_stop_walking.bind(customer, walk))
	steps.tween_interval(0.5)
	steps.tween_callback(_pay.bind(customer, amount))
	steps.tween_interval(0.5)
	steps.tween_callback(_start_leaving.bind(customer, walk))
	steps.tween_property(customer, "position:x", exit_x, (exit_x - stop_x) / WALK_SPEED)
	steps.tween_callback(customer.queue_free)


func _stop_walking(customer: TextureRect, walk: Tween) -> void:
	walk.pause()
	customer.rotation_degrees = 0.0


func _start_leaving(customer: TextureRect, walk: Tween) -> void:
	customer.flip_h = true
	walk.play()


func _pay(customer: TextureRect, amount: float) -> void:
	# Pelanggan menerima secangkir kopi.
	var cup := TextureRect.new()
	cup.texture = CUP_TEXTURE
	cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cup.size = Vector2(22, 22)
	cup.position = Vector2(34, 40)
	customer.add_child(cup)

	# Angka koin melayang di atas kepala pelanggan.
	var label := Label.new()
	label.text = "+" + GameState.format_number(amount)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color("3b2417"))
	label.add_theme_constant_override("outline_size", 6)
	label.position = customer.position + Vector2(4, -22)
	add_child(label) # Bukan ke "customers", agar tidak dihitung sebagai pelanggan.

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
