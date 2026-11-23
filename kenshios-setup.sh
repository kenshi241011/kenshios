#!/bin/bash
# =====================================================================
#  KenshiOS - Script maestro de personalizacion (para Cubic / Ubuntu 22.04)
#  Se ejecuta DENTRO del chroot de Cubic como root.
#  Requiere que /root/kenshios.png (fondo) y /root/boot.png (splash)
#  esten copiados antes (con el boton de copiar de Cubic).
# =====================================================================
export DEBIAN_FRONTEND=noninteractive
echo "========== KenshiOS: inicio =========="

# --- Repos y herramientas base ---
apt install -y software-properties-common || true
add-apt-repository -y universe || true
apt update
apt install -y nmap net-tools dnsutils whois curl wget git python3-pip \
  netcat-openbsd hydra john nikto imagemagick libnotify-bin squashfs-tools || true

# --- KDE Plasma (login con GDM; NO sddm: sddm falla en VMs sin GPU) ---
apt install -y kde-plasma-desktop || true
apt install -y gdm3 || true
# Nos aseguramos de NO usar sddm: lo quitamos si se coló como dependencia
apt purge -y sddm 2>/dev/null || true
# GDM como gestor de inicio de sesion (fiable en VMs y PCs)
GDM_SVC=$(find /lib/systemd/system /usr/lib/systemd/system -name gdm3.service 2>/dev/null | head -1)
[ -n "$GDM_SVC" ] && ln -sf "$GDM_SVC" /etc/systemd/system/display-manager.service
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
# Al iniciar sesion, el usuario elige "Plasma (X11)" (GDM lo recuerda despues)

# --- Fondo de pantalla ---
if [ -f /root/kenshios.png ]; then
  cp /root/kenshios.png /usr/share/backgrounds/kenshios.png
  mkdir -p /usr/share/glib-2.0/schemas
  cat > /usr/share/glib-2.0/schemas/99_kenshios.gschema.override <<EOF
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/kenshios.png'
picture-uri-dark='file:///usr/share/backgrounds/kenshios.png'
picture-options='zoom'
[org.gnome.desktop.interface]
color-scheme='prefer-dark'
EOF
  glib-compile-schemas /usr/share/glib-2.0/schemas/ || true
  for d in /usr/share/wallpapers/*/contents/images; do
    for f in "$d"/*; do cp /usr/share/backgrounds/kenshios.png "$f" 2>/dev/null || true; done
  done
fi

# --- Nombre del sistema ---
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="KenshiOS 1.0 (Ethical Hacking Edition)"/' /etc/os-release

# --- Pantalla de carga (Plymouth) ---
if [ -f /root/boot.png ]; then
  mkdir -p /usr/share/plymouth/themes/kenshios
  cp /root/boot.png /usr/share/plymouth/themes/kenshios/logo.png
  cat > /usr/share/plymouth/themes/kenshios/kenshios.plymouth <<EOF
[Plymouth Theme]
Name=KenshiOS
Description=KenshiOS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/kenshios
ScriptFile=/usr/share/plymouth/themes/kenshios/kenshios.script
EOF
  cat > /usr/share/plymouth/themes/kenshios/kenshios.script <<EOF
Window.SetBackgroundTopColor(0,0,0);
Window.SetBackgroundBottomColor(0,0,0);
img = Image("logo.png");
scale = Window.GetWidth() / img.GetWidth();
img = img.Scale(Window.GetWidth(), img.GetHeight() * scale);
sprite = Sprite(img);
sprite.SetX(0);
sprite.SetY(Window.GetHeight() / 2 - img.GetHeight() / 2);
EOF
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/kenshios/kenshios.plymouth 200
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/kenshios/kenshios.plymouth
fi

# --- Fondo del menu GRUB (sistema instalado) ---
if [ -f /usr/share/backgrounds/kenshios.png ]; then
  mkdir -p /boot/grub
  cp /usr/share/backgrounds/kenshios.png /boot/grub/kenshios.png
  sed -i '/^GRUB_BACKGROUND/d' /etc/default/grub
  echo 'GRUB_BACKGROUND="/boot/grub/kenshios.png"' >> /etc/default/grub
fi

# --- Optimizaciones para PC de bajos recursos ---
cat > /etc/xdg/baloofilerc <<EOF
[Basic Settings]
Indexing-Enabled=false
EOF
cat >> /etc/xdg/kdeglobals <<EOF

[KDE]
AnimationDurationFactor=0.3
EOF
apt install -y zram-config || apt install -y systemd-zram-generator || true

# --- Ventana de bienvenida (primer arranque) ---
cat > /usr/local/bin/kenshios-firstrun.sh <<'FRUN'
#!/bin/bash
FLAG="$HOME/.config/kenshios-setup-done"
[ -f "$FLAG" ] && exit 0
mkdir -p "$HOME/.config"
kdialog --title "Bienvenido a KenshiOS" --yesno "Que tipo de PC tienes?\n\nElige el modo de rendimiento:" --yes-label "Bajos recursos" --no-label "Normal"
if [ "$?" = "0" ]; then
  printf '[Basic Settings]\nIndexing-Enabled=false\n' > "$HOME/.config/baloofilerc"
  printf '[KDE]\nAnimationDurationFactor=0\n' > "$HOME/.config/kdeglobals"
  MODE="Bajos recursos (optimizado)"
else
  printf '[Basic Settings]\nIndexing-Enabled=true\n' > "$HOME/.config/baloofilerc"
  printf '[KDE]\nAnimationDurationFactor=1\n' > "$HOME/.config/kdeglobals"
  MODE="Normal (todo activado)"
fi
touch "$FLAG"
kdialog --title "KenshiOS" --msgbox "Modo aplicado: $MODE.\n\nReinicia para aplicar todos los cambios."
FRUN
chmod +x /usr/local/bin/kenshios-firstrun.sh
cat > /etc/xdg/autostart/kenshios-firstrun.desktop <<EOF
[Desktop Entry]
Type=Application
Name=KenshiOS First Run
Exec=/usr/local/bin/kenshios-firstrun.sh
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
EOF

# --- Sistema de actualizaciones ---
echo "1" > /etc/kenshios-version
cat > /usr/local/bin/kenshios-update <<'UPD'
#!/bin/bash
REPO="https://github.com/kenshi241011/kenshios-updates.git"
DIR="/opt/kenshios-updates"
echo "Buscando actualizaciones de KenshiOS..."
if [ -d "$DIR/.git" ]; then sudo git -C "$DIR" pull --quiet
else sudo git clone --quiet "$REPO" "$DIR" || { echo "Sin conexion."; exit 1; }; fi
[ -f "$DIR/apply.sh" ] && sudo bash "$DIR/apply.sh"
[ -f "$DIR/version" ] && sudo cp "$DIR/version" /etc/kenshios-version
echo "KenshiOS actualizado."
UPD
chmod +x /usr/local/bin/kenshios-update
cat > /usr/local/bin/kenshios-check-update <<'CHK'
#!/bin/bash
LOCAL=$(cat /etc/kenshios-version 2>/dev/null || echo 0)
REMOTE=$(curl -fsSL https://raw.githubusercontent.com/kenshi241011/kenshios-updates/main/version 2>/dev/null)
[ -z "$REMOTE" ] && exit 0
if [ "$REMOTE" -gt "$LOCAL" ] 2>/dev/null; then
  notify-send -i system-software-update "KenshiOS" "Actualizacion disponible (v$REMOTE). Ejecuta 'kenshios-update' en una terminal."
fi
CHK
chmod +x /usr/local/bin/kenshios-check-update
cat > /etc/xdg/autostart/kenshios-check-update.desktop <<EOF
[Desktop Entry]
Type=Application
Name=KenshiOS Update Check
Exec=/usr/local/bin/kenshios-check-update
X-KDE-autostart-phase=2
EOF

# --- Kit gamer ---
dpkg --add-architecture i386
add-apt-repository -y multiverse || true
apt update
apt install -y steam-installer lutris gamemode mangohud wine \
  mesa-vulkan-drivers mesa-vulkan-drivers:i386 || true

# --- Limpieza para que pese menos ---
apt clean
rm -rf /var/lib/apt/lists/* /usr/share/doc/* /tmp/* /var/tmp/* 2>/dev/null

echo "========== KenshiOS: LISTO =========="
