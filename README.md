# BlackMamba Controller Desktop

Convierte un Xbox/Bluetooth/USB gamepad en una capa de control real para macOS cuando no estás jugando.

## Comportamiento

El modo por defecto es **AUTO**:

- **GAME**: si BlackMamba Cybernetic Runtime marca una sesión activa, si una app de juego reconocida está al frente, o si Chrome/Safari está en una URL de cloud gaming, se suspende toda inyección de mouse/teclado. El juego recibe el control normalmente.
- **DESKTOP**: al salir del juego, el mando vuelve automáticamente a controlar macOS.
- Override manual: `BLACKMAMBA_FORCE_MODE=desktop|game|auto`.

BCR puede señalar una sesión de juego creando `/tmp/blackmamba-game-active`. La rama de integración en `Blackmvmba88/switch` hace esto automáticamente al entrar a `play/open` y elimina la señal en `close/work`.

## Redundancia USB + Bluetooth

El controlador se trata como una **fuente lógica única** aunque cambie el transporte:

- Si hay USB/cable disponible, se prefiere por estabilidad.
- Si el cable desaparece, el runtime espera o hace failover al gamepad inalámbrico disponible sin reiniciarse.
- Si vuelve el cable, puede promoverlo nuevamente a fuente activa.
- Si macOS expone USB y Bluetooth al mismo tiempo, sólo una fuente queda activa para evitar clics/ejes duplicados.
- El log imprime nombre, nombre del SO, VID:PID, UUID y transporte inferido para aprender cómo reporta ese Xbox específico en macOS.

La inferencia usa el GUID/UUID compatible con SDL como pista del bus y `PowerInfo` como respaldo. Si el backend no expone suficiente información, se marca como `unknown` en vez de inventar el transporte.

Prueba de handoff:

```text
1. Inicia cargo run con el mando conectado por cable.
2. Comprueba la línea ACTIVE -> ... USB/cable.
3. Desconecta el cable y deja que Bluetooth reconecte.
4. Debe aparecer FAILOVER -> ... Bluetooth/wireless.
5. Conecta de nuevo el cable.
6. Debe aparecer ACTIVE SOURCE -> ... USB/cable.
```

## Mapeo de escritorio

| Xbox | macOS |
| --- | --- |
| Stick izquierdo | Cursor con dead-zone + aceleración |
| Stick derecho | Scroll |
| A | Clic izquierdo |
| B | Atrás |
| X | Play / Pause |
| Y | Pantalla completa |
| LB / RB | Pestaña anterior / siguiente |
| LT / RT | Aplicación anterior / siguiente |
| D-pad ← / → | Retroceder / adelantar |
| D-pad ↑ / ↓ | Volumen |
| L3 | Doble clic |
| R3 | Clic derecho |
| View | Mission Control |
| Menu | Enter |

## Ejecutar en macOS

```bash
git clone https://github.com/Blackmvmba88/controlrojonueo.git
cd controlrojonueo
git switch feat/xbox-desktop-control
cargo run
```

La primera vez, macOS debe permitir al Terminal/app controlar el equipo en **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**.

## Arquitectura

```text
Xbox / Bluetooth / USB gamepad
            ↓
          gilrs
            ↓
     semantic mapping
      ↙             ↘
AUTO mode         pointer state
   ↓                   ↓
GAME / DESKTOP     dead-zone + curve
   ↓                   ↓
pass-through       Enigo/macOS
                    ↓
          mouse / keyboard / media
```

## Detección AUTO

AUTO revisa el **contexto al frente**, no sólo si el juego sigue abierto:

1. Override explícito `BLACKMAMBA_FORCE_MODE`.
2. Aplicaciones configuradas en `BLACKMAMBA_GAME_APPS`.
3. Juegos nativos conocidos.
4. URL activa de Chrome/Safari para Xbox Cloud Gaming, GeForce NOW o Luna.
5. La señal BCR `/tmp/blackmamba-game-active` como confirmación cuando Atlas/Chrome no exponen suficiente contexto.

Así puedes dejar una sesión de juego abierta, cambiar a Finder/YouTube/ChatGPT y el mando vuelve a DESKTOP; al regresar a la superficie de juego vuelve a GAME.

Para agregar un juego que no se detecte por nombre:

```bash
BLACKMAMBA_GAME_APPS="Nombre de mi juego,Otro juego" cargo run
```

## Desarrollo y validación

```bash
cargo check --all-targets
cargo test --all-targets
```

GitHub Actions ejecuta ambos comandos en `macos-latest`.

## Dependencias principales

- `gilrs 0.11.2`: gamepad unificado, hotplug y ejes.
- `enigo 0.6.1`: inyección de mouse y teclado en macOS.

## Objetivo

El gamepad deja de ser un periférico exclusivo de videojuegos. Cuando juegas, es gamepad. Cuando sales del juego, se convierte automáticamente en control remoto del escritorio.


## Diagnóstico USB GIP directo

Si macOS/gilrs enumera el Xbox pero no emite ningún evento (`map='<none>'`, `source=Driver`), prueba el lector USB directo:

```bash
git pull
cargo build --bin gip_probe
sudo ./target/debug/gip_probe
```

El probe está fijado inicialmente al Xbox Series X|S detectado en esta máquina:

```text
VID:PID 045e:0b12
```

La prueba salta `gilrs`, abre el dispositivo con libusb, reclama la interfaz interrupt IN/OUT, envía el paquete GIP de activación y muestra paquetes crudos. Mueve sticks y pulsa A/B/X/Y.

Resultado esperado si la ruta USB directa funciona:

```text
USB device opened ...
Claimed interface ...
GIP wake packet sent: 5 bytes
RAW #00001 ...
RAW #00002 ...
```

Si los bytes cambian al mover controles, el siguiente paso es convertir esos paquetes GIP en el mismo `DeckAction`/estado de puntero que ya usa el modo escritorio.
