# controlrojonueo

BlackMamba Bluetooth Controller convierte un gamepad Bluetooth/USB en una capa de control para macOS y, después, BlackMamba Deck.

## MVP

- Detecta gamepads Bluetooth/USB con `gilrs`.
- Traduce botones físicos a acciones canónicas (`DeckAction`).
- Ejecuta volumen del sistema y controles de Apple Music en macOS.
- Mantiene entrada y backend desacoplados para conectar después BlackMamba Deck, Spotify, MIDI, ESP32 u otros dispositivos.

## Mapeo inicial

| Control | Acción |
| --- | --- |
| South / A / Cross | Play / Pause |
| East / B / Circle | Siguiente canción |
| West / X / Square | Canción anterior |
| D-pad arriba | Volumen +5% |
| D-pad abajo | Volumen -5% |

Los nombres dependen del layout que reporte el control; el programa imprime el botón detectado para facilitar el remapeo.

## Ejecutar en macOS

1. Empareja el control en **Ajustes del Sistema → Bluetooth**.
2. Instala Rust si todavía no está disponible.
3. Clona el repo y cambia a la rama del MVP:

```bash
git clone https://github.com/Blackmvmba88/controlrojonueo.git
cd controlrojonueo
git switch feat/bluetooth-controller-mvp
cargo run
```

Al arrancar verás los controles detectados y el programa quedará escuchando eventos.

## Arquitectura

```text
Bluetooth / USB Gamepad
        ↓
      gilrs
        ↓
   input::map_button
        ↓
     DeckAction
        ↓
    MediaBackend
        ↓
   MacOsBackend
```

La regla es que el dispositivo físico genera intención; no modifica directamente el motor de reproducción. Esto permite sustituir `MacOsBackend` por un backend de BlackMamba Deck sin cambiar el código de entrada.

## Estructura

```text
src/
├── actions.rs
├── input.rs
├── main.rs
└── backend/
    ├── mod.rs
    └── macos.rs
```

## Siguiente etapa

- Perfiles JSON/TOML por control.
- Wizard de aprendizaje: "presiona el botón para Play/Pause".
- Tap, hold y double-tap.
- Combinaciones como `L1 + A` para cues.
- Backend directo de BlackMamba Deck.
- Reconexión y selección automática de perfil por GUID.
