extends Node
## Menyimpan seluruh data permainan (autoload "GameState").
## Mengatur koin, generator, upgrade, prestige, serta save/load.

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8 * 60 * 60

const COST_GROWTH := 1.15
const CLICK_UPGRADE_BASE_COST := 50.0
const CLICK_UPGRADE_GROWTH := 3.0
const PRESTIGE_REQUIREMENT := 1_000_000.0
const PRESTIGE_BONUS := 0.1

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

const GENERATORS := [
	{"name": "Barista", "base_cost": 15.0, "rate": 0.1},
	{"name": "Mesin Espresso", "base_cost": 100.0, "rate": 1.0},
	{"name": "Gerobak Kopi", "base_cost": 1_100.0, "rate": 8.0},
	{"name": "Kedai Kopi", "base_cost": 12_000.0, "rate": 47.0},
	{"name": "Pabrik Roasting", "base_cost": 130_000.0, "rate": 260.0},
	{"name": "Perkebunan Kopi", "base_cost": 1_400_000.0, "rate": 1_400.0},
]

var coins := 0.0
var total_earned := 0.0 # Total koin sejak prestige terakhir.
var click_level := 0
var owned: Array[int] = []
var golden_beans := 0
var offline_earnings := 0.0

var _autosave_timer := 0.0


func _ready() -> void:
	owned.resize(GENERATORS.size())
	owned.fill(0)
	load_game()


func _process(delta: float) -> void:
	add_coins(income_per_second() * delta)

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Perhitungan ---

func multiplier() -> float:
	return 1.0 + golden_beans * PRESTIGE_BONUS


func click_value() -> float:
	return pow(2.0, click_level) * multiplier()


func generator_rate(index: int) -> float:
	return GENERATORS[index]["rate"] * multiplier()


func income_per_second() -> float:
	var total := 0.0
	for i in GENERATORS.size():
		total += owned[i] * generator_rate(i)
	return total


func generator_cost(index: int) -> float:
	return GENERATORS[index]["base_cost"] * pow(COST_GROWTH, owned[index])


func click_upgrade_cost() -> float:
	return CLICK_UPGRADE_BASE_COST * pow(CLICK_UPGRADE_GROWTH, click_level)


func prestige_gain() -> int:
	return int(floor(sqrt(total_earned / PRESTIGE_REQUIREMENT)))


# --- Aksi pemain ---

func add_coins(amount: float) -> void:
	coins += amount
	total_earned += amount


func click() -> void:
	add_coins(click_value())


func buy_generator(index: int) -> bool:
	var cost := generator_cost(index)
	if coins < cost:
		return false
	coins -= cost
	owned[index] += 1
	return true


func buy_click_upgrade() -> bool:
	var cost := click_upgrade_cost()
	if coins < cost:
		return false
	coins -= cost
	click_level += 1
	return true


func prestige() -> bool:
	var gain := prestige_gain()
	if gain < 1:
		return false
	golden_beans += gain
	coins = 0.0
	total_earned = 0.0
	click_level = 0
	owned.fill(0)
	save_game()
	return true


# --- Save / Load ---

func save_game() -> void:
	var data := {
		"coins": coins,
		"total_earned": total_earned,
		"click_level": click_level,
		"owned": owned,
		"golden_beans": golden_beans,
		"last_save": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return

	coins = data.get("coins", 0.0)
	total_earned = data.get("total_earned", 0.0)
	click_level = int(data.get("click_level", 0))
	golden_beans = int(data.get("golden_beans", 0))
	var saved_owned: Array = data.get("owned", [])
	for i in mini(saved_owned.size(), owned.size()):
		owned[i] = int(saved_owned[i])

	# Penghasilan offline, dibatasi maksimal 8 jam.
	var now := Time.get_unix_time_from_system()
	var elapsed := clampf(now - data.get("last_save", now), 0.0, MAX_OFFLINE_SECONDS)
	offline_earnings = income_per_second() * elapsed
	add_coins(offline_earnings)


func reset_game() -> void:
	coins = 0.0
	total_earned = 0.0
	click_level = 0
	golden_beans = 0
	owned.fill(0)
	save_game()


# --- Utilitas ---

## Mengubah angka besar menjadi format singkat, contoh: 1.25M, 3.40B.
func format_number(value: float) -> String:
	if value < 1000.0:
		if value < 10.0 and value != floor(value):
			return "%.1f" % value
		return "%d" % int(value)
	var tier := 0
	while value >= 1000.0 and tier < SUFFIXES.size() - 1:
		value /= 1000.0
		tier += 1
	return "%.2f%s" % [value, SUFFIXES[tier]]
