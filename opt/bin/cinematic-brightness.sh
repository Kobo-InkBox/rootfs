#!/bin/sh

DEVICE=$(cat /opt/inkbox_device)

get_brightness() {
	if [ "${DEVICE}" == "n613" ]; then
		BRIGHTNESS=$(cat /opt/config/03-brightness/config)
	elif [ "${DEVICE}" == "n236" ] || [ "${DEVICE}" == "n437" ]; then
		BRIGHTNESS=$(cat /sys/class/backlight/mxc_msp430_fl.0/brightness)
	elif [ "${DEVICE}" == "n249" ]; then
		BRIGHTNESS=$(cat /sys/class/backlight/backlight_cold/actual_brightness)
		WARM_BRIGHTNESS=$(cat /sys/class/backlight/backlight_warm/actual_brightness)
	else
		BRIGHTNESS=$(cat /sys/class/backlight/mxc_msp430.0/brightness)
	fi
}

set_brightness() {
	if [ "${DEVICE}" == "n613" ]; then
		/opt/bin/frontlight ${1}
	elif [ "${DEVICE}" == "n236" ] || [ "${DEVICE}" == "n437" ]; then
		echo ${1} > "/sys/class/backlight/mxc_msp430_fl.0/brightness"
	elif [ "${DEVICE}" == "n249" ]; then
		echo "${1}" > "/sys/class/backlight/backlight_cold/brightness"
		# TODO: Improve this hackery
		echo "${1}" > "/sys/class/backlight/backlight_warm/brightness"
	else
		echo ${1} > "/sys/class/backlight/mxc_msp430.0/brightness"
	fi
}

if [ -z "${1}" ]; then
	echo "You must provide the 'brightness' argument."
	exit 1
elif [ -z "${2}" ]; then
	echo "You must provide the 'mode' argument."
	echo "Available modes:"
	echo "0: Bring UP brightness"
	echo "1: Bring DOWN brightness"
	exit 1
else
	if [ "${2}" == "0" ]; then
		VALUE=${1}
		CURRENT_BRIGHTNESS=0
		while [ ${CURRENT_BRIGHTNESS} != ${VALUE} ]; do
			CURRENT_BRIGHTNESS=$((CURRENT_BRIGHTNESS+1))
			set_brightness ${CURRENT_BRIGHTNESS}
			sleep 0.03
		done
	else
		get_brightness
		CURRENT_BRIGHTNESS=${BRIGHTNESS}
		while [ ${CURRENT_BRIGHTNESS} != 0 ]; do
			CURRENT_BRIGHTNESS=$((CURRENT_BRIGHTNESS-1))
			set_brightness ${CURRENT_BRIGHTNESS}
			sleep 0.03
		done
	fi
fi
