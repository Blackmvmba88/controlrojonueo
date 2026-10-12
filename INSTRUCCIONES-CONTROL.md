# ControlGame — Hoja de instrucciones

## Abrir la app

Abre **ControlGame** en `/Users/blackmamba/Applications/ControlGame.app`. Puedes arrastrarla al Dock para tenerla a mano. Ya no necesitas abrir Terminal ni activar Python.

1. Conecta el mando Xbox por USB o Bluetooth.
2. Abre ControlGame y comprueba el estado del control.
3. Si aparece «Falta permiso de Accesibilidad», pulsa **Permitir control en Accesibilidad**, añade ControlGame con el botón + si no aparece y activa su interruptor. Regresa a la app: el estado se actualiza automáticamente.
4. Prueba las flechas en Finder. A hace clic y B cancela en la ventana que esté activa.

## Botones

| Mando | Acción |
|---|---|
| Stick izquierdo | Mover el mouse |
| Stick derecho | Scroll vertical y horizontal |
| Cruceta | Flechas para navegar |
| A / B | Clic izquierdo / Escape |
| L3 / R3 | Doble clic / Clic derecho |
| X | Reproducir / pausar |
| Y | Pantalla completa (Ctrl+Cmd+F) |
| LB / RB | Pestaña anterior / siguiente |
| LT / RT | Aplicación anterior / siguiente |
| Menu | Enter |
| View | Mission Control (Ctrl+↑) |

## Personalizar botones

Pulsa **Personalizar botones** o cualquier fila de Tus controles. Selecciona el botón en pantalla o presiónalo en el mando; busca una acción o filtra por Mouse, Navegación, Navegador, Edición, Multimedia o Sistema y pulsa **Asignar**. Los cambios se guardan automáticamente y siguen disponibles al reiniciar. Todos los botones, gatillos, cruceta y clics de sticks se pueden reasignar; los movimientos de los sticks siguen siendo mouse y scroll.

Durante la edición se suspenden clics, movimiento y atajos mientras ControlGame está al frente; al cambiar a otra app vuelve el control del escritorio. Pulsa **Listo** para volver al escritorio. **Sin acción** deshabilita un botón. **Restaurar controles iniciales** pide confirmación antes de reemplazar las asignaciones.

Los atajos dependen de la aplicación al frente. Todavía no se incluyen combinaciones personalizadas, macros ni un teclado por letras.

## Jugar sin que el mando te saque

- **Juego · sin atajos:** suspende toda entrada de teclado de ControlGame. Selecciónalo antes de jugar en Xbox Cloud o en otro navegador.
- **Automático:** suspende los atajos cuando un juego reconocido está al frente. Para otro juego, actívalo, vuelve a ControlGame y pulsa **Añadir última app externa a la lista de juegos**. Comprueba el nombre antes de añadirlo. La lista se guarda.
- **Escritorio:** permite los atajos aunque estés en un juego; úsalo sólo cuando quieras control de escritorio explícito.
- **Pausar:** detiene los atajos hasta pulsar Reanudar.

No hay detección de URLs dentro del navegador en esta versión. El modo Juego permanece seleccionado hasta que lo cambies, incluso al reiniciar la app.

## Salir

El mando funciona dentro y fuera de la ventana. Cerrar o minimizar la ventana mantiene el control del escritorio activo. Abre la ventana desde el icono de mando en la barra de menú o desde Aplicaciones. Para detener el programa, elige Salir de ControlGame en la barra de menú o presiona Cmd+Q. No dejes activo el script Python antiguo al mismo tiempo: duplicaría los eventos.

## Permisos y actualizaciones

La versión 1.1 usa el certificado local estable «BlackMamba ControlGame Local Signing». Las actualizaciones deben conservar ese certificado, el identificador y la ruta instalada. Se verificó que el requisito de firma permanece igual con contenido diferente. No uses firma ad hoc: el constructor ahora rechaza ese cambio. La clave privada está en el llavero y en la carpeta privada de firma, fuera del repositorio. Si migras de una versión antigua, puede requerirse una nueva autorización inicial. La app comprueba el permiso real.

## Construcción para desarrollo

Desde `/Users/blackmamba/controlrojonueo`: `python3 macos/build.py`. Genera una candidata en `build/ControlGame.app` sin reemplazar la instalada. Usa AppKit y GameController nativos, sin depender de Python para ejecutar la app. El icono fuente está en `assets/ControlGame.png`.

## Interfaz 1.1

Paneles de vidrio, fondo animado y visualizador de entradas reales del mando. Los botones se iluminan, los sticks muestran su posición y los gatillos su porcentaje. Las animaciones respetan Reducir movimiento de macOS. El botón **Cómo empezar** abre una guía dentro de la app. El estado de conexión, permiso y pausa se muestra por separado.


## Navegación por tarjetas de YouTube (1.3)

Activa **Navegar por tarjetas** en Tus controles. En YouTube, la primera pulsación de cruceta selecciona un enlace de video visible con un borde cian; las siguientes cambian de tarjeta según la dirección. **A** abre la selección y **B** vuelve. Incluye videos y Shorts que el navegador exponga mediante Accesibilidad. Si el navegador sólo expone el título, el borde marca el título clicable. En otras aplicaciones se conservan tus asignaciones normales.

El stick izquierdo sigue moviendo el mouse y el derecho hace scroll; al usarlos se cancela el recuadro para evitar abrir una selección anterior. Para usar tus botones personalizados en YouTube, desactiva Navegar por tarjetas. Las cinco acciones de tarjetas también están disponibles individualmente en el catálogo. Si una página no ofrece enlaces accesibles, las direcciones funcionan como flechas; usa mouse, scroll y clic para los demás elementos. Al llegar fuera de pantalla intenta desplazar la página; si no logra mostrar la tarjeta, usa el stick derecho.
