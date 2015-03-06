#!/bin/sh
# This script was written by Frank Caviggia, Red Hat Consulting
# Last update was 5 March 2015
# This script is NOT SUPPORTED by Red Hat Global Support Services.
# Please contact Rick Tavares for more information.
#
# Script: ssg-suplemental.sh (system-hardening)
# Description: RHEL 6 Hardening Supplemental to SSG
# License: GPL (see COPYING)
# Copyright: Red Hat Consulting, March 2015
# Author: Frank Caviggia <fcaviggi (at) redhat.com>

########################################
# FIPS 140-2 Kernel Mode
########################################
sed -i 's/PRELINKING=yes/PRELINKING=no/g' /etc/sysconfig/prelink
prelink -u -a
dracut -f
if [ -e /sys/firmware/efi ]; then
	BOOT=`df /boot/efi | tail -1 | awk '{print $1 }'`
else
	BOOT=`df /boot | tail -1 | awk '{ print $1 }'`
fi
/sbin/grubby --update-kernel=ALL --args="boot=${BOOT} fips=1"

########################################
# Make SELinux Configuration Immutable
########################################
chattr +i /etc/selinux/config

########################################
# Disable Control-Alt-Delete
########################################
cat <<EOF > /etc/init/control-alt-delete.conf
# control-alt-delete - emergency keypress handling
#
# This task is run whenever the Control-Alt-Delete key combination is
# pressed. Usually used to shut down the machine.
#
# Do not edit this file directly. If you want to change the behaviour,
# please create a file control-alt-delete.override and put your changes there.

#start on control-alt-delete
exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"
EOF

########################################
# Disable Interactive Shell (Timeout)
########################################
cat <<EOF > /etc/profile.d/autologout.sh
#!/bin/sh
TMOUT=900
readonly TMOUT
export TMOUT
EOF
cat <<EOF > /etc/profile.d/autologout.csh
#!/bin/csh
set autologout=15
set -r autologout
EOF
chown root:root /etc/profile.d/autologout.sh
chown root:root /etc/profile.d/autologout.csh
chmod 755 /etc/profile.d/autologout.sh
chmod 755 /etc/profile.d/autologout.csh

########################################
# Vlock Alias (Cosole Screen Lock)
########################################
cat <<EOF > /etc/profile.d/vlock-alias.sh
#!/bin/sh
alias vlock='clear;vlock -a'
EOF
cat <<EOF > /etc/profile.d/vlock-alias.csh
#!/bin/csh
alias vlock 'clear;vlock -a'
EOF
chown root:root /etc/profile.d/vlock-alias.sh
chown root:root /etc/profile.d/vlock-alias.csh
chmod 755 /etc/profile.d/vlock-alias.sh
chmod 755 /etc/profile.d/vlock-alias.csh

########################################
# Wheel Group Require (sudo)
########################################
sed -i -re '/pam_wheel.so use_uid/s/^#//' /etc/pam.d/su
sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*ALL\)/\1/' /etc/sudoers
echo -e "\n## Set timeout for authentiation (5 Minutes)\nDefaults:ALL timestamp_timeout=5\n" >> /etc/sudoers

########################################
# SSHD Hardening
########################################
echo "MACs hmac-sha2-512,hmac-sha2-256,hmac-sha1" >> /etc/ssh/sshd_config
echo "AllowGroups sshusers" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
if [ $(grep -c sshusers /etc/group) -eq 0 ]; then
	/usr/sbin/groupadd sshusers &> /dev/null
fi

########################################
# TCP_WRAPPERS
########################################
cat <<EOF >> /etc/hosts.allow
# LOCALHOST (ALL TRAFFIC ALLOWED) DO NOT REMOVE FOLLOWING LINE
ALL: 127.0.0.1 [::1]
# Allow SSH (you can limit this further using IP addresses - e.g. 192.168.0.*)
sshd: ALL
EOF
cat <<EOF >> /etc/hosts.deny
# Deny All by Default
ALL: ALL
EOF

########################################
# Filesystem Attributes
#  CCE-26499-4,CCE-26720-3,CCE-26762-5,
#  CCE-26778-1,CCE-26622-1,CCE-26486-1.
#  CCE-27196-5
########################################
FSTAB=/etc/fstab
SED=`which sed`

if [ $(grep " \/sys " ${FSTAB} | grep -c "nosuid") -eq 0 ]; then
	MNT_OPTS=$(grep " \/sys " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/sys.*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/boot " ${FSTAB} | grep -c "nosuid") -eq 0 ]; then
	MNT_OPTS=$(grep " \/boot " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/boot.*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/usr " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/usr " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/usr .*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/home " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/home " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/home .*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/export\/home " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/export\/home " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/export\/home .*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/usr\/local " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/usr\/local " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/usr\/local.*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi
if [ $(grep " \/dev\/shm " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/dev\/shm " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/dev\/shm.*${MNT_OPTS}\)/\1,nodev,noexec,nosuid/" ${FSTAB}
fi
if [ $(grep " \/tmp " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/tmp " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/tmp.*${MNT_OPTS}\)/\1,nodev,noexec,nosuid/" ${FSTAB}
fi
if [ $(grep " \/var\/tmp " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/var\/tmp " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/var\/tmp.*${MNT_OPTS}\)/\1,nodev,noexec,nosuid/" ${FSTAB}
fi
if [ $(grep " \/var\/log " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/var\/tmp " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/var\/tmp.*${MNT_OPTS}\)/\1,nodev,noexec,nosuid/" ${FSTAB}
fi
if [ $(grep " \/var\/log\/audit " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/var\/log\/audit " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/var\/log\/audit.*${MNT_OPTS}\)/\1,nodev,noexec,nosuid/" ${FSTAB}
fi
if [ $(grep " \/var " ${FSTAB} | grep -c "nodev") -eq 0 ]; then
	MNT_OPTS=$(grep " \/var " ${FSTAB} | awk '{print $4}')
	${SED} -i "s/\( \/var.*${MNT_OPTS}\)/\1,nodev,nosuid/" ${FSTAB}
fi

########################################
# File Ownership 
########################################
find / -nouser -print | xargs chown root
find / -nogroup -print | xargs chown :root
cat <<EOF > /etc/cron.daily/unowned_files
#!/bin/sh
# Fix user and group ownership of files without user
find / -nouser -print | xargs chown root
find / -nogroup -print | xargs chown :root
EOF
chown root:root /etc/cron.daily/unowned_files

########################################
# Additional GNOME Hardening
########################################
if [ -x /usr/bin/gconftool-2 ]; then
# Set Defualt Runlevel
sed -i 's/id:5:initdefault:/id:3:initdefault:/' /etc/inittab
# Legal Banner on GDM
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gdm/simple-greeter/banner_message_enable true
# Disable User List on GDM
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gdm/simple-greeter/disable_user_list true
# Disable Restart Buttons on GDM
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gdm/simple-greeter/disable_restart_buttons true
# Lock Gnome Menus
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/panel/global/locked_down true
# Disable Quick User Switching in Gnome
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /desktop/gnome/lockdown/disable_user_switching true
# Disable Gnome Power Settings
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gnome-power-manager/general/can_suspend false
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gnome-power-manager/general/can_hibernate false
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/lockdown.pkla
[consolekit]
Identity=unix-user:*
Action=org.freedesktop.consolekit.system.*
ResultAny=no
ResultInactive=no
ResultActive=no
[upower]
Identity=unix-user:*
Action=org.freedesktop.upower.system.*
ResultAny=no
ResultInactive=no
ResultActive=no
[devicekit]
Identity=unix-user:*
Action=org.freedesktop.devicekit.power.*
ResultAny=no
ResultInactive=no
ResultActive=no
EOF
# NSA SNAC Recommendation: Disable Gnome Automounter
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/nautilus/preferences/media_autorun_never true
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/nautilus/preferences/media_automount_open false
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/nautilus/preferences/media_automount false
# NSA SNAC Recommendation: Disable Gnome Thumbnailers
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /desktop/gnome/thumbnailers/disable_all true
# NIST 800-53 CCE-3315-9 (row 95): Screensaver in 15 Minutes; Forced Logout in 30 Minutes
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type string \
--set /desktop/gnome/session/max_idle_action "forced-logout"
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type int \
--set /desktop/gnome/session/max_idle_time 120
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type int \
--set /apps/gnome-screensaver/idle_delay 15
# NIST 800-53 CCE-14604-3 (row 96)
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gnome-screensaver/idle_activation_enabled true
# NIST 800-53 CCE-14023-6 (row 97)
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/gnome-screensaver/lock_enabled true
# NIST 800-53 CCE-14735-5 (row 98)
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type string \
--set /apps/gnome-screensaver/mode blank-only
# Disable Ctrl-Alt-Del in GNOME
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type string \
--set /apps/gnome_settings_daemon/keybindings/power ""
# Disable Clock Temperature
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/panel/applets/clock/prefs/show_temperature false
# Disable Clock Weather
gconftool-2 --direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type bool \
--set /apps/panel/applets/clock/prefs/show_weather false
fi

chmod 0700 /etc/cron.daily/unowned_files

########################################
# AIDE Initialization
########################################
if [ ! -e /var/lib/aide/aide.db.gz ]; then
	echo "Initializing AIDE database, this step may take quite a while!"
	/usr/sbin/aide --init &> /dev/null
	echo "AIDE database initialization complete."
	cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
fi
cat <<EOF > /etc/cron.weekly/aide-report
#!/bin/sh
# Generate Weekly AIDE Report
`/usr/sbin/aide --check > /var/log/aide/reports/$(hostname)-aide-report-$(date +%Y%m%d).txt`
EOF
chown root:root /etc/cron.weekly/aide-report
chmod 555 /etc/cron.weekly/aide-report
mkdir -p /var/log/aide/reports
chmod 700 /var/log/aide/reports
