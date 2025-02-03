#!/bin/bash

# Mise à jour des paquets
apt-get update

# Installation des logiciels
apt-get install \
    unclutter \
    xorg \
    curl \
    chromium \
    openbox \
    lightdm \
    locales \
    -y

# Création des répertoires
mkdir -p /home/kiosk/.config/openbox

# Création du groupe et de l'utilisateur kiosk
groupadd kiosk
id -u kiosk &>/dev/null || useradd -m kiosk -g kiosk -s /bin/bash 

# Droits sur le répertoire utilisateur
chown -R kiosk:kiosk /home/kiosk

# Suppression des consoles virtuelles
if [ -e "/etc/X11/xorg.conf" ]; then
  mv /etc/X11/xorg.conf /etc/X11/xorg.conf.backup
fi

cat > /etc/X11/xorg.conf << EOF
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "AutoAddDevices" "false"
EndSection

Section "InputClass"
    Identifier "Disable all keyboard input"
    MatchIsKeyboard "on"
    Option "Ignore" "on"
EndSection

Section "InputClass"
    Identifier "Disable all pointer input"
    MatchIsPointer "on"
    Option "Ignore" "on"
EndSection
EOF

# Configuration de LightDM
if [ -e "/etc/lightdm/lightdm.conf" ]; then
  mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi

cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
autologin-user=kiosk
autologin-session=openbox
EOF

# Dossier et fichier HTML local
LOCAL_HTML_DIR="/home/kiosk/offline"
LOCAL_HTML_FILE="$LOCAL_HTML_DIR/index.html"

mkdir -p "$LOCAL_HTML_DIR"

cat > "$LOCAL_HTML_FILE" << HTML_EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pas de connexion Internet</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: red; }
    </style>
</head>
<body>
    <h1>Pas de connexion Internet</h1>
    <p>Nous essayons de rétablir la connexion...</p>
</body>
</html>
HTML_EOF

# URL cible
TARGET_URL="https://neave.tv/"

# Fonction de vérification de la connexion
check_connection() {
    curl -Is "$TARGET_URL" --max-time 5 | grep "HTTP/2\|HTTP/1.1" > /dev/null
}

# Définition de l'URL à ouvrir
if check_connection; then
    CHROMIUM_URL="$TARGET_URL"
else
    CHROMIUM_URL="file://$LOCAL_HTML_FILE"
fi

# Création du fichier autostart
if [ -e "/home/kiosk/.config/openbox/autostart" ]; then
  mv /home/kiosk/.config/openbox/autostart /home/kiosk/.config/openbox/autostart.backup
fi

cat > /home/kiosk/.config/openbox/autostart << SCRIPT_EOF
#!/bin/bash

unclutter -idle 0.1 -grab -root &

while :
do
  xrandr --auto
  chromium \
    --no-first-run \
    --start-maximized \
    --disable \
    --disable-translate \
    --disable-infobars \
    --disable-suggestions-service \
    --disable-save-password-bubble \
    --disable-session-crashed-bubble \
    --incognito \
    --kiosk "$CHROMIUM_URL"
  sleep 5
done &
SCRIPT_EOF

echo "Installation terminée !"
