# controlrojonueo

BlackMamba Bluetooth Controller — convierte un gamepad Bluetooth/USB en una capa de control para macOS y, después, BlackMamba Deck.

## Objetivo MVP

- Detectar gamepads Bluetooth/USB mediante HID.
- Traducir botones a acciones canónicas (`PlayPause`, `NextTrack`, `PreviousTrack`, `VolumeUp`, `VolumeDown`).
- Ejecutar acciones de volumen y Apple Music en macOS.
- Mantener desacoplada la entrada física del backend para poder conectar después BlackMamba Deck, Spotify, MIDI, ESP32 u otros controladores.

La implementación se desarrolla en una rama de trabajo antes de integrarse a `main`.
