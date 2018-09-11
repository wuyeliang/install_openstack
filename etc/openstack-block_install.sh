#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
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



if [  -e /etc/openstack_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on controller.  \033[0m"
	log_error "Oh no ! you can't execute this script on controller. "
	exit 1
fi
if [ -f  /etc/openstack_tag/cinder.tag ]
then 
	echo -e "\033[41;37m you have  been  installed cinder service. \033[0m"
	log_info "you have  been  installed cinder service."
	exit
fi

yum clean all && yum install -y openstack-utils python-openstackclient
fn_log "yum clean all && yum install -y openstack-utils"

yum install -y lvm2  openstack-cinder targetcli python-keystone 
fn_log "yum install -y lvm2  openstack-cinder targetcli python-keystone "




systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service"

function fn_create_cinder_volumes () {
if [  -z  ${BLOCK_CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
else
	pvcreate ${BLOCK_CINDER_DISK}  && vgcreate cinder-volumes ${BLOCK_CINDER_DISK}
	fn_log "pvcreate ${BLOCK_CINDER_DISK}  && vgcreate cinder-volumes ${BLOCK_CINDER_DISK}"
fi

}



VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes have  been  created."
else
	fn_create_cinder_volumes
fi


BLOCK_MANAGER_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
cat <<END >/tmp/tmp
DEFAULT my_ip  ${BLOCK_MANAGER_IP}
DEFAULT log_dir  /var/log/cinder
DEFAULT state_path  /var/lib/cinder
DEFAULT auth_strategy  keystone
DEFAULT transport_url  rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
DEFAULT glance_api_servers  http://${MANAGER_IP}:9292
DEFAULT enable_v3_api  True
database connection  mysql+pymysql://cinder:${ALL_PASSWORD}@${MANAGER_IP}/cinder
keystone_authtoken www_authenticate_uri  http://${MANAGER_IP}:5000
keystone_authtoken auth_url  http://${MANAGER_IP}:5000
keystone_authtoken memcached_servers  ${MANAGER_IP}:11211
keystone_authtoken auth_type  password
keystone_authtoken project_domain_name  default
keystone_authtoken user_domain_name  default
keystone_authtoken project_name  service
keystone_authtoken username  cinder
keystone_authtoken password  ${ALL_PASSWORD}
oslo_concurrency lock_path  /var/lib/cinder/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/cinder/cinder.conf
fn_log "fn_set_conf /etc/cinder/cinder.conf" 




cat <<END >/tmp/tmp
DEFAULT enabled_backends  lvm
lvm target_helper  lioadm
lvm  target_protocol  iscsi
lvm  target_ip_address  ${BLOCK_MANAGER_IP}
lvm volume_group  cinder-volumes
lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver
lvm volumes_dir  /var/lib/cinder/volumes
END

fn_set_conf /etc/cinder/cinder.conf
fn_log "fn_set_conf /etc/cinder/cinder.conf"

chown cinder:cinder /etc/cinder/cinder.conf
fn_log "chown cinder:cinder /etc/cinder/cinder.conf"


systemctl enable openstack-cinder-volume.service target.service && systemctl restart openstack-cinder-volume.service target.service
fn_log "systemctl enable openstack-cinder-volume.service target.service && systemctl restart openstack-cinder-volume.service target.service"


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



source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
openstack volume service list
fn_log "openstack volume service list"

function fn_install_ceilometer () {
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_notifications driver  messagingv2
fn_log "openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_notifications driver  messagingv2"



if [ -e /etc/systemd/system/multi-user.target.wants/openstack-cinder-api.service  ]
then
	systemctl restart openstack-cinder-volume.service
	fn_log "systemctl restart openstack-cinder-volume.service"
fi
}


source /root/admin-openrc.sh 
fn_log "source /root/admin-openrc.sh "
USER_ceilometer=`openstack user list | grep ceilometer | grep -v ceilometer_domain_admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_ceilometer}x = ceilometerx ]
then
	fn_install_ceilometer
	fn_log "fn_install_ceilometer"
else
	log_info "ceilometer have  been  not installed."
fi









echo -e "\033[32m ####################################################### \033[0m"
echo -e "\033[32m ###       Install Cinder Service  Sucessed         #### \033[0m"
echo -e "\033[32m ####################################################### \033[0m"

if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/cinder.tag
    
	
	
























