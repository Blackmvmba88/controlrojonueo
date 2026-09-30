# ControlGame nativo para macOS

App Swift local para usar un control Xbox Series X/S como mouse. Detecta la versión de macOS y muestra acceso a Bluetooth y Accesibilidad.

- Stick izquierdo: cursor; stick derecho: desplazamiento.
- A: clic izquierdo y arrastre; B: clic derecho.
- X: Enter; Y: Escape.
- RT: ⌘ Tab; LT: ⌘ Shift Tab. Mantén un gatillo para mostrar el selector de macOS; suelta ambos para entrar a la aplicación seleccionada. Con RT sostenido, pulsa LT para retroceder en el selector.
- Menú: activar o pausar.
- Cruz: flechas normales por defecto; X confirma con Enter.
- B en video: activa el botón de salida del modo cine de YouTube si se reconoce; de lo contrario envía Escape para salir de pantalla completa. Fuera de video conserva clic derecho.
- Video: en páginas de reproducción de YouTube detectables por Accesibilidad, RT/LT y la palanca derecha horizontal envían flecha derecha/izquierda para adelantar/retroceder. Fuera de video, RT/LT conservan el selector de apps. Hay un interruptor manual para otros reproductores. Los campos de texto accesibles bloquean este modo para evitar mover el cursor de edición. La reproducción y el efecto de las flechas dependen del foco y de los atajos del reproductor; abrir una página de video no demuestra que esté reproduciéndose.
- Selección asistida opcional: busca elementos accesibles de la ventana en la dirección pulsada, incluidos enlaces, imágenes, campos y controles de ventana. Muestra un marco amarillo y coloca el cursor para pulsar con A. No vuelve al principio al llegar al borde ni activa elementos automáticamente. El stick recupera el cursor libre.

La selección asistida depende de los elementos que cada app/sitio expone a Accesibilidad. No reconoce imágenes por visión ni garantiza encontrar todas las tarjetas de YouTube. Una ventana con una jerarquía grande puede exponer solo una parte de los elementos dentro del límite de exploración.

Esta app es independiente del runtime Rust de la raíz; tiene otro mapeo y no incluye detección automática de juegos ni el lector USB GIP.

## Compilar

Desde esta carpeta, ejecuta `./build.sh`. Requiere macOS y las herramientas de desarrollo de Apple. Produce `build/ControlGame.app`.

El script exige `CONTROLGAME_SIGNING_IDENTITY` con una identidad de firma disponible y estable. Para una prueba local temporal, permite explícitamente `CONTROLGAME_ALLOW_ADHOC=1 ./build.sh`. Esa firma identifica cada ejecutable por su hash y puede invalidar Accesibilidad al recompilar. Mantener el bundle ID no basta para conservar los permisos.

El build no instala, reinicia ni restablece permisos. Conserva el identificador `local.blackmamba.ControlGame` y la ubicación de instalación al actualizar. Usa la misma identidad de firma; verifica compatibilidad del requisito de firma antes de reemplazar una versión autorizada.

## Estado verificado

El código compiló y la app arrancó en macOS 26.3.1. La autorización y las acciones con el control requieren validación en el equipo. No hay una identidad de firma estable configurada en el entorno original.


## Doctor (versión 1.1)

El botón **Doctor · revisar y probar control** pausa la inyección y muestra permiso real de Accesibilidad, control/perfil conectado, último evento físico recibido y número de eventos. No permite reactivar el mouse mientras Doctor está abierto. Cierra Doctor y activa el mouse al terminar.

Permite abrir Bluetooth/Accesibilidad, exportar JSON y restablecer **solo** Accesibilidad del bundle actual. Restablecer no concede permiso: macOS requiere volver a habilitar la app. Doctor advierte cuando la firma es temporal; no confunde firma válida con conservación garantizada de permisos.

También puedes obtener una instantánea sin abrir ventanas ni inyectar entrada:

```bash
./build/ControlGame.app/Contents/MacOS/ControlGame --doctor
```

Esta instantánea pertenece al proceso que ejecutaste; no inspecciona otra instancia abierta ni prueba los botones. Para verificar eventos físicos utiliza el Doctor dentro de la app. El JSON incluye la ruta local de instalación, pero no texto escrito, títulos de páginas ni URLs.

## Rendimiento y comprobaciones

- Compilación optimizada (`-O`).
- Bucle del cursor detenido cuando el control del escritorio está pausado.
- Pantallas actualizadas por notificación, en lugar de enumerarlas al mover el cursor.
- Contexto de video consultado en segundo plano; los resultados caducados se descartan al cambiar de app/estado. Las acciones deliberadas vuelven a comprobar el contexto.
- Permiso supervisado y liberación de teclas/botones al pausar, desconectar o salir.
- Preferencias de velocidad y modos guardadas entre sesiones.

Ejecuta `./test.sh` para comprobar zona muerta, aceleración, pantallas múltiples, huecos entre pantallas y selección direccional sin retorno al borde. CI ejecuta estas pruebas, compila la app y valida el JSON del Doctor. Estas pruebas no sustituyen pruebas físicas del control ni validan todos los navegadores/reproductores.
