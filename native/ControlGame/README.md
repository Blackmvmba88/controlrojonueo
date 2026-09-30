# ControlGame nativo para macOS

App Swift local para usar un control Xbox Series X/S como mouse. Detecta la versión de macOS y muestra acceso a Bluetooth y Accesibilidad.

- Stick izquierdo: cursor; stick derecho: desplazamiento.
- A: clic izquierdo y arrastre; B: clic derecho.
- X: Enter; Y: Escape.
- RT: ⌘ Tab; LT: ⌘ Shift Tab. Mantén un gatillo para mostrar el selector de macOS; suelta ambos para entrar a la aplicación seleccionada. Con RT sostenido, pulsa LT para retroceder en el selector.
- Menú: activar o pausar.

Esta app es independiente del runtime Rust de la raíz; tiene otro mapeo y no incluye detección automática de juegos ni el lector USB GIP.

## Compilar

Desde esta carpeta, ejecuta `./build.sh`. Requiere macOS y las herramientas de desarrollo de Apple. Produce `build/ControlGame.app`.

El script exige `CONTROLGAME_SIGNING_IDENTITY` con una identidad de firma disponible y estable. Para una prueba local temporal, permite explícitamente `CONTROLGAME_ALLOW_ADHOC=1 ./build.sh`. Esa firma identifica cada ejecutable por su hash y puede invalidar Accesibilidad al recompilar. Mantener el bundle ID no basta para conservar los permisos.

El build no instala, reinicia ni restablece permisos. Conserva el identificador `local.blackmamba.ControlGame` y la ubicación de instalación al actualizar. Usa la misma identidad de firma; verifica compatibilidad del requisito de firma antes de reemplazar una versión autorizada.

## Estado verificado

El código compiló y la app arrancó en macOS 26.3.1. La autorización y las acciones con el control requieren validación en el equipo. No hay una identidad de firma estable configurada en el entorno original.
