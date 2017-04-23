#!/bin/bash
#log function
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



if [  -e /etc/openstack-ocata_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on controller.  \033[0m"
	log_error "Oh no ! you can't execute this script on controller. "
	exit 1
fi
if [ -f  /etc/openstack-ocata_tag/swift.tag ]
then 
	echo -e "\033[41;37m you have  been  installed swift service. \033[0m"
	log_info "you have  been  installed swift service."
	exit
fi


BLOCK_MANAGER_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
function fn_install_node_swift () {
yum clean all && yum install xfsprogs rsync openstack-utils python2-swiftclient  openstack-swift-account openstack-swift-container   openstack-swift-object -y
fn_log "yum clean all && yum install xfsprogs rsync  openstack-utils python2-swiftclient openstack-swift-account openstack-swift-container   openstack-swift-object -y"
sed -i "/nobarrier/d" /etc/fstab
fn_log "sed -i "/nobarrier/d" /etc/fstab"
echo ${SWIFT_DISK}
for v  in ${SWIFT_DISK}
do
	echo $v
	df -h | grep /srv/node/${v}
	if [ $? -eq  0 ]
	then
		umount -f /dev/${v}
		fn_log "umount -f /dev/${v}"
	fi 
	fn_log "echo $v"
	if [ -e /srv/node/${v} ]
	then
		log_info "/srv/node/${v} is exist."
	else
		mkdir -p /srv/node/${v}
		fn_log "mkdir -p /srv/node/${v}"
	fi
	mkfs.xfs  -f /dev/${v}
	fn_log "mkfs.xfs  -f  /dev/${v}"
	echo "/dev/${v} /srv/node/${v} "  ' xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' >>/etc/fstab
	fn_log "echo "/dev/${v} /srv/node/${v} "  ' xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' >>/etc/fstab"
	mount /srv/node/${v}
	fn_log "mount /srv/node/${v}"
done


cat <<END >/etc/rsyncd.conf
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = ${BLOCK_MANAGER_IP}

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock
END
fn_log "set /etc/rsyncd.conf"


systemctl enable rsyncd.service &&  systemctl start rsyncd.service
fn_log "systemctl enable rsyncd.service &&  systemctl start rsyncd.service"

cat ${TOPDIR}/lib/account-server.conf >   /etc/swift/account-server.conf
fn_log "cat ${TOPDIR}/lib/account-server.conf >   /etc/swift/account-server.conf"
cat ${TOPDIR}/lib/container-server.conf >  /etc/swift/container-server.conf
fn_log "cat ${TOPDIR}/lib/container-server.conf >  /etc/swift/container-server.conf"
cat ${TOPDIR}/lib/object-server.conf >  /etc/swift/object-server.conf
fn_log "cat ${TOPDIR}/lib/object-server.conf >  /etc/swift/object-server.conf"

cat <<END >/tmp/tmp
DEFAULT bind_ip   ${BLOCK_MANAGER_IP}
DEFAULT bind_port   6002
DEFAULT user   swift
DEFAULT swift_dir   /etc/swift
DEFAULT devices   /srv/node
DEFAULT mount_check   True
pipeline:main pipeline   healthcheck recon account-server
filter:recon use   egg:swift#recon
filter:recon recon_cache_path   /var/cache/swift
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/swift/account-server.conf
fn_log "fn_set_conf /etc/swift/account-server.conf"

cat <<END >/tmp/tmp
DEFAULT bind_ip   ${BLOCK_MANAGER_IP}
DEFAULT bind_port   6001
DEFAULT user   swift
DEFAULT swift_dir   /etc/swift
DEFAULT devices   /srv/node
DEFAULT mount_check   True
pipeline:main pipeline   healthcheck recon container-server
filter:recon use   egg:swift#recon
filter:recon recon_cache_path   /var/cache/swift
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/swift/container-server.conf
fn_log "fn_set_conf /etc/swift/container-server.conf"

cat <<END >/tmp/tmp
DEFAULT bind_ip  ${BLOCK_MANAGER_IP}
DEFAULT bind_port  6000
DEFAULT user  swift
DEFAULT swift_dir  /etc/swift
DEFAULT devices  /srv/node
DEFAULT mount_check  True
pipeline:main pipeline  healthcheck recon object-server
filter:recon use  egg:swift#recon
filter:recon recon_cache_path  /var/cache/swift
filter:recon recon_lock_path  /var/lock
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/swift/object-server.conf
fn_log "fn_set_conf /etc/swift/object-server.conf"

chown -R swift:swift /srv/node
fn_log "chown -R swift:swift /srv/node"


if [ -e /var/cache/swift ]
then
	log_info "/var/cache/swift is exist."
else
	mkdir -p /var/cache/swift
	fn_log "mkdir -p /var/cache/swift"
fi

	


chown -R root:swift /var/cache/swift
fn_log "chown -R root:swift /var/cache/swift"
chmod -R 775 /var/cache/swift
fn_log "chmod -R 775 /var/cache/swift"

#muti num
swift-ring-builder /etc/swift/account.builder create 10 ${MUTIL_NUM} 1
fn_log "swift-ring-builder /etc/swift/account.builder create 10 ${MUTIL_NUM} 1"

for v  in ${OBJECT_NODE}
do
	for vd  in ${SWIFT_DISK}
	do
		swift-ring-builder /etc/swift/account.builder  | grep $v | grep ${vd} >/dev/null
		if [ $? -eq 0 ]
		then
			log_info "swift-ring-builder account.builder add   --region 1 --zone 1 --ip $v  --port 6002 --device ${vd} --weight 100 have been create."
		else
			swift-ring-builder /etc/swift/account.builder add   --region 1 --zone 1 --ip $v  --port 6002 --device ${vd} --weight 100
			fn_log "swift-ring-builder account.builder add   --region 1 --zone 1 --ip $v  --port 6002 --device ${vd} --weight 100"
		fi
	done
done 	
swift-ring-builder /etc/swift/account.builder rebalance
fn_log "swift-ring-builder account.builder rebalance"



swift-ring-builder /etc/swift/container.builder create 10 ${MUTIL_NUM} 1
fn_log "swift-ring-builder /etc/swift/container.builder create 10 ${MUTIL_NUM} 1"

for v  in ${OBJECT_NODE}
do
	for vd  in ${SWIFT_DISK}
	do
		swift-ring-builder /etc/swift/container.builder | grep $v | grep ${vd} >/dev/null
		if [ $? -eq 0 ]
		then
			log_info "swift-ring-builder account.builder add   --region 1 --zone 1 --ip $v  --port 6001 --device ${vd} --weight 100 have been create."
		else
			swift-ring-builder /etc/swift/container.builder add   --region 1 --zone 1 --ip $v --port 6001 --device ${vd} --weight 100
			fn_log "swift-ring-builder container.builder add   --region 1 --zone 1 --ip $v --port 6001 --device ${vd} --weight 100"
		fi
	done
done 	
swift-ring-builder /etc/swift/container.builder rebalance
fn_log "swift-ring-builder /etc/swift/container.builder rebalance"

swift-ring-builder /etc/swift/object.builder create 10 ${MUTIL_NUM} 1
fn_log "swift-ring-builder /etc/swift/object.builder create 10 ${MUTIL_NUM} 1"

for v  in ${OBJECT_NODE}
do
	for vd  in ${SWIFT_DISK}
	do
		swift-ring-builder /etc/swift/object.builder | grep $v | grep ${vd} >/dev/null
		if [ $? -eq 0 ]
		then
			log_info "swift-ring-builder account.builder add   --region 1 --zone 1 --ip $v  --port 6000 --device ${vd} --weight 100 have been create."
		else
			swift-ring-builder /etc/swift/object.builder add   --region 1 --zone 1 --ip $v --port 6000 --device ${vd} --weight 100
			fn_log "swift-ring-builder object.builder add   --region 1 --zone 1 --ip $v --port 6001 --device ${vd} --weight 100"
		fi
	done
done 	
swift-ring-builder /etc/swift/object.builder rebalance
fn_log "swift-ring-builder /etc/swift/object.builder rebalance"

cat ${TOPDIR}/lib/swift.conf >/etc/swift/swift.conf
fn_log "cat ${TOPDIR}/lib/swift.conf >/etc/swift/swift.conf"
cat <<END >/tmp/tmp
swift-hash swift_hash_path_suffix  ${ALL_PASSWORD}
swift-hash swift_hash_path_prefix  ${ALL_PASSWORD}
storage-policy:0 name  Policy-0
storage-policy:0 default  yes
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/swift/swift.conf
fn_log "fn_set_conf /etc/swift/swift.conf"


chown -R root:swift /etc/swift
fn_log "chown -R root:swift /etc/swift"

#systemctl enable openstack-swift-proxy.service memcached.service
#fn_log "systemctl enable openstack-swift-proxy.service memcached.service"
#systemctl restart openstack-swift-proxy.service memcached.service
#fn_log "systemctl restart openstack-swift-proxy.service memcached.service"
systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service
fn_log "systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
systemctl restart openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service
fn_log "systemctl restart openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
systemctl enable openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service
fn_log "systemctl enable openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service"
systemctl restart openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service
fn_log "systemctl restart openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service"
systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service
fn_log "systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service"
systemctl restart openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service
fn_log "systemctl restart openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service"


}
OBJECT_NODE=`cat ${TOPDIR}/lib/swiftrc | grep '\[' | awk -F '[' '{print$2}' | awk -F ']' '{print$1}'`
fn_log "OBJECT_NODE=`cat ${TOPDIR}/lib/swiftrc | grep '\[' | awk -F '[' '{print$2}' | awk -F ']' '{print$1}'`"
echo " "
SWIFT_DISK='sdb sdc'
#SWIFT_DISK=`cat ${TOPDIR}/lib/swiftrc | grep -A 1  ${HOSTNAME}  | grep -v  ${HOSTNAME}`
fn_log "SWIFT_DISK=`cat ${TOPDIR}/lib/swiftrc | grep -A 1  ${HOSTNAME}  | grep -v  ${HOSTNAME}`"
echo  ${SWIFT_DISK}

if [  -n  ${SWIFT_DISK} ]
then
	log_info "${SWIFT_DISK} is null."
else
	fn_install_node_swift
fi

cat <<END >/root/admin-openrc.sh 
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${MANAGER_IP}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END

cat <<END >/root/demo-openrc.sh  
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${MANAGER_IP}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END



source /root/demo-openrc.sh
fn_log "source /root/demo-openrc.sh"
sleep 10
swift stat
fn_log "swift stat"


echo -e "\033[32m ####################################################### \033[0m"
echo -e "\033[32m ###       Install swift Service  Sucessed         #### \033[0m"
echo -e "\033[32m ####################################################### \033[0m"

if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/swift.tag
