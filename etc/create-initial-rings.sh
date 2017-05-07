#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
NAMEHOST=$HOSTNAME
if [  -e ${TOPDIR}/lib/ocata-log.sh ]
then	
	source ${TOPDIR}/lib/ocata-log.sh
else
	echo -e "\033[41;37m ${TOPDIR}/ocata-log.sh is not exist. \033[0m"
	exit 1
fi
#input variable
if [  -e ${TOPDIR}/lib/installrc ]
then	
	source ${TOPDIR}/lib/installrc 
else
	echo -e "\033[41;37m ${TOPDIR}/lib/installr is not exist. \033[0m"
	exit 1
fi

#get config function 
if [  -e ${TOPDIR}/lib/source-function ]
then	
	source ${TOPDIR}/lib/source-function
else
	echo -e "\033[41;37m ${TOPDIR}/source-function is not exist. \033[0m"
	exit 1
fi






if [ -f  /etc/openstack-ocata_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi


if [ ! -f  /etc/openstack-ocata_tag/install_swift.tag ]
then 
	echo -e "\033[41;37m you haved install swift first. \033[0m"
	log_info "you haved install swift first."	
	exit 1
fi

if [  -f  /etc/openstack-ocata_tag/initial_rings.tag ]
then 
	echo -e "\033[41;37m you haved initial rings \033[0m"
	log_info "you haved install initial rings."	
	exit 1
fi


function fn_delete_file () {
if [ -e $1  ]
then
	rm -rf $1
	fn_log "$1"
fi
}


fn_delete_file /etc/swift/account.builder
fn_delete_file /etc/swift/container.builder
fn_delete_file /etc/swift/object.builder
fn_delete_file /etc/swift/account.ring.gz
fn_delete_file /etc/swift/container.ring.gz
fn_delete_file /etc/swift/account.ring.gz




swift-ring-builder /etc/swift/account.builder create 10 3 1
fn_log "swift-ring-builder /etc/swift/account.builder create 10 3 1"
swift-ring-builder /etc/swift/container.builder create 10 3 1
fn_log "swift-ring-builder /etc/swift/container.builder create 10 3 1"
swift-ring-builder /etc/swift/object.builder create 10 3 1
fn_log "swift-ring-builder /etc/swift/object.builder create 10 3 1"


cat ${TOPDIR}/lib/swiftrc | grep -v '\[' | grep -v ^$ >tmpswiftrc
fn_log "cat ${TOPDIR}/lib/swiftrc | grep -v '\[' | grep -v ^$ >tmpswiftrc"

while  read LINE
do
	NODEP_IP=`echo $LINE | grep -v '\[' | grep -v ^$ | awk -F " " '{print$1}'`
	fn_log "NODEP_IP=`echo $LINE | grep -v '\[' | grep -v ^$ | awk -F " " '{print$1}'`"
	NODE_DISK=`echo $LINE | grep -v '\[' | grep -v ^$ | awk -F " " '{print$2}'`
	fn_log "NODE_DISK=`echo $LINE | grep -v '\[' | grep -v ^$ | awk -F " " '{print$2}'`"
	swift-ring-builder /etc/swift/account.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6202 --device ${NODE_DISK} --weight 100
	fn_log "swift-ring-builder /etc/swift/account.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6202 --device ${NODE_DISK} --weight 100"
	swift-ring-builder /etc/swift/container.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6201 --device ${NODE_DISK} --weight 100
	fn_log "swift-ring-builder /etc/swift/container.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6201 --device ${NODE_DISK} --weight 100"
	swift-ring-builder /etc/swift/object.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6200 --device ${NODE_DISK} --weight 100
	fn_log "swift-ring-builder /etc/swift/object.builder add   --region 1 --zone 1 --ip ${NODEP_IP} --port 6200 --device ${NODE_DISK} --weight 100"
done   < tmpswiftrc

rm -f tmpswiftrc
fn_log "rm -f tmpswiftrc"


swift-ring-builder /etc/swift/account.builder
fn_log "swift-ring-builder /etc/swift/account.builder"
swift-ring-builder /etc/swift/account.builder rebalance
fn_log "swift-ring-builder /etc/swift/account.builder rebalance"



swift-ring-builder /etc/swift/container.builder
fn_log "swift-ring-builder /etc/swift/container.builder"
swift-ring-builder /etc/swift/container.builder rebalance
fn_log "swift-ring-builder /etc/swift/container.builder rebalance"
swift-ring-builder /etc/swift/object.builder
fn_log "swift-ring-builder /etc/swift/container.builder rebalance"
swift-ring-builder /etc/swift/object.builder rebalance
fn_log "swift-ring-builder /etc/swift/object.builder rebalance"

# create auth

cat <<"EOF" > /etc/ssh/ssh_config
UserKnownHostsFile /dev/null
ConnectTimeout 15
StrictHostKeyChecking no
EOF
fn_log "config /etc/ssh/ssh_config "
service sshd restart
fn_log "service sshd restart"

yum install expect -y
fn_log "yum install expect -y"
if [ -e ~/.ssh ]
then
    rm -rf ~/.ssh/*
    fn_log "rm -rf ~/.ssh/*"
fi

ssh-keygen -t dsa -f ~/.ssh/id_dsa -N ""
fn_log "ssh-keygen -t dsa -f ~/.ssh/id_dsa -N """

cat <<"EOF" >/tmp/ssh-auth
#!/usr/bin/expect -f
set host_ip [lindex $argv 0]
set host_user [lindex $argv 1]
set user_pwd [lindex $argv 2]
spawn ssh-copy-id $host_user@$host_ip
set p_loop 1
while { $p_loop } {
        expect {
                "password:"  { send "$user_pwd\r" }
                eof exit
        }
}
exit
EOF


NODE_IP_LIST=`cat ${TOPDIR}/lib/swiftrc  | grep -v '\[' | grep -v ^$ | awk -F " " '{print$1}' | sort -u`
for v  in ${NODE_IP_LIST}
do
	/usr/bin/expect /tmp/ssh-auth ${v} root ${ALL_PASSWORD}
	fn_log "/usr/bin/expect /tmp/ssh-auth ${v} root ${ALL_PASSWORD} "
	scp /etc/swift/*.gz ${v}:/etc/swift/
	fn_log "scp /etc/swift/*.gz ${v}:/etc/swift/"
	ssh $v "systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service   openstack-swift-account-reaper.service openstack-swift-account-replicator.service  openstack-swift-container.service   openstack-swift-container-auditor.service openstack-swift-container-replicator.service   openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service   openstack-swift-object-replicator.service openstack-swift-object-updater.service"
	fn_log "ssh $v "systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service   openstack-swift-account-reaper.service openstack-swift-account-replicator.service  openstack-swift-container.service   openstack-swift-container-auditor.service openstack-swift-container-replicator.service   openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service   openstack-swift-object-replicator.service openstack-swift-object-updater.service""
	ssh $v "systemctl restart openstack-swift-account.service openstack-swift-account-auditor.service   openstack-swift-account-reaper.service openstack-swift-account-replicator.service  openstack-swift-container.service   openstack-swift-container-auditor.service openstack-swift-container-replicator.service   openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service   openstack-swift-object-replicator.service openstack-swift-object-updater.service"
	fn_log "ssh $v "systemctl restart openstack-swift-account.service openstack-swift-account-auditor.service   openstack-swift-account-reaper.service openstack-swift-account-replicator.service  openstack-swift-container.service   openstack-swift-container-auditor.service openstack-swift-container-replicator.service   openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service   openstack-swift-object-replicator.service openstack-swift-object-updater.service""
done

rm -f /tmp/ssh-auth
fn_log "rm -f /tmp/ssh-auth"


systemctl enable openstack-swift-proxy.service memcached.service
fn_log "systemctl enable openstack-swift-proxy.service memcached.service"
systemctl restart openstack-swift-proxy.service memcached.service
fn_log "systemctl restart openstack-swift-proxy.service memcached.service"
echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        initial rings Sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi


echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/initial_rings.tag

