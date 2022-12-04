#!/opt/wz_mini/bin/bash

# same as /media/mmc/wz_mini/wz_mini.conf
MASTER_CONFIG="/opt/wz_mini/wz_mini.conf"  # needed for CUSTOM_HOSTNAME'
MQTT_CONFIG="/media/mmc/mosquitto/mosquitto.conf"

source ${MASTER_CONFIG}
source ${MQTT_CONFIG}

TOPIC_BASE="${MQTT_HA_TOPIC_BASE}/camera/${CUSTOM_HOSTNAME}"
mqtt_publish(){ # $1 = /my/topic  $2 = payload
    echo "MQTT publish $1 -> $2"
    # Note: all discovery messages are RETAINED
	${MOSQUITTO_PUB_BIN} -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "$1" ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -r -m "$2"
}

# to avoid errors on boot with motion not being available, we wait
sleep 10
while true; do
    ret=$(cmd waitmotion 10)

    if [[ "$ret" == "detect"* ]]; then
        printf "\nMotion-detected - ${TOPIC_BASE}/motion/detected ON"
        mqtt_publish "${TOPIC_BASE}/motion/detected" "ON"
        sleep 30
    else
        mqtt_publish "${TOPIC_BASE}/motion/detected" "OFF"
    fi
done