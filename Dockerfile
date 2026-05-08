FROM ghcr.io/linuxserver/baseimage-selkies:ubuntunoble

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"
ARG DEBIAN_FRONTEND="noninteractive"

# title
ENV TITLE="Ubuntu KDE" \
    NO_GAMEPAD=true

# Disable libuv io_uring backend container-wide so VSCode's bundled
# Electron/Node runtime (and anything else libuv-based) falls back to
# epoll. CRIU can't dump anon_inode:[io_uring] fds, so leaving this on
# breaks checkpoint of any process that ends up using the io_uring path
# (libuv >=1.49 enables it by default for fs ops).
ENV UV_USE_IO_URING=0

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/webtop-logo.png && \
  echo "**** install packages ****" && \
  add-apt-repository ppa:xtradeb/apps && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    chromium \
    dolphin \
    gwenview \
    kde-config-gtk-style \
    kdialog \
    kfind \
    khotkeys \
    kio-extras \
    knewstuff-dialog \
    konsole \
    ksystemstats \
    kubuntu-settings-desktop \
    kubuntu-wallpapers \
    kubuntu-web-shortcuts \
    kwin-addons \
    kwin-x11 \
    kwrite \
    plasma-desktop \
    plasma-workspace \
    qml-module-qt-labs-platform \
    systemsettings && \
  echo "**** application tweaks ****" && \
  sed -i \
    's#^Exec=.*#Exec=/usr/local/bin/wrapped-chromium#g' \
    /usr/share/applications/chromium.desktop && \
  echo "**** kde tweaks ****" && \
  sed -i \
    's/applications:org.kde.discover.desktop,/applications:org.kde.konsole.desktop,/g' \
    /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# ==== custom packages ====
ENV SAL_USE_VCLPLUGIN=qt5
RUN \
  echo "**** add microsoft repo for vscode ****" && \
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg && \
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list && \
  echo "**** add mozilla ppa for thunderbird (avoid snap shim) ****" && \
  add-apt-repository -y ppa:mozillateam/ppa && \
  printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-ppa && \
  echo "**** install custom apps ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    adwaita-icon-theme \
    breeze-icon-theme \
    code \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-noto-core \
    gimp \
    gimp-data-extras \
    gtk2-engines-pixbuf \
    hicolor-icon-theme \
    libaa1 \
    libqt6svg6 \
    librsvg2-common \
    libwmf-0.2-7 \
    mypaint-brushes \
    libreoffice-calc \
    libreoffice-impress \
    libreoffice-qt5 \
    libreoffice-style-breeze \
    libreoffice-writer \
    thunderbird \
    vlc && \
  echo "**** wire up CRIU-friendly wrappers for vscode + thunderbird ****" && \
  sed -i \
    's#^Exec=/usr/share/code/code#Exec=/usr/local/bin/wrapped-code#g' \
    /usr/share/applications/code.desktop && \
  sed -i \
    's#^Exec=thunderbird #Exec=/usr/local/bin/wrapped-thunderbird #g' \
    /usr/share/applications/thunderbird.desktop && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
# ==== end custom packages ====

# ==== pyautogui for the bench (Agent-S / OSWorld actions) ====
# The bench runs `python3 -c <pyautogui code>` inside the container
# from osworld_run_branch's action exec for screenshots + clicks.
#
# Required:
#   python3-pip               install pyautogui + Pillow from PyPI
#   python3-xlib              X11 client lib pyautogui uses
#   python3-tk                tkinter — pyautogui's `mouseinfo`
#                             dependency imports it at module load.
#                             Earlier attempts to stub mouseinfo via
#                             sitecustomize.py or inline-prepended
#                             code were brittle (mouseinfo exports
#                             several names, and pyautogui imports
#                             them at __init__ time). Just shipping
#                             real tkinter (~50MB) is more reliable.
#   scrot                     used by PIL.ImageGrab as one of the
#                             screenshot backends
#   x11-utils                 provides xdpyinfo, used by the bench's
#                             source_ready_probe
#   xdotool                   pyautogui sometimes uses it for
#                             keyboard/mouse fallbacks
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    python3-pip \
    python3-tk \
    python3-xlib \
    scrot \
    x11-utils \
    xdotool && \
  pip install --no-cache-dir --break-system-packages \
    pyautogui \
    Pillow && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/* \
    /root/.cache

# add local files
COPY /root /

# ports and volumes
EXPOSE 3000
VOLUME /config
