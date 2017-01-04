#!/bin/bash

#
# Permissions for this file must be set with
# sudo chown root:root drop_cache.sh
# sudo chmod u+s drop_cache.sh
# In order for to use it without asking for explicit sudo rights every time
#
if [ "$(whoami)" != "root" ]; then
    pushd ${BASH_SOURCE%/*} > /dev/null
    P=`pwd`
    popd > /dev/null
    S=$(basename $(readlink -nf ${BASH_SOURCE%}))
    >&2 echo "Error: This script must be executed as root."
    >&2 echo "Call it with 'sudo ./drop_cache.sh' after the script has been added to"
    >&2 echo "/etc/sudoers"
    >&2 echo ""
    >&2 echo "Add this script to sudoers by running 'sudo visudo' and pasting the"
    >&2 echo "line below into the sudoers file:"
    >&2 echo "ALL ALL=(ALL:ALL) NOPASSWD: ${P}/${S} \"\""
    exit 1
fi

sync
#sudo bash -c "echo 3 > /proc/sys/vm/drop_caches"
echo 3 > /proc/sys/vm/drop_caches

