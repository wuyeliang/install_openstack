#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
NAMEHOST=$HOSTNAME
if [  -e ${TOPDIR}/lib/openstack-log.sh ]
then	
	source ${TOPDIR}/lib/openstack-log.sh
else
	echo -e "\033[41;37m ${TOPDIR}/openstack-log.sh is not exist. \033[0m"
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




if [  -e /etc/openstack_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi

if [ -f  /etc/openstack_tag/install_swift.tag ]
then 
	echo -e "\033[41;37m you haved install swift \033[0m"
	log_info "you haved install swift."	
	exit
fi



unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 



fn_create_user swift ${ALL_PASSWORD}
fn_log "fn_create_user swift ${ALL_PASSWORD}"
openstack role add --project service --user swift admin
fn_log "openstack role add --project service --user swift admin"

fn_create_service swift  "OpenStack Object Storage" object-store
fn_log "fn_create_service swift  "OpenStack Object Storage" object-store"


fn_create_endpoint_swift object-store 8080 v1
fn_log "fn_create_endpoint_swift object-store 8080 v1" 



#for controller

yum clean all && yum install openstack-swift-proxy python-swiftclient   python-keystoneclient python-keystonemiddleware   memcached -y
fn_log "yum clean all && yum install openstack-swift-proxy python-swiftclient   python-keystoneclient python-keystonemiddleware   memcached -y"
unset http_proxy https_proxy ftp_proxy no_proxy 


cat ${TOPDIR}/lib/proxy-server.conf >/etc/swift/proxy-server.conf
fn_log "cat ${TOPDIR}/proxy-server.conf >/etc/swift/proxy-server.conf"
cat <<END >/tmp/tmp
filter:authtoken auth_uri  http://${MANAGER_IP}:5000
filter:authtoken auth_url  http://${MANAGER_IP}:35357
filter:authtoken memcached_servers  ${MANAGER_IP}:11211
filter:authtoken password  ${ALL_PASSWORD}
filter:cache memcache_servers  ${MANAGER_IP}:11211
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/swift/proxy-server.conf
fn_log "fn_set_conf /etc/swift/proxy-server.conf"




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

systemctl enable openstack-swift-proxy.service memcached.service
fn_log "systemctl enable openstack-swift-proxy.service memcached.service"
systemctl restart openstack-swift-proxy.service memcached.service
fn_log "systemctl restart openstack-swift-proxy.service memcached.service"


chown -R root:swift /etc/swift
fn_log "chown -R root:swift /etc/swift"

systemctl enable openstack-swift-proxy.service memcached.service
fn_log "systemctl enable openstack-swift-proxy.service memcached.service"
systemctl restart openstack-swift-proxy.service memcached.service
fn_log "systemctl restart openstack-swift-proxy.service memcached.service"




source /root/demo-openrc.sh
fn_log "source /root/demo-openrc.sh"
#sleep 10 
#swift stat
fn_log "swift stat"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install swift Sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/install_swift.tag