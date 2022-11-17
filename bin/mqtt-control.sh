#!/opt/wz_mini/bin/bash

# Subscribes to MQTT topics and when a message is received it will update the appropriate configuration file, 
# publish the updated state to a read topic and restart the device to have the changes take effect.

# Control camera state via MQTT
# Supported features:
# 	/leds/indicator/set ON|OFF
# 	/osd_time/set ON|OFF
# 	/night_mode/set ON|OFF
# 	/night_mode/auto/set ON|OFF
# 	/night_mode/early_activation/set ON|OFF
#	/leds/ir_near/set ON|OFF
#	/leds/ir_far/set ON|OFF
# 	/flip_vert/set ON|OFF
#	/flip_horz/set ON|OFF
# 	/play <filename.wav> <volume_1-100>
# 	/web_console/set ON|true|OFF|false
#	/refresh_rate/set [integer]

# to write state update: 	$TOPIC_BASE/some-feature/optional-sub-feature/set
# to read state: 			$TOPIC_BASE/some-feature/optional-sub-feature

#/play 
	# Audio files present on device:
	# --------------------------------------------------------
	# /media/mmc/wz_mini/usr/share/audio
	#       /opt/wz_mini/usr/share/audio
	# 									binbin_v3.wav
	# 									honk.wav
	# 									init.wav
	# 									init_v2.wav
	# 									swap.wav
	# 									swap_v2.wav
	# 									upgrade_mode.wav
	# 									upgrade_mode_v2.wav
	# /usr/share
	# 									baojing.wav
	# /system/local
	# 									siren.wav
	# 									garage.wav
	# /usr/share/notify/CN
	# 									code_ok.wav
	# 									code_wrong.wav
	# 									connect_Faile.wav
	# 									connect_in_progress.wav
	# 									connect_wifi_ok.wav
	# 									dang.wav
	#	 								dang_rd.wav
	# 									init_ok.wav
	# 									ssid_not_found.wav
	# 									user_need_check.wav
	# 									wep_not_support.wav	

MASTER_CONFIG="/opt/wz_mini/wz_mini.conf"
ICAMERA_CONFIG="/configs/.user_config"
MQTT_CONFIG="/media/mmc/mosquitto/mosquitto.conf"
# must support start,stop,restart params
WEBSERVER_INIT_SCRIPT="/opt/wz_mini/etc/network.d/S10httpd"

source ${MASTER_CONFIG}
source ${MQTT_CONFIG}

# killall mosquitto_sub 2> /dev/null
# killall mosquitto_sub.bin 2> /dev/null

TOPIC_BASE="${MQTT_HA_TOPIC_BASE}/camera/${CUSTOM_HOSTNAME}"

mqtt_publish(){ # $1 = /my/topic  $2 = payload
	echo "MQTT publish ${TOPIC_BASE}$1 -> $2"
	${MOSQUITTO_PUB_BIN} -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${TOPIC_BASE}$1" ${MOSQUITTOPUBOPTS} ${MOSQUITTOOPTS} -m "$2"
}

# Write key=value to file and replace old key (not append)
#
# Note: *position* of the key must be in the correct ini file section ([NET], [SETTING], [CAMERA_INFO])
# If not, it doesn't seems to have any effect.
# This macro isn't smart enough to know under which section new/missing keys must be placed.
# Therefore, you MUST start with a fully populated /configs/.user_config file, even including all the defaults 
# This way, the position will always be correct since no new keys will ever need to be appended
update_config_file() { # $1 file  $2 key  $3 value    
    echo "Write $2=$3 to $1"
	logger -t "MQTT" "MQTT update write $2=$3 to $1"
    
	thekey="$2"
	newvalue="$3"

	if ! grep -R "^[#]*\s*${thekey}=.*" $1 > /dev/null; then
	echo "APPENDING because '${thekey}' not found"
	echo "$thekey=$newvalue" >> $1
	else
	echo "SETTING because '${thekey}' exists"
	sed -ir "s/^[#]*\s*${thekey}=.*/$thekey=$newvalue/" $1
	fi	
}

#  write key=value to /configs/.user_config
update_icamera_config() {  # $1 key  $2 value
	update_config_file ${ICAMERA_CONFIG} $1 $2
}

#  write key=value to /opt/wz_mini/wz_mini.conf and replace old key (not append)
update_wzmini_config() { # $1 key  $2 value            
	update_config_file ${MASTER_CONFIG} $1 $2
}

# restart device but only if /opt/wz_mini/wz_mini.conf is valid
safe_restart() {	
	if [ -f ${MASTER_CONFIG} ]; then
		if [ -s ${MASTER_CONFIG} ]; then
			#echo "${MASTER_CONFIG} exists and not empty"
			logger -t "MQTT" "${MASTER_CONFIG} updates made via MQTT. Rebooting for changes to take effect..."
			reboot
		else
			echo "${MASTER_CONFIG} exists but empty"
			echo "if you reboot then the hack will fail "
			return 1
		fi
	else
		echo "${MASTER_CONFIG} file does not exist"
		echo "if you reboot then the hack will fail. Please insure you have a valid config file."
		return 2
	fi
}

commit_icamera_updates() {        
    # TODO: ideally, just need to restart iCamera
	logger -t "MQTT" "${ICAMERA_CONFIG} updates made via MQTT. Rebooting for changes to take effect..."
	safe_restart
}

commit_wzmini_updates(){
	logger -t "MQTT" "${MASTER_CONFIG} updates made via MQTT. Rebooting for changes to take effect..."
	safe_restart
}

# Check MQTT broker connectivity...
while true; do
  ${MOSQUITTO_PUB_BIN} -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${TOPIC_BASE}"/init ${MOSQUITTOOPTS} -n
  case $? in
	0)
		break 2
		;;
	5)
		# Not authorized
		logger -t "MQTT" "Mosquitto broker credentials are not valid"
		break 2
		;;
	14)
		# Connection error, retry
		logger -t "MQTT" "MQTT: Cannot connect to Mosquitto broker $HOST at $PORT, retry in 60s"
		sleep 60
		;;
  esac
done

# Subscription listener runs continuously
${MOSQUITTO_SUB_BIN} -v -h "${MQTT_BROKER_HOST}" -p "${MQTT_BROKER_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${TOPIC_BASE}/#"  ${MOSQUITTOOPTS} | while read -r line ; do
  case $line in
	"${TOPIC_BASE}/osd_time/set ON")
      update_icamera_config "osdSwitch" "1"
	  # before device restarts, check that the configuration will result in the new desired state upon boot
	  if [ ! -z "$(grep "osdSwitch=1" ${ICAMERA_CONFIG})" ]; then
	  	# reflect the anticipated new state; this avoids the switch "bounce", since HA expects and immediate state update to be reflected, otherwise it will revert the switch
	  	mqtt_publish "/osd_time" "ON"	  
	  fi
	  # reboot to apply new state; next status update on boot will give us the actual current state (should be the same as the anticipated state)
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/osd_time/set OFF")	  
      update_icamera_config "osdSwitch" "2"
	  if [ ! -z "$(grep "osdSwitch=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/osd_time" "OFF"	  
	  fi	  
	  commit_icamera_updates 	  
	;;	

	"${TOPIC_BASE}/leds/indicator/set ON")
      update_icamera_config "indicator" "1"
	  if [ ! -z "$(grep "indicator=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/indicator" "ON"	  
	  fi	  
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/leds/indicator/set OFF")	  
      update_icamera_config "indicator" "2"
	  if [ ! -z "$(grep "indicator=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/indicator" "OFF"	  
	  fi	
	  commit_icamera_updates 	  
	;;



	"${TOPIC_BASE}/night_mode/set ON")	  
      update_icamera_config "nightVision" "1"
	  if [ ! -z "$(grep "nightVision=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode" "ON"	  
	  fi	
	  commit_icamera_updates 	  
	;;	

	"${TOPIC_BASE}/night_mode/set OFF")	  
      update_icamera_config "nightVision" "2"
	  if [ ! -z "$(grep "nightVision=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode" "OFF"	  
	  fi	
	  commit_icamera_updates 	  
	;;		

	"${TOPIC_BASE}/night_mode/auto/set ON")	  
      update_icamera_config "nightVision" "3"
	  # not sure if nightmode should be on or off (ideally it should reflect if nightmode is currently active - but there is no way to query for this)?
	  if [ ! -z "$(grep "nightVision=3" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode/auto" "ON"	  
	  fi		  
	  commit_icamera_updates 	  
	;;	

	"${TOPIC_BASE}/night_mode/auto/set OFF")	
	  # I will assume if automatic night mode is turned off, then night mode will be turned off	  
      update_icamera_config "nightVision" "2"
	  if [ ! -z "$(grep "nightVision=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode/auto" "OFF"	  
	  fi	
	  commit_icamera_updates 	  
	;;	

	"${TOPIC_BASE}/night_mode/early_activation/set ON")
      update_icamera_config "night_cut_thr" "1" # dusk
	  if [ ! -z "$(grep "night_cut_thr=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode/early_activation" "ON"	  
	  fi
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/night_mode/early_activation/set OFF")	  
      update_icamera_config "night_cut_thr" "2" # dark
	  if [ ! -z "$(grep "night_cut_thr=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/night_mode/early_activation" "OFF"	  
	  fi	
	  commit_icamera_updates 	
	;;

	"${TOPIC_BASE}/leds/ir_near/set ON")
      update_icamera_config "night_led_ex" "1"
	  if [ ! -z "$(grep "night_led_ex=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/ir_near" "ON"	  
	  fi	  	  
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/leds/ir_near/set OFF")	  
      update_icamera_config "night_led_ex" "2"
	  if [ ! -z "$(grep "night_led_ex=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/ir_near" "OFF"	  
	  fi	
	  commit_icamera_updates 	  
	;;

	"${TOPIC_BASE}/leds/ir_far/set ON")
      update_icamera_config "NIGHT_LED_flag" "1"
	  if [ ! -z "$(grep "NIGHT_LED_flag=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/ir_far" "ON"	  
	  fi  
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/leds/ir_far/set OFF")	  
      update_icamera_config "NIGHT_LED_flag" "2"
	  if [ ! -z "$(grep "NIGHT_LED_flag=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/leds/ir_far" "OFF"	  
	  fi  
	  commit_icamera_updates 	  
	;;

	"${TOPIC_BASE}/flip_vert/set ON")
      update_icamera_config "verSwitch" "2"
	  if [ ! -z "$(grep "verSwitch=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/flip_vert" "ON"	  
	  fi  	  
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/flip_vert/set OFF")	  
      update_icamera_config "verSwitch" "1"
	  if [ ! -z "$(grep "verSwitch=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/flip_vert" "OFF"	  
	  fi 
	  commit_icamera_updates 	  
	;;

	"${TOPIC_BASE}/flip_horz/set ON")
      update_icamera_config "horSwitch" "2"
	  if [ ! -z "$(grep "horSwitch=2" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/flip_horz" "ON"	  
	  fi   
	  commit_icamera_updates
	;;

	"${TOPIC_BASE}/flip_horz/set OFF")	  
      update_icamera_config "horSwitch" "1"
	  if [ ! -z "$(grep "horSwitch=1" ${ICAMERA_CONFIG})" ]; then	  	
	  	mqtt_publish "/flip_horz" "OFF"	  
	  fi 	
	  commit_icamera_updates 	  
	;;

	# ..../play <filename.wav> <volume_1-100>
	"${TOPIC_BASE}/play "*)
	  AUDIOFILE=$(echo "$line" | awk '{print $2}')
	  VOLUME=$(echo "$line" | awk '{print $3}')
	  VOLUME=${VOLUME:50}
	  cmd aplay "${AUDIOFILE}" "${VOLUME}"
	;;

	# ..../webconsole/set ON|true|OFF|false)
	"${TOPIC_BASE}/web_console/set "*)
		toggle=$(echo "$line" | awk '{print $2}')
		echo "web_console/set -> $toggle"
      	if [ "$toggle" == "ON" ] || [ "$toggle" == "true" ]; then	  
	    	# save config change so that it survives device restarts
			update_wzmini_config "WEB_SERVER_ENABLED" "\"true\""  
			# reflect updated configuration
			mqtt_publish "/web_console" "ON"		    		
			$(${WEBSERVER_INIT_SCRIPT} start)
      	else  
	    	# save config change so that it survives device restarts
			update_wzmini_config "WEB_SERVER_ENABLED" "\"false\""      			
			# reflect updated configuration
			mqtt_publish "/web_console" "OFF"
			$(${WEBSERVER_INIT_SCRIPT} stop)
	  	fi	
	  	# since we're avoiding a device restart, publish once start is confirmed
	  	sleep 5 # wait for web server to start/stop
	  	# reflect actual state 
	  	if [ -z "$(pgrep httpd)" ]; then
			mqtt_publish "/web_console/active" "OFF"
	  	else
	 		mqtt_publish "/web_console/active" "ON"
	  	fi	  
	  	# no need to restart device to start/stop webserver
      	#commit_wzmini_updates
	;;

	"${TOPIC_BASE}/refresh_rate/set "*)	  
	  STATUSINTERVAL=$(echo "$line" | awk '{print $2}')
	  echo "refresh_rate/set -> ${STATUSINTERVAL}"
	   if [ "${STATUSINTERVAL}" -lt 30 ]; then
  			STATUSINTERVAL=30
			echo "refresh_rate/set -> ${STATUSINTERVAL} (minimum override)"
	   fi

	  # update STATUSINTERVAL in mosquitto.conf
	  update_config_file "${MQTT_CONFIG}" "STATUSINTERVAL" "${STATUSINTERVAL}"
	  # mqtt-status.sh will re-read mosquitto.conf with every iteration (so there will be a delay for the change to be reflected)
	  # reflect the updated refresh rate immediately rather than waiting for it to be done by mqtt-status.sh
	  mqtt_publish "/refresh_rate" "${STATUSINTERVAL}"		  	  
	;;

  esac
done
