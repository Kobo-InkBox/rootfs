#!/bin/sh

# Stop Qt from getting in the way
stop inkbox_gui

# Kill all running instances, unmount filesystems
killall X Xorg
kill -9 `pidof X`
rm /xorg/var/log/Xorg.0.log
killall vnc-nographic vnc

DPI=`cat /tmp/X_dpi 2>/dev/null`
DPMODE=`cat /tmp/X_dpmode 2>/dev/null`
PROGRAM=`cat /tmp/X_program 2>/dev/null`
DEVICE=`cat /opt/inkbox_device`
DISPLAY=:0

[ ! -e "/xorg/opt/device" ] && touch /xorg/opt/device
mount --bind /opt/inkbox_device /xorg/opt/device

if [ "$DEVICE" == "n705" ] || [ "$DEVICE" == "n905b" ] || [ "$DEVICE" == "n905c" ] || [ "$DEVICE" == "n613" ] || [ "${DEVICE}" == "n236" ] || [ "${DEVICE}" == "n437" ] || [ "${DEVICE}" == "n306" ]; then
	FB_UR=3
elif [ "${DEVICE}" == "kt" ]; then
	FB_UR=1
elif [ "$DEVICE" == "n873" ]; then
	FB_UR=0
else
	FB_UR=3
fi
echo $FB_UR > /sys/class/graphics/fb0/rotate

if [ "$DPI" == "" ]; then
        chroot /xorg "X" "-nocursor" &
	DISPLAY=:0 chroot /xorg "x11vnc" "-localhost" "-forever" "-quiet" &
	sleep 20
else
        chroot /xorg "X" "-nocursor" "-dpi" "$DPI" &
	DISPLAY=:0 chroot /xorg "x11vnc" "-localhost" "-forever" "-quiet" &
	sleep 20
fi

# Launch touch input handler
echo $FB_UR > /sys/class/graphics/fb0/rotate
# fbink_xdamage on the Glo HD displays things very strangely
chroot /opt/X11/vnc-touch /bin/bash -c 'LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/qt5/lib QT_QPA_PLATFORM=kobo /root/vnc/vnc-nographic vnc://localhost' &

# Rebuilding caches; here, the FUSE version of OverlayFS does not allow renaming/moving files (probably due to an old 2.6.35.3 kernel version), so we have to circumvent that sometimes by mounting a tmpfs where the files have to be moved.
# GSchemas (Onboard keyboard needs them to be recompiled)
rm /xorg/usr/share/glib-2.0/schemas/gschemas.compiled
mkdir -p /xorg/usr/share/glib-2.0/schemas/compile
mount -t tmpfs tmpfs /xorg/usr/share/glib-2.0/schemas/compile
chroot /xorg /usr/bin/glib-compile-schemas "--targetdir=/usr/share/glib-2.0/schemas/compile" "/usr/share/glib-2.0/schemas"
cp /xorg/usr/share/glib-2.0/schemas/compile/gschemas.compiled /xorg/usr/share/glib-2.0/schemas/gschemas.compiled
umount -l -f /xorg/usr/share/glib-2.0/schemas/compile

# GDK-Pixbuf cache (also for Onboard, which needs it to display SVGs)
rm -rf /xorg/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
chroot /xorg /bin/bash -c 'gdk-pixbuf-query-loaders > /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache'

sync

# Checking if the program needs to be run full-screen
DPMODE_TEMP=`cat "/opt/X11/extension-storage-merged/${PROGRAM}/.${PROGRAM}_run_full_screen" 2>/dev/null`
if [ "$DPMODE_TEMP" == "true" ]; then
	DPMODE="fullscreen"
fi

# Checking if we have a custom DPI setting specific to an extension
CUSTOM_DPI=`cat "/opt/X11/extension-storage-merged/${PROGRAM}/.${PROGRAM}_dpi" 2>/dev/null`
if [ "$CUSTOM_DPI" != "" ]; then
	DPI="$CUSTOM_DPI"
fi

# Launching requested program
if [ "$PROGRAM" == "!netsurf" ]; then
	rc-service ibxd restart
fi
LAUNCH_OSK=`cat "/opt/X11/extension-storage-merged/${PROGRAM}/.${PROGRAM}_launch_osk" 2>/dev/null`
# A built-in text editor needs its keyboard, doesn't it? ;p
if [ "$PROGRAM" == "geany" ]; then
	LAUNCH_OSK="true"
fi
# Launching onboard (On-Screen Keyboard) if needed
if [ "$LAUNCH_OSK" == "true" ]; then
	DISPLAY=:0 chroot /xorg /usr/bin/onboard &
fi

echo $FB_UR > /sys/class/graphics/fb0/rotate
if [ "${DEVICE}" == "n437" ]; then
	# Don't even try to understand this
	if ! grep -q "true" /tmp/kobox_initial_launch_done; then
		/opt/bin/fbink/fbdepth -d 16
	else
		/opt/bin/fbink/fbdepth -d 32
	fi
elif [ "${DEVICE}" == "kt" ]; then
	/opt/bin/fbink/fbdepth -d 32
fi

RUN_SCRIPT=`cat "/opt/X11/extension-storage-merged/${PROGRAM}/.${PROGRAM}_run_launch_script" 2>/dev/null`
if [ "$RUN_SCRIPT" == "true" ]; then
	chroot /xorg /scripts/start.sh "$DPMODE" "/scripts/${PROGRAM}.sh" "$DPI"
else
	chroot /xorg /scripts/start.sh "$DPMODE" "${PROGRAM}" "$DPI"
fi

if [ "${DEVICE}" == "kt" ] || [ "${DEVICE}" == "n437" ]; then
	/opt/bin/fbink/fbdepth -d 8
fi

echo "true" > /tmp/kobox_initial_launch_done

# The program will have terminated at this point
rc-service xorg stop
rc-service inkbox_gui start
