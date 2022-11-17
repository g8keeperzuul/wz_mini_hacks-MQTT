#!/bin/sh

# Run from your device
# This script will:
#   + overwrite /configs/.user_config iCamera settings with all default settings
#   + overwrite web server init script with a fixed version
#   + reboot the device for all the changes to take effect

# overwrite iCamera settings new full, default version (backup the original)
echo "Backing up and applying default iCamera settings (.user_config)..."
mv /configs/.user_config /media/mmc/mosquitto/installer/.user_config.original
cp /media/mmc/mosquitto/installer/DOTuser_config /configs/.user_config

# fix web server init script (backup the original)
echo "Updating httpd init script..."
mv /opt/wz_mini/etc/network.d/S10httpd /media/mmc/mosquitto/installer/S10httpd.original
cp /media/mmc/mosquitto/installer/S10httpd /opt/wz_mini/etc/network.d/

# add daemons for mqtt-status.sh and mqtt-control.sh
echo "Setting up MQTT daemon..."
cp /media/mmc/mosquitto/bin/mqtt-daemon.sh /opt/wz_mini/etc/rc.local.d/S50mqtt-daemon

echo "Rebooting device..."
reboot
