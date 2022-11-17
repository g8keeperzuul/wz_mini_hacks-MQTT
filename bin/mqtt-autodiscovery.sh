#!/opt/wz_mini/bin/bash

# same as /media/mmc/wz_mini/wz_mini.conf
MASTER_CONFIG="/opt/wz_mini/wz_mini.conf"  # needed for CUSTOM_HOSTNAME'
MQTT_CONFIG="/media/mmc/mosquitto/mosquitto.conf"

source ${MASTER_CONFIG}
source ${MQTT_CONFIG}

mqtt_publish(){ # $1 = /my/topic  $2 = payload
    echo "MQTT publish $1 -> $2"
    # Note: all discovery messages are RETAINED
	${MOSQUITTO_PUB_BIN} -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "$1" ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -r -m "$2"
}

DEVICE_MODEL=$(/opt/wz_mini/etc/init.d/s04model start | grep detected | cut -f1 -d ' ')
FW_VER=$(tail -n1 /configs/app.ver | cut -f2 -d=  )
MAC=$(ifconfig wlan0  | grep HWaddr | cut -d 'HW' -f2 | cut -d ' ' -f2)

# Model after HA MQTT discovery device json
#   "device": {
#     "name": "Gas Monitor",
#     "identifiers": "98:CD:AC:D3:63:18",
#     "mf": "UnexpectedMaker",
#     "mdl": "TinyPICO",
#     "sw": "20221020.1300"
#   }
DEVICE_JSON="{\"name\":\"${CUSTOM_HOSTNAME}\", \"ids\":\"${MAC}\", \"mf\":\"Wyze\", \"mdl\":\"${DEVICE_MODEL}\", \"sw\": \"${FW_VER}\"}"
TOPIC_BASE="${MQTT_HA_TOPIC_BASE}/camera/${CUSTOM_HOSTNAME}"

# https://www.home-assistant.io/integrations/mqtt/
# <discovery_prefix>/<component>/[<node_id>/]<object_id>/config
# homeassistant/switch|number|sensor/wyzec3_838c/<label>/config
# homeassistant/sensor/environmental/featherm0_humidity/config
DISCOVERY_PREFIX="${MQTT_HA_TOPIC_BASE}"
NODE_ID="${CUSTOM_HOSTNAME}"

# Configurations
mqtt_publish "${DISCOVERY_PREFIX}/number/${NODE_ID}/refresh_rate/config" "{\"name\": \"${NODE_ID} Refresh Rate\", \"unique_id\": \"${NODE_ID}-refresh-rate\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:refresh\", \"state_topic\": \"${TOPIC_BASE}/refresh_rate\", \"command_topic\": \"${TOPIC_BASE}/refresh_rate/set\", \"entity_category\": \"config\",\"unit_of_measurement\": \"seconds\", \"min\":30, \"max\":3600, \"step\":30 }"

# Controls
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/flip_vert/config" "{\"name\": \"${NODE_ID} Flip Vertical\", \"unique_id\": \"${NODE_ID}-flip-vertical\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:flip-vertical\", \"state_topic\": \"${TOPIC_BASE}/flip_vert\", \"command_topic\": \"${TOPIC_BASE}/flip_vert/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/flip_horz/config" "{\"name\": \"${NODE_ID} Flip Horizontal\", \"unique_id\": \"${NODE_ID}-flip-horizontal\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:flip-horizontal\", \"state_topic\": \"${TOPIC_BASE}/flip_horz\", \"command_topic\": \"${TOPIC_BASE}/flip_horz/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/indicator/config" "{\"name\": \"${NODE_ID} Indicator LED\", \"unique_id\": \"${NODE_ID}-indicator\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:led-on\", \"state_topic\": \"${TOPIC_BASE}/leds/indicator\", \"command_topic\": \"${TOPIC_BASE}/leds/indicator/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/leds-ir_near/config" "{\"name\": \"${NODE_ID} IR Near\", \"unique_id\": \"${NODE_ID}-ir-near\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:car-light-dimmed\", \"state_topic\": \"${TOPIC_BASE}/leds/ir_near\", \"command_topic\": \"${TOPIC_BASE}/leds/ir_near/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/leds-ir_far/config" "{\"name\": \"${NODE_ID} IR Far\", \"unique_id\": \"${NODE_ID}-ir-far\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:car-light-high\", \"state_topic\": \"${TOPIC_BASE}/leds/ir_far\", \"command_topic\": \"${TOPIC_BASE}/leds/ir_far/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/night_mode/config" "{\"name\": \"${NODE_ID} Night Mode\", \"unique_id\": \"${NODE_ID}-night-mode\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:lightbulb-night\", \"state_topic\": \"${TOPIC_BASE}/night_mode\", \"command_topic\": \"${TOPIC_BASE}/night_mode/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/night_mode-auto/config" "{\"name\": \"${NODE_ID} Night Mode Auto\", \"unique_id\": \"${NODE_ID}-night-mode-auto\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:lightbulb-auto\", \"state_topic\": \"${TOPIC_BASE}/night_mode/auto\", \"command_topic\": \"${TOPIC_BASE}/night_mode/auto/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/night_mode-early_activation/config" "{\"name\": \"${NODE_ID} Night Mode Early Activation\", \"unique_id\": \"${NODE_ID}-night-mode-early-activation\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:weather-sunset\", \"state_topic\": \"${TOPIC_BASE}/night_mode/early_activation\", \"command_topic\": \"${TOPIC_BASE}/night_mode/early_activation/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/osd_time/config" "{\"name\": \"${NODE_ID} OSD Timestamp\", \"unique_id\": \"${NODE_ID}-osd-time\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:clock-outline\", \"state_topic\": \"${TOPIC_BASE}/osd_time\", \"command_topic\": \"${TOPIC_BASE}/osd_time/set\"}"
mqtt_publish "${DISCOVERY_PREFIX}/switch/${NODE_ID}/web_console/config" "{\"name\": \"${NODE_ID} Web Console\", \"unique_id\": \"${NODE_ID}-web-console\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:console-network\", \"state_topic\": \"${TOPIC_BASE}/web_console\", \"command_topic\": \"${TOPIC_BASE}/web_console/set\"}"

# Diagnostics
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/web_console-active/config" "{\"name\": \"${NODE_ID} Web Console Active\", \"unique_id\": \"${NODE_ID}-web-console-active\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:run\", \"state_topic\": \"${TOPIC_BASE}/web_console/active\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-port/config" "{\"name\": \"${NODE_ID} RTSP Server Port\", \"unique_id\": \"${NODE_ID}-rtsp-port\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:export\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/port\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/rtsp_server-authentication/config" "{\"name\": \"${NODE_ID} RTSP Authentication\", \"unique_id\": \"${NODE_ID}-rtsp-authentication\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:lock\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/authentication\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/rtsp_server-channel1/config" "{\"name\": \"${NODE_ID} RTSP Channel 1\", \"unique_id\": \"${NODE_ID}-rtsp-channel1\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:numeric-1-box\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/rtsp_server-channel2/config" "{\"name\": \"${NODE_ID} RTSP Channel 2\", \"unique_id\": \"${NODE_ID}-rtsp-channel2\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:numeric-2-box\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/rtsp_server-channel1-audio/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 Audio\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-audio\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:volume-high\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/audio\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/binary_sensor/${NODE_ID}/rtsp_server-channel2-audio/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 Audio\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-audio\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:volume-high\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/audio\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel1-bitrate_max/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 Bitrate Max\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-bitrate_max\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:speedometer\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/bitrate_max\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel2-bitrate_max/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 Bitrate Max\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-bitrate_max\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:speedometer\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/bitrate_max\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel1-bitrate_target/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 Bitrate Target\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-bitrate_target\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:speedometer-medium\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/bitrate_target\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel2-bitrate_target/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 Bitrate Target\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-bitrate_target\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:speedometer-medium\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/bitrate_target\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel1-enc_params/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 Encode Params\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-enc_params\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:movie-open-cog\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/enc_params\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel2-enc_params/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 Encode Params\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-enc_params\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:movie-open-cog\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/enc_params\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel1-url/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 URL\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-url\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:web\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/url\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel2-url/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 URL\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-url\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:web\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/url\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel1-fps/config" "{\"name\": \"${NODE_ID} RTSP Channel 1 FPS\", \"unique_id\": \"${NODE_ID}-rtsp-channel1-fps\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:filmstrip\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel1/fps\", \"entity_category\": \"diagnostic\"}"
mqtt_publish "${DISCOVERY_PREFIX}/sensor/${NODE_ID}/rtsp_server-channel2-fps/config" "{\"name\": \"${NODE_ID} RTSP Channel 2 FPS\", \"unique_id\": \"${NODE_ID}-rtsp-channel2-fps\", \"device\": ${DEVICE_JSON}, \"icon\": \"mdi:filmstrip\", \"state_topic\": \"${TOPIC_BASE}/rtsp_server/channel2/fps\", \"entity_category\": \"diagnostic\"}"