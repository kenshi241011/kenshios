# 🐧 KenshiOS — Cómo crear tu propia distribución de Linux

> Guía completa, paso a paso, para construir **KenshiOS**: una distro basada en Ubuntu, con escritorio **KDE**, enfocada a **hacking ético** y **gaming**, con fondo, nombre, pantalla de carga, optimizaciones y sistema de actualizaciones propios.
>
> Esta guía incluye **todos los comandos** y, lo más valioso, **los errores reales que encontramos y cómo los resolvimos**. Si vas a remasterizar Ubuntu, léete la sección de errores: te ahorrará horas.

---

## 📑 Índice

1. [¿Qué es KenshiOS?](#qué-es-kenshios)
2. [Requisitos](#requisitos)
3. [Visión general del proceso](#visión-general)
4. [Paso 1 — Preparar el entorno (VM + Cubic)](#paso-1)
5. [Paso 2 — Crear el proyecto en Cubic](#paso-2)
6. [Paso 3 — Personalizar el sistema (script maestro)](#paso-3)
7. [Paso 4 — Generar la ISO](#paso-4)
8. [Paso 5 — Probar la ISO](#paso-5)
9. [⚠️ Errores que encontramos y cómo los resolvimos](#errores)
10. [Cómo iterar SIN rehacer la ISO cada vez](#iterar)
11. [Sistema de actualizaciones](#updates)
12. [El script maestro completo](#script)

---

<a name="qué-es-kenshios"></a>
## 1. ¿Qué es KenshiOS?

KenshiOS **no** es un sistema operativo escrito desde cero (eso lleva años). Es una **remasterización** de Ubuntu: se toma Ubuntu como base y se personaliza (programas, aspecto, nombre, configuración) hasta tener una ISO propia que cualquiera puede instalar. Así nacieron Kali, Linux Mint, Pop!_OS, etc.

**KenshiOS incluye:**
- 🪟 Escritorio **KDE Plasma** (aspecto tipo Windows)
- 🛠️ Herramientas de hacking ético (nmap, hydra, john, nikto, netcat…)
- 🎮 Kit gamer (Steam/Proton, Lutris, GameMode, MangoHud, Wine, Vulkan)
- 🎨 Fondo de pantalla y pantalla de carga (Plymouth) propios
- 🏷️ Nombre propio en el sistema y el instalador
- ⚡ Optimizaciones para PC de bajos recursos (ZRAM, Baloo off)
- 👋 Ventana de bienvenida que pregunta el modo de rendimiento al primer arranque
- 🔄 Sistema de actualizaciones propio (sin necesidad de reinstalar)

---

<a name="requisitos"></a>
## 2. Requisitos

- **VirtualBox** (o un PC con Ubuntu para trabajar).
- **Ubuntu 22.04.5 LTS Desktop** como base. ⚠️ **IMPORTANTE: usa 22.04, NO 24.04 ni 26.04** (ver sección de errores — las versiones nuevas usan un formato de ISO que Cubic no remasteriza bien todavía).
- **Cubic** (Custom Ubuntu ISO Creator).
- **~60 GB de disco** libres para la VM de trabajo.
- Opcional: tus imágenes de fondo y de pantalla de carga (PNG horizontales, idealmente 1920×1080).

---

<a name="visión-general"></a>
## 3. Visión general del proceso

```
Ubuntu base (ISO 22.04)
      ↓  Cubic abre la ISO y te mete "dentro" del sistema (chroot)
Personalizar (instalar KDE, herramientas, fondo, etc.)
      ↓  Cubic empaqueta todo
KenshiOS.iso  →  probar en una VM  →  instalar en un PC real
```

---

<a name="paso-1"></a>
## 4. Paso 1 — Preparar el entorno (VM + Cubic)

Dentro de tu Ubuntu (en una VM o en un PC), instala **Cubic**:

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:cubic-wizard/release
sudo apt update
sudo apt install -y cubic
```

> Si `cubic` no se encuentra, el PPA aún no tiene paquete para tu versión de Ubuntu. En 22.04 funciona sin problema.

Abre Cubic desde el menú de aplicaciones.

---

<a name="paso-2"></a>
## 5. Paso 2 — Crear el proyecto en Cubic

1. **Carpeta de proyecto:** crea una carpeta vacía (ej. `~/kenshios`) y selecciónala en Cubic.
   ```bash
   mkdir ~/kenshios
   ```
2. **ISO original:** en la pantalla siguiente, lado izquierdo "Original Disk", pulsa el icono de carpeta junto a *Filename* y elige tu `ubuntu-22.04.5-desktop-amd64.iso`.
3. **Datos de tu distro** (lado derecho "Custom Disk"):
   - **Volume ID:** `KenshiOS 1.0` (máximo 32 caracteres)
   - **Release:** `KenshiOS`
4. Pulsa **Next** y deja que Cubic **extraiga** la ISO (unos minutos).
5. En la pantalla de snaps, **no quites nada** → **Customize**.

Ahora estás **dentro de KenshiOS** (terminal `root@cubic`). Todo lo que hagas aquí queda grabado en tu distro.

---

<a name="paso-3"></a>
## 6. Paso 3 — Personalizar el sistema (script maestro)

En vez de ejecutar decenas de comandos a mano, usamos **un solo script** que lo hace todo. Está al final de esta guía ([script maestro](#script)) y también en el archivo [`kenshios-setup.sh`](kenshios-setup.sh).

**Pasos dentro del chroot de Cubic:**

1. Con el **botón de copiar de Cubic** (al lado de `Back`), copia estos 3 archivos a `/root`:
   - `kenshios.png` (tu fondo de pantalla)
   - `boot.png` (tu pantalla de carga)
   - `kenshios-setup.sh` (el script)
2. Ejecuta:
   ```bash
   sed -i 's/\r$//' /root/kenshios-setup.sh   # por si tiene saltos de línea de Windows
   bash /root/kenshios-setup.sh
   ```
3. Espera a que aparezca `========== KenshiOS: LISTO ==========` (tarda bastante: descarga KDE + gamer = varios GB).

**Verifica que todo quedó bien:**
```bash
ls /usr/bin/plasmashell                       # KDE instalado
ls -l /etc/systemd/system/display-manager.service   # SDDM por defecto
ls /usr/share/backgrounds/kenshios.png        # fondo
ls /usr/share/plymouth/themes/kenshios/logo.png     # splash
grep PRETTY_NAME /etc/os-release              # nombre
```

---

<a name="paso-4"></a>
## 7. Paso 4 — Generar la ISO

1. **Next** para salir del chroot.
2. Avanza con **Next** dejando todo por defecto (Packages → Kernel → Preseed → Boot).
3. **Compression:** deja **gzip** (lo más compatible) → **Generate**.
4. Espera a *"successfully created"*. Verás la ISO con su tamaño real (varios GB). **No cierres la ventana mientras genera.**

Tu ISO queda en la carpeta del proyecto (`~/kenshios/`).

---

<a name="paso-5"></a>
## 8. Paso 5 — Probar la ISO

Crea una **VM nueva** en VirtualBox, con firmware **EFI**, y arranca desde tu ISO. También puedes hacerlo por consola:

```bash
VBoxManage createvm --name "KenshiOS-Test" --ostype Ubuntu_64 --register
VBoxManage modifyvm "KenshiOS-Test" --memory 4096 --cpus 2 --vram 128 \
  --graphicscontroller vmsvga --firmware efi --nic1 nat
VBoxManage storagectl "KenshiOS-Test" --name SATA --add sata --controller IntelAhci --bootable on
VBoxManage createmedium disk --filename "KenshiOS-Test/disk.vdi" --size 25600 --format VDI
VBoxManage storageattach "KenshiOS-Test" --storagectl SATA --port 0 --device 0 --type hdd --medium "KenshiOS-Test/disk.vdi"
VBoxManage storageattach "KenshiOS-Test" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "/ruta/a/KenshiOS.iso"
VBoxManage modifyvm "KenshiOS-Test" --boot1 dvd --boot2 disk
VBoxManage startvm "KenshiOS-Test" --type gui
```

En el menú de arranque elige **"Try or Install KenshiOS"**. Deberías ver tu pantalla de carga, y luego el escritorio KDE o el instalador con tu marca.

---

<a name="errores"></a>
## 9. ⚠️ Errores que encontramos y cómo los resolvimos

**Esta es la parte más valiosa de la guía.** Estos problemas te van a pasar; aquí está la solución real.

### ❌ Error 1 — Cubic falla: *"Unable to link to the standard Linux file system"* (Ubuntu 24.04 / 26.04)

- **Qué pasa:** al generar, Cubic se cuelga en el paso *"Compress the customized Linux file system"* con ese error.
- **Causa:** las versiones nuevas de Ubuntu (24.04, 25.x, 26.04) usan un **sistema de archivos en capas** (`minimal.squashfs` + `minimal.standard.squashfs` + `minimal.standard.live.squashfs`) que Cubic todavía no remasteriza bien.
- **Si intentas armar la ISO a mano con `xorriso`**, arranca por GRUB pero da **kernel panic**: `VFS: Unable to mount root fs on unknown-block(0,0)`. Probamos compresión `xz` y `zstd`: mismo panic. **No es la compresión, es el formato de capas.**
- ✅ **Solución:** usa **Ubuntu 22.04.5 LTS** como base. Usa el formato antiguo (un solo `filesystem.squashfs`) que Cubic genera perfecto, sin bugs, sin xorriso manual.

> 📌 **Regla de oro:** para remasterizar con Cubic, usa una base LTS probada (22.04). Las versiones bleeding-edge no valen el dolor de cabeza.

### ❌ Error 2 — *"Not enough space on the disk"* al generar

- **Causa:** el disco de la VM se llenó (proyectos viejos de Cubic ocupan mucho: cada `custom-root` son ~12 GB).
- ✅ **Solución:** borra los proyectos que ya no uses y vuelve a **Generate**:
  ```bash
  df -h /                        # ver espacio
  rm -rf ~/proyecto-viejo        # liberar
  ```

### ❌ Error 3 — *"Failed to start Simple Desktop Display Manager (SDDM)"*

- **Qué pasa:** la ISO arranca y muestra el fondo, pero la pantalla de login de KDE (**SDDM**) falla en bucle.
- **Causa:** SDDM necesita aceleración gráfica (OpenGL) que una **VM sin GPU** no tiene, y además entra en conflicto con **GDM** (el gestor de login de GNOME, que viene instalado). El instalador de GNOME sí funciona porque GDM usa renderizado por software como respaldo.
- 🟡 **Mejora parcial** (ayuda pero puede no bastar en una VM): forzar renderizado por software en SDDM:
  ```bash
  mkdir -p /etc/sddm.conf.d
  cat > /etc/sddm.conf.d/10-vm.conf <<EOF
  [General]
  GreeterEnvironment=QT_QUICK_BACKEND=software,QSG_RENDER_LOOP=basic
  EOF
  ```
- ✅ **Solución robusta (recomendada):** **no uses SDDM; quédate con GDM** (el gestor de login de Ubuntu, que funciona perfecto en VMs y PCs). Solo instala KDE y deja que GDM ofrezca la sesión "Plasma". Es decir, en el script **omite** el bloque que fuerza SDDM:
  ```bash
  # NO hagas esto si quieres máxima compatibilidad:
  #   ln -sf .../sddm.service /etc/systemd/system/display-manager.service
  #   echo "/usr/sbin/sddm" > /etc/X11/default-display-manager
  # En su lugar: deja GDM y elige "Plasma (X11)" en la pantalla de login.
  ```
  Con GDM, en la pantalla de inicio de sesión pulsas el engranaje ⚙️ y eliges **"Plasma"**. KDE arranca sin problemas.

> 📌 **Lección:** mezclar dos gestores de login (GDM + SDDM) causa conflictos. Elige uno. GDM es el más compatible; SDDM es más "KDE puro" pero quisquilloso en VMs sin GPU.

### ⚠️ Avisos que puedes IGNORAR (no son errores)

- `couldn't connect to zsys daemon ... /run/zsysd.sock` → normal dentro del chroot (el servicio solo corre en un sistema arrancado).
- `Err: file:/cdrom ... Release ... File not found` → normal, Cubic usa los repos de internet en su lugar.
- `Failed to create stream fd` al entrar al chroot → inofensivo.

---

<a name="iterar"></a>
## 10. Cómo iterar SIN rehacer la ISO cada vez

**No generes una ISO por cada cambio.** La ISO es el "instalador", el producto final. Para trabajar:

1. **Instala KenshiOS UNA vez** en una VM (o en un PC real).
2. En ese sistema ya instalado, haz tus cambios **en vivo** (instala apps, cambia configs) y pruébalos al instante. **Cero rebuilds.**
3. Cuando un cambio te convenza, apúntalo en `kenshios-setup.sh`.
4. **Genera una ISO nueva solo cuando quieras lanzar una versión nueva** para distribuir.

---

<a name="updates"></a>
## 11. Sistema de actualizaciones

KenshiOS trae un comando `kenshios-update` que baja cambios desde un repo de GitHub **sin reinstalar ni generar ISO nueva**. Así se mantiene una distro de verdad.

**Cómo funciona:**
- El sistema guarda su versión en `/etc/kenshios-version`.
- Al iniciar sesión, compara con el archivo `version` del repo de updates y **avisa con una notificación** si hay una nueva.
- El usuario ejecuta `kenshios-update`, que hace `git pull` del repo y ejecuta su `apply.sh`.

**Para lanzar una actualización** (tú, el creador):
1. Edita `apply.sh` del repo de updates con los cambios.
2. Sube el número de `version` (de `1` a `2`).
3. `git push`. Todos los KenshiOS avisarán y aplicarán con `kenshios-update`.

---

<a name="script"></a>
## 12. El script maestro completo

Está en el archivo [`kenshios-setup.sh`](kenshios-setup.sh) de este repositorio. Hace, en orden:

1. Instala herramientas de hacking + base
2. Instala KDE Plasma + SDDM (con renderizado por software)
3. Pone tu fondo de pantalla
4. Cambia el nombre del sistema
5. Configura la pantalla de carga (Plymouth)
6. Pone fondo al menú GRUB
7. Optimizaciones para bajos recursos (ZRAM, Baloo off, animaciones)
8. Ventana de bienvenida al primer arranque
9. Sistema de actualizaciones
10. Kit gamer (Steam, Lutris, Wine, Vulkan…)
11. Limpieza para reducir tamaño

---

## 📜 Licencia y créditos

KenshiOS está basado en **Ubuntu** (© Canonical) y software libre. Úsalo y modifícalo libremente.

Creado como proyecto de aprendizaje de **hacking ético** y **remasterización de Linux**. 🐧💜
