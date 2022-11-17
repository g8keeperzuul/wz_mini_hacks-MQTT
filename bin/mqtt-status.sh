#!/opt/wz_mini/bin/bash

# Query camera state via MQTT
# Supported features:
#   /osd_time -> ON|OFF
#   /leds/indicator -> ON|OFF
#   /night_mode  -> ON|OFF
#   /night_mode/auto -> ON|OFF
#   /night_mode/early_activation -> ON|OFF
#   /leds/ir_near -> ON|OFF
#   /leds/ir_far -> ON|OFF
#   /flip_vert -> ON|OFF
#   /flip_horz -> ON|OFF

#	/refresh_rate -> [integer]
#   /status -> {"last_boot":"2022-11-08 18:07:59","ts":"2022-11-09T16:07:50+00:00","ip":"10.0.0.172","link_quality":75,"signal_level":66,"noise_level":0,"bit_rate":"72.2 Mb/s","device":{"name":"wyzec3_838c", "identifiers":"D0:3F:27:5D:83:8C", "mf":"Wyze", "mdl":"WYZE_CAKP2JFUS", "sw": "4.36.9.139"}}

#   /rtsp_server/port -> [integer]
#   /rtsp_server/authentication -> ON|OFF
#   /rtsp_server/channel1 -> ON|OFF
#   /rtsp_server/channel1/audio -> true|false
#   /rtsp_server/channel1/fps -> [integer]
#   /rtsp_server/channel1/url -> [url]
#   /rtsp_server/channel2 -> true|false
#   /rtsp_server/channel2/audio -> true|false
#   /rtsp_server/channel2/fps -> [integer]
#   /rtsp_server/channel2/url -> [url]
#   /rtsp_server/channel1/bitrate_max -> [integer]
#   /rtsp_server/channel2/bitrate_max -> [integer]
#   /rtsp_server/channel1/bitrate_target -> [integer]
#   /rtsp_server/channel2/bitrate_target -> [integer]
#   /rtsp_server/channel1/enc_params -> [string]
#   /rtsp_server/channel2/enc_params -> [string]
#   /web_console -> ON|OFF
#   /web_console/active -> ON|OFF  (if httpd is running)

# same as /media/mmc/wz_mini/wz_mini.conf
MASTER_CONFIG="/opt/wz_mini/wz_mini.conf"
ICAMERA_CONFIG="/configs/.user_config"
MQTT_CONFIG="/media/mmc/mosquitto/mosquitto.conf"

source ${MASTER_CONFIG}
source ${MQTT_CONFIG}

TOPIC_BASE="${MQTT_HA_TOPIC_BASE}/camera/${CUSTOM_HOSTNAME}"
mqtt_publish(){ # $1 = /my/topic  $2 = payload
    echo "MQTT publish ${TOPIC_BASE}$1 -> $2"
	${MOSQUITTO_PUB_BIN} -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${TOPIC_BASE}$1" ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$2"
}

# Returns value part of KEY=VALUE where key is $1
get_icamera_value_for_key(){
    grep "$1" "${ICAMERA_CONFIG}" | cut -f2 -d"="
}

# Returns "on" for 1, "off" for everything else
convert_binary_value(){
    if [ "$1" == "1" ]; then
        echo "ON"        
    else
        echo "OFF"
    fi
}

# Camera settings read from /configs/.user_config (parsed with get_icamera_value_for_key())
# Device settings read from /opt/wz_mini/wz_mini.conf (imported as env vars)
# Some device settings can be written using cmd (which calls patched iCamera on port 4000 via nc)
while true
do
	mqtt_publish "/refresh_rate" "${STATUSINTERVAL}"

    VAL_FLAG=$(convert_binary_value $(get_icamera_value_for_key "osdSwitch")) # Show OSD timestamp (1=Enabled, 2=Disabled)        
    mqtt_publish "/osd_time" "${VAL_FLAG}"

    VAL_FLAG=$(convert_binary_value $(get_icamera_value_for_key "indicator")) # Camera Status Light (1=Enabled, 2=Disabled)        
    mqtt_publish "/leds/indicator" "${VAL_FLAG}"
    
    # nightvision can explicitly be enabled with "cmd irled ON|OFF"
    # this configuration setting may not reflect the actual state (.user_config says nightVision is off, but "cmd irled on" was issued; )
    NIGHTVISION_VAL=$(get_icamera_value_for_key "nightVision") # 1=(always) On, 2= (always) Off, 3=Auto
    VAL_FLAG=$(convert_binary_value $NIGHTVISION_VAL)
    mqtt_publish "/night_mode" "${VAL_FLAG}"

    if [ "$NIGHTVISION_VAL" == "3" ]; then
        VAL_FLAG="ON"
    else
        VAL_FLAG="OFF"
    fi
    mqtt_publish "/night_mode/auto" "${VAL_FLAG}"

    VAL_FLAG=$(convert_binary_value $(get_icamera_value_for_key "night_cut_thr")) # Nightvision activation threshold (1=Dusk, 2=Dark)
    mqtt_publish "/night_mode/early_activation" "${VAL_FLAG}"

    VAL_FLAG=$(convert_binary_value $(get_icamera_value_for_key "night_led_ex")) # Night Vision IR Lights Near (1=Near, 2=Off or Far)
    mqtt_publish "/leds/ir_near" "${VAL_FLAG}"

    VAL_FLAG=$(convert_binary_value $(get_icamera_value_for_key "NIGHT_LED_flag")) # Night Vision IR Lights Far (1=Far, 2=Off or Near)
    mqtt_publish "/leds/ir_far" "${VAL_FLAG}"

    FLIP_VAL=$(get_icamera_value_for_key "verSwitch") # Flip Vertical (1=Disabled, 2=Enabled)  <<< notice opposite from other attributes
    if [ "$FLIP_VAL" == "2" ]; then
        VAL_FLAG="ON"
    else
        VAL_FLAG="OFF"
    fi    
    mqtt_publish "/flip_vert" "${VAL_FLAG}"

    FLIP_VAL=$(get_icamera_value_for_key "horSwitch") # Flip Horizontal (1=Disabled, 2=Enabled)  <<< notice opposite from other attributes
    if [ "$FLIP_VAL" == "2" ]; then
        VAL_FLAG="ON"
    else
        VAL_FLAG="OFF"
    fi   
    mqtt_publish "/flip_horz" "${VAL_FLAG}" 



	# "${TOPIC}/motion/detection")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/detection ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_detection status)"
	# ;;

	# "${TOPIC}/motion/detection/set ON")
	#   motion_detection on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/detection ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_detection status)"
	# ;;

	# "${TOPIC}/motion/detection/set OFF")
	#   motion_detection off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/detection ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_detection status)"
	# ;;

	# "${TOPIC}/motion/led")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/led ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_led status)"
	# ;;

	# "${TOPIC}/motion/led/set ON")
	#   motion_led on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/led ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_led status)"
	# ;;

	# "${TOPIC}/motion/led/set OFF")
	#   motion_led off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/led ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_led status)"
	# ;;
	
	# "${TOPIC}/motion/snapshot")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_snapshot status)"
	# ;;

	# "${TOPIC}/motion/snapshot/set ON")
	#   motion_snapshot on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_snapshot status)"
	# ;;

	# "${TOPIC}/motion/snapshot/set OFF")
	#   motion_snapshot off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_snapshot status)"
	# ;;

	# "${TOPIC}/motion/video")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/video ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_video status)"
	# ;;

	# "${TOPIC}/motion/video/set ON")
	#   motion_video on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/video ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_video status)"
	# ;;

	# "${TOPIC}/motion/video/set OFF")
	#   motion_video off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/video ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_video status)"
	# ;;

	# "${TOPIC}/motion/mqtt_publish")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_publish ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_publish status)"
	# ;;

	# "${TOPIC}/motion/mqtt_publish/set ON")
	#   motion_mqtt_publish on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_publish ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_publish status)"
	# ;;

	# "${TOPIC}/motion/mqtt_publish/set OFF")
	#   motion_mqtt_publish off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_publish ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_publish status)"
	# ;;
	

	# "${TOPIC}/motion/mqtt_snapshot")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_snapshot status)"
	# ;;
		
	# "${TOPIC}/snapshot/image GET")
	#   /system/sdcard/bin/getimage > "/tmp/mqtt_snapshot"
	#   /system/sdcard/bin/jpegoptim -m 50 "/tmp/mqtt_snapshot"
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/snapshot/image ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -f "/tmp/mqtt_snapshot"
	#   rm "/tmp/mqtt_snapshot"
	# ;;

	# "${TOPIC}/motion/mqtt_snapshot/set ON")
	#   motion_mqtt_snapshot on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_snapshot status)"
	# ;;

	# "${TOPIC}/motion/mqtt_snapshot/set OFF")
	#   motion_mqtt_snapshot off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/mqtt_snapshot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_mqtt_snapshot status)"
	# ;;


	# "${TOPIC}/motion/tracking")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/tracking ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_tracking status)"
	# ;;

	# "${TOPIC}/motion/tracking/set ON")
	#   motion_tracking on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/tracking ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_tracking status)"
	# ;;

	# "${TOPIC}/motion/tracking/set OFF")
	#   motion_tracking off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/tracking ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motion_tracking status)"
	# ;;

	# "${TOPIC}/motors/vertical/set up")
	#   motor up
	#   MOTORSTATE=$(motor status vertical)
	#   if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	TARGET=$(busybox expr $MAX_Y - $MOTORSTATE)
	#   else
	# 	TARGET=$MOTORSTATE
	#   fi
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motors/vertical ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$TARGET"
	# ;;

	# "${TOPIC}/motors/vertical/set down")
	#   motor down
	#   MOTORSTATE=$(motor status vertical)
	#   if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	TARGET=$(busybox expr $MAX_Y - $MOTORSTATE)
	#   else
	# 	TARGET=$MOTORSTATE
	#   fi	   
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motors/vertical ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$TARGET"
	# ;;

	# "${TOPIC}/motors/vertical/set "*)
	#   COMMAND=$(echo "$line" | awk '{print $2}')
	#   MOTORSTATE=$(motor status vertical)
	#   if [ -n "$COMMAND" ] && [ "$COMMAND" -eq "$COMMAND" ] 2>/dev/null; then   
	# 	if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	  echo Changing motor from $COMMAND to $MOTORSTATE
	# 	  TARGET=$(busybox expr $MOTORSTATE + $COMMAND - $MAX_Y)
	# 	else
	# 	  echo Changing motor from $MOTORSTATE to $COMMAND
	# 	  TARGET=$(busybox expr $COMMAND - $MOTORSTATE)
	# 	fi
	# 	echo Moving $TARGET
	# 	if [ "$TARGET" -lt 0 ]; then
	# 	  motor down $(busybox expr $TARGET \* -1)
	# 	else
	# 	  motor up $TARGET
	# 	fi
	#   else
	# 	echo Requested $COMMAND is not a number
	#   fi
	# ;;
	
	# "${TOPIC}/motors/horizontal/set left")
	#   motor left
	#   MOTORSTATE=$(motor status horizontal)
	#   if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	TARGET=$(busybox expr $MAX_X - $MOTORSTATE)
	#   else
	# 	TARGET=$MOTORSTATE
	#   fi
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motors/horizontal ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$TARGET"
	# ;;

	# "${TOPIC}/motors/horizontal/set right")
	#   motor right
	#   MOTORSTATE=$(motor status horizontal)
	#   if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	TARGET=$(busybox expr $MAX_X - $MOTORSTATE)
	#   else
	# 	TARGET=$MOTORSTATE
	#   fi
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motors/horizontal ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$TARGET"
	# ;;

	# "${TOPIC}/motors/horizontal/set "*)
	#   COMMAND=$(echo "$line" | awk '{print $2}')
	#   MOTORSTATE=$(motor status horizontal)
	#   if [ -n "$COMMAND" ] && [ "$COMMAND" -eq "$COMMAND" ] 2>/dev/null; then
	# 	if [ `/system/sdcard/bin/setconf -g f` -eq 1 ]; then
	# 	  echo Changing motor from $COMMAND to $MOTORSTATE
	# 	  TARGET=$(busybox expr $MOTORSTATE + $COMMAND - $MAX_X)
	# 	else
	# 	  echo Changing motor from $MOTORSTATE to $COMMAND
	# 	  TARGET=$(busybox expr $COMMAND - $MOTORSTATE)
	# 	fi
	# 	echo Moving $TARGET
	# 	if [ "$TARGET" -lt 0 ]; then
	# 	  motor left $(busybox expr $TARGET \* -1)
	# 	else
	# 	  motor right $TARGET
	# 	fi
	#   else
	# 	echo Requested $COMMAND is not a number
	#   fi
	# ;;

	# "${TOPIC}/motors/set calibrate")
	#   motor reset_pos_count
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motors ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(motor status horizontal)"
	# ;;

	# "${TOPIC}/remount_sdcard/set ON")
	#   remount_sdcard
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/remount_sdcard ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "Remounting the SD Card"
	# ;;

	# "${TOPIC}/reboot/set ON")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/reboot ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "Rebooting the System"
	#   reboot_system
	# ;;

	# "${TOPIC}/recording")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/recording ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(recording status)"
	# ;;

	# "${TOPIC}/recording/set ON")
	#   recording on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/recording ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(recording status)"
	# ;;

	# "${TOPIC}/recording/set OFF")
	#   recording off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/recording ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(recording status)"
	# ;;

	# "${TOPIC}/timelapse")
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/timelapse ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(timelapse status)"
	# ;;

	# "${TOPIC}/timelapse/set ON")
	#   timelapse on
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/timelapse ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(timelapse status)"
	# ;;

	# "${TOPIC}/timelapse/set OFF")
	#   timelapse off
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/timelapse ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(timelapse status)"
	# ;;

	# "${TOPIC}/snapshot/set ON")
	#   snapshot
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/snapshot ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -f "$filename"
	# ;;

	# "${TOPIC}/update/set update")
	#   if [ -f "/system/sdcard/VERSION" ]; then
	#   	branch=$(/system/sdcard/bin/jq -r .branch /system/sdcard/VERSION)
	#   else
	#     branch="master"
	#   fi
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/update ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "Upgrade started"
	#   result=$(/bin/sh /system/sdcard/autoupdate.sh -s -v -f -r $branch)
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/update ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "Upgrade finish: ${result}"	  
	# ;;

	# "${TOPIC}/set "*)
	#   COMMAND=$(echo "$line" | awk '{print $2}')
	#   #echo "$COMMAND"
	#   F_cmd="${COMMAND}" /system/sdcard/www/cgi-bin/action.cgi -o /dev/null 2>/dev/null
	#   if [ $? -eq 0 ]; then
	# 	/system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}/${COMMAND}" ${MOSQUITTOOPTS} -m "OK (this means: action.cgi invoke with parameter ${COMMAND}, nothing more, nothing less)"
	#   else
	# 	/system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}/error" ${MOSQUITTOOPTS} -m "An error occured when executing ${line}"
	#   fi
	#   # Publish updated states
	#   /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}" ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$(/system/sdcard/scripts/mqtt-status.sh)"
	# ;;

# Noticed some subtle differences between iwconfig return values between devices:
# $ iwconfig wlan0
# wlan0     IEEE 802.11bgn  ESSID:"ETHERCI5"  
#           Mode:Managed  Frequency:2.437 GHz  Access Point: C0:94:35:E3:8D:B5   
#           Bit Rate=65 Mb/s   
#           Retry  long limit:7   RTS thr:off   Fragment thr:off
#           Encryption key:off
#           Power Management:on
#           Link Quality=57/70  Signal level=-53 dBm  
#           Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
#           Tx excessive retries:0  Invalid misc:37260   Missed beacon:0

# $ iwconfig wlan0
# wlan0     IEEE 802.11gn  ESSID:"ETHERCI5"  Nickname:"<WIFI@REALTEK>"
#           Mode:Managed  Frequency:2.437 GHz  Access Point: C0:94:35:E3:8D:B5   
#           Bit Rate:72.2 Mb/s   Sensitivity:0/0  
#           Retry:off   RTS thr:off   Fragment thr:off
#           Encryption key:****-****-****-****-****-****-****-****   Security mode:open
#           Power Management:off
#           Link Quality=76/100  Signal level=66/100  Noise level=0/100
#           Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
#           Tx excessive retries:0  Invalid misc:0   Missed beacon:0

# Bit Rate(:|=)
# Signal level=(66/100|-53 dBm)
# Noise level=(0/100|MISSING!)

    DEVICE_MODEL=$(/opt/wz_mini/etc/init.d/s04model start | grep detected | cut -f1 -d ' ')
    FW_VER=$(tail -n1 /configs/app.ver | cut -f2 -d=  )
    IP_ADDR=$(ifconfig wlan0  | grep inet | cut -d ':' -f2 | cut -d ' ' -f0)
    MAC=$(ifconfig wlan0  | grep HWaddr | cut -d 'HW' -f2 | cut -d ' ' -f2)
    # Link quality, signal level and noise are all represented as a percentage
    WIFI_LINK_QUALITY=$(iwconfig wlan0 | grep "Link Quality" | cut -d "S" -f1 | cut -d "=" -f2 | cut -d "/" -f1)
	# Signal level may be % or expressed in dBm
	# Signal level may be returned as json number or string
    WIFI_SIGNAL_LEVEL=$(iwconfig wlan0 | grep "Signal level" | cut -d "S" -f2 | cut -d "=" -f2 | cut -d "/" -f1)
	if [ ! -z "$(echo "${WIFI_SIGNAL_LEVEL}" | grep "dBm")" ]; then # "dBm" was found
		WIFI_SIGNAL_LEVEL="\"${WIFI_SIGNAL_LEVEL}\""
	fi
    WIFI_NOISE_LEVEL=$(iwconfig wlan0 | grep "Noise level" | cut -d "Noise" -f2 | cut -d "=" -f2 | cut -d "/" -f1)
	# Noise level may be missing
	if [ -z "${WIFI_NOISE_LEVEL}" ]; then
		WIFI_NOISE_LEVEL=0
	fi
    # Bit rate returned as "<float> Mb/s"
	# Bit rate can be delimited by : or =
    WIFI_BIT_RATE=$(iwconfig wlan0 | grep "Bit Rate" | cut -d ":" -f2 | cut -d "=" -f2 | cut -d "Sens" -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # 2022-11-08 18:07:50  (I think this is local time)
    LAST_BOOT=$(uptime -s)
    # 2022-11-09T16:07:50+00:00  (always returns UTC)
    CURRENT_TIME=$(date -Iseconds)

    # Model after HA MQTT discovery device json
    #   "device": {
    #     "name": "CXV Gas Monitor",
    #     "identifiers": "98:CD:AC:D3:63:18",
    #     "mf": "UnexpectedMaker",
    #     "mdl": "TinyPICO",
    #     "sw": "20221020.1300"
    #   }
    DEVICE_JSON="{\"name\":\"${CUSTOM_HOSTNAME}\", \"identifiers\":\"${MAC}\", \"mf\":\"Wyze\", \"mdl\":\"${DEVICE_MODEL}\", \"sw\": \"${FW_VER}\"}"
    STATUS_JSON="{\"last_boot\":\"${LAST_BOOT}\",\"ts\":\"${CURRENT_TIME}\",\"ip\":\"${IP_ADDR}\",\"link_quality\":${WIFI_LINK_QUALITY},\"signal_level\":${WIFI_SIGNAL_LEVEL},\"noise_level\":${WIFI_NOISE_LEVEL},\"bit_rate\":\"${WIFI_BIT_RATE}\",\"device\":${DEVICE_JSON}}"
    mqtt_publish "/status" "${STATUS_JSON}"



    # --- Configuration from /opt/wz_mini/wz_mini.conf ---
    # These have already been loaded as env vars

    # - RTSP_LOGIN="admin"
    # - RTSP_PASSWORD="password"

    mqtt_publish "/rtsp_server/port" "${RTSP_PORT}"
    if [ "${RTSP_AUTH_DISABLE}" == "true" ]; then
        mqtt_publish "/rtsp_server/authentication" "OFF"
    else
        mqtt_publish "/rtsp_server/authentication" "ON"
    fi

    if [ "${RTSP_HI_RES_ENABLED}" == "true" ]; then
        mqtt_publish "/rtsp_server/channel1" "ON"
    else
        mqtt_publish "/rtsp_server/channel1" "OFF"
    fi
    
    if [ "${RTSP_LOW_RES_ENABLED}" == "true" ]; then
        mqtt_publish "/rtsp_server/channel2" "ON"
    else
        mqtt_publish "/rtsp_server/channel2" "OFF"
    fi
    
    if [ "${RTSP_HI_RES_ENABLE_AUDIO}" == "true" ]; then
        mqtt_publish "/rtsp_server/channel1/audio" "ON"
    else
        mqtt_publish "/rtsp_server/channel1/audio" "OFF"
    fi

    if [ "${RTSP_LOW_RES_ENABLE_AUDIO}" == "true" ]; then
        mqtt_publish "/rtsp_server/channel2/audio" "ON"
    else
        mqtt_publish "/rtsp_server/channel2/audio" "OFF"
    fi	
    
    mqtt_publish "/rtsp_server/channel1/fps" "${RTSP_HI_RES_FPS}"
    mqtt_publish "/rtsp_server/channel2/fps" "${RTSP_LOW_RES_FPS}"

    mqtt_publish "/rtsp_server/channel1/bitrate_max" "${RTSP_HI_RES_MAX_BITRATE}"
    mqtt_publish "/rtsp_server/channel2/bitrate_max" "${RTSP_LOW_RES_MAX_BITRATE}"

    mqtt_publish "/rtsp_server/channel1/bitrate_target" "${RTSP_HI_RES_TARGET_BITRATE}"
    mqtt_publish "/rtsp_server/channel2/bitrate_target" "${RTSP_LOW_RES_TARGET_BITRATE}"   

    mqtt_publish "/rtsp_server/channel1/enc_params" "${RTSP_HI_RES_ENC_PARAMETER}"
    mqtt_publish "/rtsp_server/channel2/enc_params" "${RTSP_LOW_RES_ENC_PARAMETER}"      


    # if both streams are enabled, then there is a rtsp url for each
    # if only one stream is enabled then that stream has a differnet rtsp url
    if [ "${RTSP_HI_RES_ENABLED}" == "true" ]; then
        if [ "${RTSP_LOW_RES_ENABLED}" == "true" ]; then
            mqtt_publish "/rtsp_server/channel1/url" "rtsp://${IP_ADDR}:${RTSP_PORT}/video1_unicast"
            mqtt_publish "/rtsp_server/channel2/url" "rtsp://${IP_ADDR}:${RTSP_PORT}/video2_unicast"   
        else     
            mqtt_publish "/rtsp_server/channel1/url" "rtsp://${IP_ADDR}:${RTSP_PORT}/unicast"
            mqtt_publish "/rtsp_server/channel2/url" ""
        fi
    else
        if [ "${RTSP_LOW_RES_ENABLED}" == "true" ]; then
            mqtt_publish "/rtsp_server/channel1/url" ""
            mqtt_publish "/rtsp_server/channel2/url" "rtsp://${IP_ADDR}:${RTSP_PORT}/unicast"   
        else     
            mqtt_publish "/rtsp_server/channel1/url" ""
            mqtt_publish "/rtsp_server/channel2/url" ""
        fi        
    fi

	# Initially this setting comes from wz_mini.conf and is read on every boot
	# However since httpd can be stopped and started without the need for a device reboot, the initial state can diverge from the present state
    # if [ "${WEB_SERVER_ENABLED}" == "true" ]; then
	# 	mqtt_publish "/web_console" "ON"
	# else
	# 	mqtt_publish "/web_console" "OFF"
	# fi
    
    if [ -z "$(pgrep httpd)" ]; then
        mqtt_publish "/web_console/active" "OFF"
		# switch should refect the present state, not past startup state
		mqtt_publish "/web_console" "OFF" 
    else
        mqtt_publish "/web_console/active" "ON"
		# switch should refect the present state, not past startup state
		mqtt_publish "/web_console" "ON"
    fi

    # mqtt_publish "/libcallback_enable" "${LIBCALLBACK_ENABLE}"    
    # mqtt_publish "/night_drop_disable" "${NIGHT_DROP_DISABLE}"
    # mqtt_publish "/fsck_on_boot_enable" "${ENABLE_FSCK_ON_BOOT}"    
    # mqtt_publish "/crontab_enable" "${ENABLE_CRONTAB}"
    # mqtt_publish "/syslog_save_enable" "${ENABLE_SYSLOG_SAVE}"
    # mqtt_publish "/ipv6_enable" "${ENABLE_IPV6}"
    # mqtt_publish "/wireguard_enable" "${ENABLE_WIREGUARD}"
    # mqtt_publish "/iptables_enable" "${ENABLE_IPTABLES}"
    
    # mqtt_publish "/selfhosted_mode_enable" "${ENABLE_SELFHOSTED_MODE}"
    # mqtt_publish "/fw_upgrade_disable" "${DISABLE_FW_UPGRADE}"
    # mqtt_publish "/local_dns_enable" "${ENABLE_LOCAL_DNS}"
    # mqtt_publish "/ntp_server" "${NTP_SERVER}"


    sleep $STATUSINTERVAL

	# Re-read mosquitto.conf every iteration in order to catch updates the the STATUSINTERVAL
	source ${MQTT_CONFIG}
	if [ "$STATUSINTERVAL" -lt 30 ]; then
  		STATUSINTERVAL=30
	fi
done

