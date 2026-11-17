# Changelog

## [Sin publicar]

### Probado
- Teléfono físico Redmi 15C con Android 16 (API 36).

## [1.0.0] - 2026-11-16

### Añadido
- Juego estilo River Raid para Android (Godot 4.7.2, renderer Compatibility).
- Control táctil relativo (deslizar en cualquier zona), aceleración y frenado verticales.
- Disparo automático o manual.
- Río procedural infinito por semilla, con islas, puentes y tramos que se estrechan.
- Enemigos: barcos, helicópteros y puentes; disparos enemigos en modo B.
- Modos A (clásico) y B (veterano).
- Menú: modo, 3 modelos y 6 colores de nave, vidas de 1 a 5, semilla.
- Sonidos sintetizados, récord por modo, pausa y fin del juego.
- Prueba automática por línea de comandos (`--autoplay`) y CI en GitHub Actions.

### Ajustado
- Los misiles atraviesan los tanques FUEL, para poder recargar con disparo automático.
- Movimiento lateral a la mitad de la sensibilidad inicial.
