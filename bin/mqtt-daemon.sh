#!/bin/sh

mkdaemon() {
    # dmon options
    #   --stderr-redir  Redirects stderr to the log file as well
    #   --max-respawns  Sets the number of times dmon will restart a failed process
    #   --environ       Sets an environment variable. Used to remove buffering on stdout
    #
    # dslog options
    #   --priority      The syslog priority. Set to DEBUG as these are just the stdout of the 
    #   --max-files     The number of logs that will exist at once
    #
    max_respawns=$1
    shift
    daemon_name=$1
    shift
    dmon \
      --stderr-redir \
      --max-respawns $max_respawns \
      --environ "LD_PRELOAD=libsetunbuf.so" \
      $@ \
      -- dslog \
        --priority DEBUG \
        --facility USER \
        $daemon_name
}

case "$1" in
	start)
        echo "#####$(basename "$0")#####"
        mkdaemon 0 mqtt-autodiscovery /media/mmc/mosquitto/bin/mqtt-autodiscovery.sh
        mkdaemon 0 mqtt-control /media/mmc/mosquitto/bin/mqtt-control.sh
        mkdaemon 0 mqtt-status /media/mmc/mosquitto/bin/mqtt-status.sh
        mkdaemon 0 mqtt-motion /media/mmc/mosquitto/bin/mqtt-motion.sh
		;;
    stop)
        echo "Stopping $(basename "$0")..."
        # mqtt-autodiscovery.sh is not a daemon; it just runs once-and-done. 
        kill -s SIGTERM $(pgrep "mosquitto_sub|mqtt-status.sh|mqtt-control.sh|mqtt-motion.sh")
        ;;
    restart)
        $0 stop
        $0 start
        ;;
	*)
		echo "Usage: $0 {start|stop|restart}"
		exit 1
		;;
esac



