# BlackMamba Controller Desktop

Convierte un Xbox/Bluetooth/USB gamepad en una capa de control real para macOS cuando no estás jugando.

## Comportamiento

El modo por defecto es **AUTO**:

- **GAME**: si BlackMamba Cybernetic Runtime marca una sesión activa, si una app de juego reconocida está al frente, o si Chrome/Safari está en una URL de cloud gaming, se suspende toda inyección de mouse/teclado. El juego recibe el control normalmente.
- **DESKTOP**: al salir del juego, el mando vuelve automáticamente a controlar macOS.
- Override manual: `BLACKMAMBA_FORCE_MODE=desktop|game|auto`.

BCR puede señalar una sesión de juego creando `/tmp/blackmamba-game-active`. La rama de integración en `Blackmvmba88/switch` hace esto automáticamente al entrar a `play/open` y elimina la señal en `close/work`.

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
