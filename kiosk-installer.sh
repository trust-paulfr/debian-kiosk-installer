#!/bin/bash

# be new
apt-get update

# get software
apt-get install \
	unclutter \
    xorg \
    chromium \
    openbox \
    lightdm \
    locales \
    -y

# dir
mkdir -p /home/kiosk/.config/openbox

# create group
groupadd kiosk

# create user if not exists
id -u kiosk &>/dev/null || useradd -m kiosk -g kiosk -s /bin/bash 

# rights
chown -R kiosk:kiosk /home/kiosk

# remove virtual consoles
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

# create config
if [ -e "/etc/lightdm/lightdm.conf" ]; then
  mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi
cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
autologin-user=kiosk
autologin-session=openbox
EOF

# create autostart
if [ -e "/home/kiosk/.config/openbox/autostart" ]; then
  mv /home/kiosk/.config/openbox/autostart /home/kiosk/.config/openbox/autostart.backup
fi
cat > /home/kiosk/.config/openbox/autostart << EOF
#!/bin/bash

unclutter -idle 0.1 -grab -root &

mkdir -p "$LOCAL_HTML_DIR"
cat > "$LOCAL_HTML_FILE" << EOF
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
EOF

# Dossier pour la page locale
LOCAL_HTML_DIR="/home/kiosk/offline"
LOCAL_HTML_FILE="$LOCAL_HTML_DIR/index.html"
TARGET_URL="https://neave.tv/"

# Fonction pour vérifier la connexion Internet
check_connection() {
    curl -Is "$TARGET_URL" --max-time 5 | head -n 1 | grep "200 OK" > /dev/null
}

if check_connection; then
    CHROMIUM_URL="$TARGET_URL"
else
    CHROMIUM_URL="file://$LOCAL_HTML_FILE"
fi

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

    if check_connection; then
        CHROMIUM_URL="$TARGET_URL"
    else
        CHROMIUM_URL="file://$LOCAL_HTML_FILE"
    fi

  sleep 5
done &
EOF

echo "Done!"
