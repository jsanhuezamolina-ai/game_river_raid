# Guía de Desarrollo: River Raid Modernizado en Godot 4 (Android)

Esta guía contiene la arquitectura, mecánicas y scripts base en **GDScript** para construir un juego funcional estilo *River Raid* en **Godot 4**, aplicando las mejoras de diseño solicitadas por los jugadores en Android.

---

## 1. Mejoras Clave de Diseño (Basadas en Feedback Real)

* **Visibilidad Total (Cero botones invasivos):** El avión se controla deslizando el dedo en cualquier parte de la pantalla (movimiento relativo). El disparo es automático por defecto (con opción de modo manual) para mantener la pantalla limpia.
* **Control de Velocidad Dinámico:** Deslizar hacia arriba acelera el avión y el desplazamiento del río; deslizar hacia abajo frena.
* **Modos de Dificultad (A y B):**
  * **Modo A (Clásico/Accesible):** Consumo de combustible moderado, ríos más anchos y disparos rectos.
  * **Modo B (Veterano):** Mayor consumo de gasolina, enemigos que disparan o patrullan rápido y ríos estrechos.
* **Personalización y Semillas:** Selector de color/modelo de nave, vidas iniciales configurables y generación procedural del río basada en una **semilla (Seed)** compartible.

---

## 2. Configuración del Proyecto en Godot 4

1. Crea un nuevo proyecto en **Godot 4.x** usando el renderizador **Compatibility** (ideal para máximo rendimiento en cualquier teléfono Android).
2. Ve a **Proyecto > Configuración del proyecto > Pantalla > Ventana**:
   * **Ancho del Viewport:** `540`
   * **Alto del Viewport:** `960`
   * **Modo de estiramiento:** `canvas_items`
   * **Aspecto:** `expand`
   * **Orientación:** `portrait` (Vertical)
3. Crea las siguientes **Capas de Colisión** (*Layer Names > 2D Physics*):
   * **Capa 1:** `Jugador`
   * **Capa 2:** `ParedesRio`
   * **Capa 3:** `Enemigos`
   * **Capa 4:** `Combustible`
   * **Capa 5:** `Proyectiles`

---

## 3. Estructura de Escenas y Nodos

Organiza tu proyecto en las siguientes escenas independientes:

### A. `Main.tscn` (Escena Principal)
* `Main` (Node2D) - *Script: `main.gd`*
  * `RiverGenerator` (Node2D) - *Script: `river_generator.gd`*
  * `Player` (Instancia de `Player.tscn`)
  * `HUD` (CanvasLayer) - *Script: `hud.gd`*
    * `FuelBar` (ProgressBar)
    * `ScoreLabel` (Label)
    * `SeedLabel` (Label)

### B. `Player.tscn` (Avión del Jugador)
* `Player` (CharacterBody2D) - *Script: `player.gd`*
  * `Sprite2D` (Textura del jet, con propiedad `modulate` para cambiar color)
  * `CollisionShape2D` (Polígono o rectángulo ajustado al fuselaje)
  * `ShootTimer` (Timer - `0.25s`, Autostart activado)
  * `Muzzle` (Marker2D en la punta del avión)

### C. `Bullet.tscn` (Misil)
* `Bullet` (Area2D) - *Script: `bullet.gd`*
  * `Sprite2D`
  * `CollisionShape2D`
  * `VisibleOnScreenNotifier2D`

### D. `FuelDepot.tscn` (Tanque de Combustible)
* `FuelDepot` (Area2D) - *Script: `fuel_depot.gd`*
  * `Sprite2D` (Ícono de "FUEL")
  * `CollisionShape2D`

### E. `Enemy.tscn` (Barcos, Helicópteros y Puentes)
* `Enemy` (Area2D) - *Script: `enemy.gd`*
  * `Sprite2D`
  * `CollisionShape2D`

---

## 4. Código Base en GDScript

### 1. Control Táctil y Combustible (`player.gd`)
Implementa el movimiento táctil relativo sin tapar la pantalla, el control de velocidad vertical y el consumo de gasolina.

```gdscript
extends CharacterBody2D

signal fuel_changed(current_fuel)
signal player_died

@export var bullet_scene: PackedScene
@export var horizontal_sensitivity: float = 1.2
@export var min_scroll_speed: float = 180.0
@export var max_scroll_speed: float = 550.0
@export var normal_scroll_speed: float = 300.0

var current_scroll_speed: float = 300.0
var max_fuel: float = 100.0
var fuel: float = 100.0
var fuel_consumption_rate: float = 4.5 # Aumentar en Modo B
var is_refueling: bool = false
var is_touching: bool = false

@onready var shoot_timer: Timer = $ShootTimer
@onready var muzzle: Marker2D = $Muzzle

func _ready() -> void:
	current_scroll_speed = normal_scroll_speed
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_touching = event.pressed
		if not is_touching:
			current_scroll_speed = normal_scroll_speed

	elif event is InputEventScreenDrag and is_touching:
		# Movimiento horizontal limpio en cualquier zona de la pantalla
		position.x += event.relative.x * horizontal_sensitivity
		position.x = clamp(position.x, 40.0, 500.0)
		
		# Deslizar arriba acelera, deslizar abajo frena
		if event.relative.y < -2.0:
			current_scroll_speed = lerp(current_scroll_speed, max_scroll_speed, 0.15)
		elif event.relative.y > 2.0:
			current_scroll_speed = lerp(current_scroll_speed, min_scroll_speed, 0.15)

func _process(delta: float) -> void:
	# Gestión de combustible
	if is_refueling:
		fuel = min(max_fuel, fuel + 25.0 * delta)
	else:
		# A mayor velocidad, ligeramente mayor consumo
		var speed_factor = current_scroll_speed / normal_scroll_speed
		fuel -= fuel_consumption_rate * speed_factor * delta
	
	emit_signal("fuel_changed", fuel)
	
	if fuel <= 0.0:
		die()

func _on_shoot_timer_timeout() -> void:
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = muzzle.global_position
		get_parent().add_child(bullet)

func die() -> void:
	emit_signal("player_died")
	queue_free()
```

### 2. Generador Procedural del Río por Semillas (`river_generator.gd`)
Permite crear ríos infinitos, islas centrales y guardar o compartir semillas numéricas.

```gdscript
extends Node2D

@export var segment_height: float = 64.0
@export var screen_width: float = 540.0
@export var enemy_scene: PackedScene
@export var fuel_scene: PackedScene

var rng := RandomNumberGenerator.new()
var current_seed: int = 12345
var river_center: float = 270.0
var river_half_width: float = 180.0
var min_half_width: float = 95.0 # Más estrecho en Modo B
var max_half_width: float = 220.0

var rows_spawned: int = 0
var active_segments: Array[Node2D] = []

func start_river(custom_seed: int) -> void:
	current_seed = custom_seed
	rng.seed = current_seed
	
	# Generar los primeros tramos para llenar la pantalla
	for i in range(18):
		spawn_next_row(-i * segment_height + 960.0)

func update_river(scroll_speed: float, delta: float) -> void:
	for segment in active_segments:
		segment.position.y += scroll_speed * delta
	
	# Eliminar segmentos que salieron por abajo y crear nuevos arriba
	if active_segments.size() > 0 and active_segments[0].position.y > 1050.0:
		var old_seg = active_segments.pop_front()
		old_seg.queue_free()
		
		var highest_y = active_segments.back().position.y
		spawn_next_row(highest_y - segment_height)

func spawn_next_row(y_pos: float) -> void:
	rows_spawned += 1
	
	# Variar suavemente el centro y ancho del río usando la semilla
	river_center += rng.randf_range(-25.0, 25.0)
	river_half_width += rng.randf_range(-15.0, 15.0)
	river_half_width = clamp(river_half_width, min_half_width, max_half_width)
	river_center = clamp(river_center, river_half_width + 30.0, screen_width - river_half_width - 30.0)
	
	var row_container = Node2D.new()
	row_container.position = Vector2(0, y_pos)
	add_child(row_container)
	active_segments.append(row_container)
	
	# Crear orillas izquierda y derecha (Colisión + Color)
	_create_bank(row_container, 0.0, river_center - river_half_width)
	_create_bank(row_container, river_center + river_half_width, screen_width - (river_center + river_half_width))
	
	# Generar objetos cada cierto número de filas
	if rows_spawned % 6 == 0:
		_spawn_entity(row_container)

func _create_bank(parent: Node2D, x_start: float, width: float) -> void:
	if width <= 0:
		return
	var bank = StaticBody2D.new()
	bank.collision_layer = 2 # Capa ParedesRio
	
	var visual = ColorRect.new()
	visual.size = Vector2(width, segment_height + 2.0)
	visual.position = Vector2(x_start, 0)
	visual.color = Color(0.18, 0.55, 0.22) # Verde terreno
	bank.add_child(visual)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, segment_height)
	col.shape = shape
	col.position = Vector2(x_start + width / 2.0, segment_height / 2.0)
	bank.add_child(col)
	
	parent.add_child(bank)

func _spawn_entity(parent: Node2D) -> void:
	var spawn_x = rng.randf_range(river_center - river_half_width + 35.0, river_center + river_half_width - 35.0)
	# 30% probabilidad de tanque de combustible, 70% enemigo
	if rng.randf() < 0.30 and fuel_scene:
		var fuel = fuel_scene.instantiate()
		fuel.position = Vector2(spawn_x, segment_height / 2.0)
		parent.add_child(fuel)
	elif enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.position = Vector2(spawn_x, segment_height / 2.0)
		parent.add_child(enemy)
```

### 3. Tanque de Combustible (`fuel_depot.gd`)
Permite recargar al pasar por encima y explotar si el jugador le dispara (mecánica clásica de riesgo/recompensa).

```gdscript
extends Area2D

signal destroyed(points)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.is_refueling = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.is_refueling = false

func _on_area_entered(area: Area2D) -> void:
	# Si un misil del jugador lo impacta, explota y da puntos extra
	if area.is_in_group("bullets"):
		area.queue_free()
		emit_signal("destroyed", 80)
		queue_free()
```

### 4. Proyectil del Jugador (`bullet.gd`)

```gdscript
extends Area2D

@export var speed: float = 900.0

func _ready() -> void:
	add_to_group("bullets")

func _process(delta: float) -> void:
	position.y -= speed * delta
	if position.y < -50.0:
		queue_free()
```

---

## 5. Pasos para Exportar a Android

1. Descarga e instala **OpenJDK 17** y **Android Studio** (o las *Android Command-line Tools*) para obtener el **Android SDK**.
2. En Godot, ve a **Editor > Configuración del editor > Exportar > Android** y asigna las rutas de tu carpeta **Android SDK** y el archivo **Debug Keystore** (puedes generarlo con `keytool`).
3. Ve a **Editor > Administrar plantillas de exportación** y descarga las plantillas oficiales para tu versión de Godot.
4. Ve a **Proyecto > Exportar**, añade el preajuste **Android**, activa **Exportar con depuración** y pulsa **Exportar proyecto** para generar tu archivo `.apk` listo para instalar en el teléfono.
