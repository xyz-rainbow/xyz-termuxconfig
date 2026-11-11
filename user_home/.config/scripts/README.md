# Scripts Personalizados de Termux (`~/.config/scripts/`)

Todos los scripts de este directorio están enlazados simbólicamente en `~/.local/bin/` para estar disponibles en el `$PATH` global sin ensuciar `$HOME`.

## Scripts Activos

- **`desktop`** (`~/.local/bin/desktop`):
  Gestor unificado para Debian 13 (Trixie) + GNOME 48 en `Termux:X11` con aceleración por hardware Adreno 650 (`VirGL Vulkan`) y audio `PulseAudio`.
  - `desktop --start` (`-s`): Inicia GNOME 48 (si ya está corriendo, no lo reinicia: avisa y abre directamente la app `Termux:X11`).
  - `desktop --stop` (`-k`): Cierra GNOME 48, D-Bus, PRoot, VirGL y `Termux:X11`, liberando memoria RAM y CPU.
  - `desktop --reboot` (`-r`): Reinicia el escritorio limpiamente (`--stop` seguido de `--start`).
  - `desktop --status`: Muestra el estado actual del escritorio, FPS, resolución y zoom.
  - `desktop --fps [30|48|50|60|90|120|144|help]`: Consulta los FPS actuales o configura los FPS de GNOME y los Hz físicos de la pantalla de la Xiaomi Pad 6 vía ADB (60 FPS por defecto).
  - `desktop --resolution [100%|75%|67%|50%|WxH|help]` (o `--res`): Consulta o configura la resolución adaptable a ventana partida/pantalla completa (`100%` por defecto) o fija (`1920x1200`).
  - `desktop --zoom [50..300|help]`: Consulta o configura el zoom de la interfaz/texto/cursor de GNOME de forma independiente a la resolución (`100` por defecto, `200` para el doble de tamaño en ventana pequeña).
  - `desktop --fast` / `desktop --normal` (o `--mode fast|normal`, `--animations off|on`): Desactiva o activa las animaciones de GNOME en vivo o al iniciar.
  - `desktop --help` (`-h`): Muestra la ayuda completa e incluye corrector inteligente de erratas (`¿Querías decir ...?`).
- **`esc-fix`** (`~/.local/bin/esc-fix`, código fuente en `src/esc-fix.c`):
  Traductor PTY en C de latencia cero para el teclado físico oficial de la Xiaomi Pad 6 en Termux.
  - Convierte la tecla superior izquierda (`º`) en `Escape` real (`0x1B`).
  - Mantiene `Shift + Esc` -> `ª` y `Alt + Esc` -> `\`.
  - Permite escribir `º` literal con `Ctrl + Alt + Esc`.
  - Convierte `Ctrl + Alt + [1..0, ', ¡]` en `F1–F12`.
- **`arecord`** (`~/.local/bin/arecord`):
  Wrapper de captura de micrófono para el comando `/voice` de Antigravity CLI, redirigiendo la grabación a `sox -t pulseaudio default` con ganancia `+12 dB`.
- **`GUIDE.md`**:
  Copia local persistente de la guía maestra de configuración y uso de la Xiaomi Pad 6.
