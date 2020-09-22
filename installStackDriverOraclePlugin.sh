#!/bin/bash

if [ $# -ne 3 ]; then
    echo $#
    echo $0: usage: installStackDriverOraclePlugin.sh {ORACLE_HOME or ORACLE_CLIENT HOME} {Oracle Primary Group} {TNS_ADMIN}
    exit 1
fi

home=$1
group=$2
tnsadmin=$3

echo "The following inputs are received $home $group $tnsadmin"

function log
{
    now=$(date +%Y%m%d%H%M%S)
    echo "$now: $*" >> /tmp/installStackDriverOraclePlugin.log
}

function install_package() {
    sudo yum install git -y || return 1
    sudo yum install autoconf -y || return 1
    sudo yum install automake -y || return 1
    sudo yum install libtool-ltdl-devel -y || return 1
    sudo yum install bison -y || return 1
    sudo yum install flex-devel -y || return 1
    sudo yum install libtool -y || return 1
    sudo yum install flex -y || return 1
    log "install_package completed"
}

function download_collectd() {
if [ -d collectd ]; then
echo "collectd directory found.. removing the directory"
rm -rf collectd
fi
git clone https://github.com/Stackdriver/collectd.git || return 1
log "download_collectd complted"
}

function configure(){
    export ORACLE_HOME=$home
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME:$LD_LIBRARY_PATH
    cd collectd
    ./build.sh
    ./configure --prefix=/opt/stackdriver/collectd --enable-oracle --libdir=/opt/stackdriver/collectd/lib64
    make
    make install
    log "configuration completed"
    /sbin/usermod -a -G $group root
}


function die() {
    error "$1"
    log "Install aborted"
    exit 1
}

function check_pre(){
	if [ ! -f /etc/init.d/stackdriver-agent ]; then
	echo "Please, install stack driver first."
        return 1
        fi
}



main(){
check_pre || die "Unable to run precheck"
install_package || die "Unable to install package"
download_collectd  || die "Unable to download collected"
configure  || die "Unable to configure collected"
echo "Install completed successfully"
echo "Modifying /etc/default/stackdriver-agent file"
file="/etc/default/stackdriver-agent"
echo "#################################" >> $file
echo "# This was added by installStackDriverOraclePlugin.sh script " >> $file
echo "export ORACLE_HONE=$home" >> $file
echo "export TNS_ADMIN=$tnsadmin" >> $file
echo "export LD_LIBRARY_PATH=$home/lib:$LD_LIBRARY_PATH" >> $file
echo "export PATH=$PATH:$home/bin" >> $file
echo "#################################" >> $file
echo "Done"
}

main
