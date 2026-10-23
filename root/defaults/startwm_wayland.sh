#!/bin/bash

# Power related
setterm blank 0
setterm powerdown 0

# Directories
sudo rm -f /usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service
mkdir -p "${HOME}/.config/autostart" "${HOME}/.XDG" "${HOME}/.local/share/"
chmod 700 "${HOME}/.XDG"

# Create startup script if it does not exist (keep in sync with openbox)
STARTUP_FILE="${HOME}/.config/autostart/autostart.desktop"
if [ ! -f "${STARTUP_FILE}" ]; then
  echo "[Desktop Entry]" > $STARTUP_FILE
  echo "Exec=bash /config/.config/openbox/autostart" >> $STARTUP_FILE
  echo "Icon=dialog-scripts" >> $STARTUP_FILE
  echo "Name=autostart" >> $STARTUP_FILE
  echo "Path=" >> $STARTUP_FILE
  echo "Type=Application" >> $STARTUP_FILE
  echo "X-GNOME-Autostart-enabled=true" >> $STARTUP_FILE
  chmod +x $STARTUP_FILE
fi

# Session identity normally set by GDM.
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_DESKTOP=ubuntu
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu

# Start DE. There is no systemd here (s6-overlay is PID 1), so run
# gnome-session in --builtin mode: it launches gnome-shell and the
# gsd-* daemons itself from /etc/xdg/autostart instead of handing the
# session to `systemd --user` targets.
# gnome-shell runs as an X11 compositor on Xwayland inside the Selkies
# Wayland compositor (a native Wayland gnome-shell would need logind).
WAYLAND_DISPLAY=wayland-1 Xwayland :1 &
sleep 2
exec dbus-launch --exit-with-session \
  /usr/bin/gnome-session --builtin --session=ubuntu > "${HOME}/.xsession-errors" 2>&1
