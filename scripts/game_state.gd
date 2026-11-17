extends Node
## Configuración de la partida, récords y guardado (autoload "GameState").

const SAVE_PATH := "user://river_raid.cfg"

const SHIP_COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.25), # Amarillo clásico
	Color(0.95, 0.35, 0.3), # Rojo
	Color(0.4, 0.9, 1.0),   # Celeste
	Color(0.55, 1.0, 0.45), # Verde lima
	Color(1.0, 0.55, 0.9),  # Rosado
	Color(0.95, 0.95, 0.95) # Blanco
]
const SHIP_MODELS: Array[String] = ["Clásico", "Delta", "Bombardero"]

var mode: String = "A"
var ship_color: int = 0
var ship_model: int = 0
var start_lives: int = 3
var auto_fire: bool = true
var seed_value: int = 0
var high_scores: Dictionary = {"A": 0, "B": 0}


func _ready() -> void:
	load_data()
	if seed_value <= 0:
		new_seed()


func new_seed() -> int:
	seed_value = randi_range(1, 999999)
	return seed_value


## Parámetros de dificultad. A = clásico/accesible, B = veterano.
func mode_params() -> Dictionary:
	if mode == "B":
		return {
			"fuel_rate": 6.5, "min_half": 72.0, "max_half": 175.0,
			"enemy_speed": 1.7, "enemy_shoots": true, "spawn_every": 4, "fuel_chance": 0.24,
		}
	return {
		"fuel_rate": 3.4, "min_half": 110.0, "max_half": 220.0,
		"enemy_speed": 0.85, "enemy_shoots": false, "spawn_every": 6, "fuel_chance": 0.32,
	}


func ship_color_value() -> Color:
	return SHIP_COLORS[clampi(ship_color, 0, SHIP_COLORS.size() - 1)]


## Silueta de la nave apuntando hacia arriba (unos 40 px).
func ship_polygon(model: int) -> PackedVector2Array:
	match model:
		1: # Delta
			return PackedVector2Array([
				Vector2(0, -24), Vector2(22, 18), Vector2(6, 12), Vector2(0, 18),
				Vector2(-6, 12), Vector2(-22, 18)])
		2: # Bombardero
			return PackedVector2Array([
				Vector2(0, -20), Vector2(6, -6), Vector2(26, 0), Vector2(26, 8), Vector2(6, 8),
				Vector2(5, 16), Vector2(12, 22), Vector2(-12, 22), Vector2(-5, 16), Vector2(-6, 8),
				Vector2(-26, 8), Vector2(-26, 0), Vector2(-6, -6)])
		_: # Clásico
			return PackedVector2Array([
				Vector2(0, -22), Vector2(5, -8), Vector2(20, 4), Vector2(20, 10), Vector2(5, 6),
				Vector2(6, 16), Vector2(12, 20), Vector2(-12, 20), Vector2(-6, 16), Vector2(-5, 6),
				Vector2(-20, 10), Vector2(-20, 4), Vector2(-5, -8)])


func high_score() -> int:
	return int(high_scores.get(mode, 0))


## Guarda el puntaje si es récord del modo actual. Devuelve true si es récord nuevo.
func submit_score(score: int) -> bool:
	if score > high_score():
		high_scores[mode] = score
		save_data()
		return true
	return false


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "A", int(high_scores.get("A", 0)))
	cfg.set_value("records", "B", int(high_scores.get("B", 0)))
	cfg.set_value("settings", "mode", mode)
	cfg.set_value("settings", "ship_color", ship_color)
	cfg.set_value("settings", "ship_model", ship_model)
	cfg.set_value("settings", "start_lives", start_lives)
	cfg.set_value("settings", "auto_fire", auto_fire)
	cfg.set_value("settings", "seed", seed_value)
	cfg.save(SAVE_PATH)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_scores["A"] = int(cfg.get_value("records", "A", 0))
	high_scores["B"] = int(cfg.get_value("records", "B", 0))
	mode = str(cfg.get_value("settings", "mode", "A"))
	ship_color = int(cfg.get_value("settings", "ship_color", 0))
	ship_model = int(cfg.get_value("settings", "ship_model", 0))
	start_lives = clampi(int(cfg.get_value("settings", "start_lives", 3)), 1, 5)
	auto_fire = bool(cfg.get_value("settings", "auto_fire", true))
	seed_value = int(cfg.get_value("settings", "seed", 0))
