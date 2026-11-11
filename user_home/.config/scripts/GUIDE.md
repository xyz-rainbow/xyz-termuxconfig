# Guía Maestra: `agy` + Debian GNOME (Modo Oscuro) + Optimización en Xiaomi Pad 6

## 1. Resumen de Herramientas y Scripts Instalados

Todo tu entorno en Termux y Debian (`proot-distro`) cuenta ahora con comandos directos en `~/.local/bin`:

| Comando / Archivo | Qué hace |
| :--- | :--- |
| **`desktop`** ([ver script](file:///data/data/com.termux/files/home/.config/scripts/desktop)) | Gestor unificado de **Debian 13 + GNOME 48**: soporta `--start` (si ya está abierto, abre `Termux:X11` sin reiniciar), `--stop`, `--reboot`, `--fps` (30–144 FPS sincronizados con la pantalla de la Xiaomi Pad 6), `--resolution` (adaptable `100%` a ventana partida o fija), `--zoom` (escala de interfaz independiente de la resolución), `--fast` / `--normal` (animaciones), `--status`, `--help` y corrector inteligente de erratas. |
| **`esc-fix`** ([ver código C](file:///data/data/com.termux/files/home/.config/scripts/src/esc-fix.c)) | Traductor PTY ultrarrápido en C para el teclado oficial de 64 teclas de la Xiaomi Pad 6: convierte la tecla física `º` en **`ESC` real** y mapea **`Ctrl + Alt + [1..¡]`** a **`F1–F12`**. |
| **Notas Pendientes** ([`pending.md`](file:///data/data/com.termux/files/home/.config/notes/pending.md)) | Sistema de notas en `~/.config/notes/` que `agy` revisa al iniciar cada sesión (p. ej. autoconfigurar `git` en cuanto hagas `gh auth login`). |
| **Soporte `/voice` y `micro`** | Verificado funcionando (`arecord` captura en 16kHz WAV vía `OpenSL_ES_source`) y `EDITOR=micro` activo en [`.bashrc`](file:///data/data/com.termux/files/home/.bashrc). |

---

## 1.B. Cómo usar `Esc`, `F1–F12` y el Touchpad en tu Teclado Oficial Xiaomi Pad 6

Como el teclado oficial de la Xiaomi Pad 6 es de **64 teclas (5 filas, sin fila física de F1–F12)** y envía el código `KEYCODE_GRAVE` (`º` en español) en la esquina superior izquierda, ha quedado configurado de forma idéntica en Termux y en X11/GNOME:

* **`Esc` real**: Pulsa directamente la **tecla física `Esc` (`º`)** sola.
* **`ª` y `\` originales**: Se mantienen intactos (`Shift + Esc` = `ª`, `Alt + Esc` = `\`). *(Y si algún día necesitas escribir `º` literal, puedes pulsar `Ctrl + Alt + Esc`)*.
* **`F1` a `F10`**: Mantén pulsado **`Ctrl + Alt`** y pulsa del **`1` al `0`** (`Ctrl+Alt+1` = F1 ... `Ctrl+Alt+0` = F10).
* **`F11` y `F12`**: Mantén pulsado **`Ctrl + Alt`** y pulsa **`'`** (para F11) o **`¡`** (para F12).
* **Touchpad Oficial en GNOME (`Termux:X11`)**: Configurado automáticamente en [`desktop-start`](file:///data/data/com.termux/files/home/.local/bin/desktop-start) con resolución `1920x1200` (16:10), captura de puntero físico, **tap-to-click** (1 dedo = clic izquierdo, 2 dedos = clic derecho) y **scroll natural con dos dedos**.

> [!IMPORTANT]
> **Requisito único en Android para que `/voice` capture tu voz:**
> Ve a *Ajustes de Android -> Aplicaciones -> Termux -> Permisos* y asegúrate de que el permiso de **Micrófono** esté en **"Permitir"**. El servidor PulseAudio (`OpenSL_ES_source`) y `arecord` ya están activos y listos.

---

## 2. Aplicaciones en Debian GNOME (ARM64): Qué se ha instalado y alternativas

Como tu Xiaomi Pad 6 tiene procesador **ARM64 (`aarch64`)**, es fundamental distinguir qué programas tienen versión nativa ARM64 para Linux (rápidos y ligeros) y cuáles solo existen para PC `x86_64`:

### A. Aplicaciones Esenciales ya incluidas en tu Debian GNOME
* **Entorno GNOME 48 en Modo Oscuro**: `gnome-shell`, `gnome-control-center` (Ajustes), `gnome-tweaks` (Retoques), `gnome-system-monitor` (Monitor del sistema) y `nautilus` (Archivos).
* **Terminales Modernas (`kitty` + `gnome-console`)**:
  * **`kitty`**: Terminal acelerada por GPU (OpenGL), rapidísima, ideal para usar con `agy`, pestañas y paneles divididos.
  * **`gnome-console` (`kgx`)**: La nueva terminal oficial de GNOME 48 en GTK4/Libadwaita con modo oscuro nativo.
* **Documentos, Markdown y Multimedia**:
  * **Markdown y código ligero**: `gnome-text-editor` (editor moderno de GNOME con resaltado de sintaxis Markdown y modo oscuro) + `micro` en consola.
  * **PDF**: `evince` (Visor de documentos oficial de GNOME).
  * **Word (`.docx`)**: `abiword` (procesador de textos compatible con `.docx` que ocupa solo ~15 MB frente a los 600 MB de LibreOffice).
  * **Vídeo e Imágenes**: `vlc` (reproductor multimedia todoterreno) + `loupe` (el nuevo visor de imágenes rápido de GNOME).

### B. Investigación: Edge, Cursor / Antigravity IDE, Discord y Steam en tu Tablet

| Aplicación | Estado en Linux ARM64 (`aarch64`) | Mejor solución en tu Xiaomi Pad 6 |
| :--- | :--- | :--- |
| **Microsoft Edge** | ❌ Microsoft solo compila Edge para Linux en `x86_64` (`amd64`), no existe paquete `.deb` ARM64. | 1. **En Debian GNOME:** Usa **Chromium** (ya instalado) o **Brave Browser ARM64** (ambos usan el mismo motor Blink de Edge y sincronizan extensiones).<br>2. **En Android nativo:** Instala la app oficial de Microsoft Edge desde Play Store (sincroniza todo tu perfil de Microsoft a 120Hz). |
| **Antigravity IDE / Cursor / VS Code** | ⚠️ **VS Code Oficial (`code`)** y **VSCodium** tienen versión 100% nativa `arm64`. Cursor tiene builds AppImage `arm64`, pero dentro de `proot` las apps Electron pesadas requieren `--no-sandbox`. | **Combinación ganadora:** Instalar **VS Code Oficial ARM64 (`code`)** dentro de Debian GNOME (o usar `code-server`), y abrir dentro de su terminal integrada tu **`agy`** (Antigravity CLI). Así tienes la interfaz gráfica completa de VS Code con el motor de agentes de Antigravity sin duplicar consumo de RAM. |
| **Discord** | ❌ El cliente oficial de Discord para Linux solo existe para `x86_64`. | ✅ **Vesktop** (`arm64` `.deb` oficial en GitHub) o **WebCord (`arm64`)**: Son clientes nativos de Discord para Linux ARM64 mucho más rápidos que el oficial, con soporte de audio, micrófono y Vencord integrado. |
| **Steam** | ❌ Steam de Linux es `x86` (32/64 bits). Ejecutarlo dentro de Debian `proot` con `box86`/`box64` pierde mucho rendimiento por la traducción de llamadas al sistema de `proot`. | ✅ **Winlator (Cmod Glibc/Bionic)** o **GameHub** (APK en Android): Usan directamente tu **Snapdragon 870 + Adreno 650 (Turnip + DXVK + Box64)** sin pasar por `proot`, permitiendo jugar juegos de PC y Steam ligeros/indies a 60 FPS reales. |

---

## 3. IA Local en tu Xiaomi Pad 6 (`Ollama` con aceleración Vulkan Adreno 650)

Al activar el repositorio `tur-repo` en tu Termux, tienes disponible **Ollama compilado de forma nativa para Termux Android con soporte Vulkan para tu GPU Adreno 650**:

```bash
# Cuando quieras instalar Ollama nativo en Termux (sin gastar RAM de Debian):
pkg install ollama ollama-backend-vulkan
```

### ¿Qué modelos de IA local funcionan fluidos en los 8 GB de RAM de tu Xiaomi Pad 6?
Android + HyperOS ocupan ~3.2 GB de RAM base, dejando **~4.2 GB libres** para modelos locales cuantizados en 4 bits (`Q4_K_M`):
1. **`qwen2.5-coder:3b`** (~1.9 GB RAM) $\rightarrow$ El mejor modelo local de código para usar sin conexión a internet (~25–35 tokens/seg en el Snapdragon 870).
2. **`llama3.2:3b`** (~2.0 GB RAM) $\rightarrow$ Excelente modelo generalista multilingüe en español.
3. **`deepseek-r1:1.5b` o `qwen2.5:1.5b`** (~1.1 GB RAM) $\rightarrow$ Respuestas instantáneas y consumo mínimo de batería.

*(Consejo: No descargues modelos de 7B/8B parámetros porque piden ~5.5 GB de RAM continua y forzarán el uso de memoria Swap o cierres de aplicaciones).*

---



### Pasos para emparejar tu tablet consigo misma (solo se hace una vez):
1. En tu Xiaomi Pad 6, ve a **Ajustes -> Ajustes adicionales -> Opciones de desarrollador**.
2. Activa:
   - **Depuración USB**
   - **Depuración inalámbrica** (*Wireless debugging*)
   - **Depuración USB (Ajustes de seguridad)** *(permite cambiar ajustes como el Phantom Process Killer y desinstalar bloatware)*
3. Pon la ventana de **Ajustes** y **Termux** en **pantalla dividida** (importante porque si sales de la pantalla de Depuración inalámbrica, el código cambia).
4. En Ajustes, entra en **Depuración inalámbrica** -> toca **"Vincular dispositivo con código de vinculación"** (*Pair device with pairing code*). Verás una IP/puerto (ej. `192.168.1.XX:38123`) y un código de 6 dígitos.
5. En Termux escribe:
   ```bash
   adb pair 127.0.0.1:PUERTO_DE_VINCULACION CODIGO_6_DIGITOS
   ```
6. Una vez vinculado, mira el puerto principal que aparece justo debajo de "Dirección IP y puerto" en la pantalla de *Depuración inalámbrica* y conecta:
   ```bash
   adb connect 127.0.0.1:PUERTO_PRINCIPAL
   ```
7. Ahora ejecuta nuestro auditor automático:
   ```bash
   ```
     1. Desactiva el **Phantom Process Killer** (`max_phantom_processes = 2147483647`) para que Android jamás cierre tus subagentes (`swarm`) ni tu escritorio GNOME con `Signal 9`.
