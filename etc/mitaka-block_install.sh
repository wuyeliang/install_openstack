#!/bin/bash
#log function
if [  -e $PWD/lib/mitaka-log.sh ]
then	
	source $PWD/lib/mitaka-log.sh
else
	echo -e "\033[41;37m $PWD/mitaka-log.sh is not exist. \033[0m"
	exit 1
fi
#input variable
if [  -e $PWD/lib/installrc ]
then	
	source $PWD/lib/installrc 
else
	echo -e "\033[41;37m $PWD/lib/installr is not exist. \033[0m"
	exit 1
fi

if [  -e /etc/openstack-mitaka_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script oncontroller.  \033[0m"
	log_error "Oh no ! you can't execute this script oncontroller. "
	exit 1
fi
if [ -f  /etc/openstack-mitaka_tag/cinder.tag ]
then 
	echo -e "\033[41;37m you had installed cinder service. \033[0m"
	log_info "you had installed cinder service."	
	exit
fi


yum install -y lvm2  python-openstackclient  python-oslo-policy openstack-cinder targetcli python-keystonemiddleware* 
fn_log "yum install -y lvm2 openstack-cinder targetcli python-oslo-policy "



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
	log_info "cinder-volumes had created."
else
	fn_create_cinder_volumes
fi


BLOCK_MANAGER_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
[ -f   /etc/cinder/cinder.conf_bak  ] || cp -a  /etc/cinder/cinder.conf /etc/cinder/cinder.conf_bak && \
openstack-config --set /etc/cinder/cinder.conf  database connection  mysql+pymysql://cinder:${ALL_PASSWORD}@${HOST_NAME}/cinder   && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit  && \
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${HOST_NAME}  && \
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack  && \
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}  && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${HOST_NAME}:5000 && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${HOST_NAME}:35357 && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken  memcached_servers  ${HOST_NAME}:11211 && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_type  password && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_name  default && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_name  default && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && \
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  ${ALL_PASSWORD} && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${BLOCK_MANAGER_IP} && \
openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lib/cinder/tmp && \
openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && \
openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && \
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && \
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_api_servers  http://${HOST_NAME}:9292  && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm
fn_log "openstack-config --set /etc/cinder/cinder.conf "

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
export OS_AUTH_URL=http://${HOST_NAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
END







cat <<END >/root/demo-openrc.sh  
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${HOST_NAME}:5000/v3
export OS_IDENTITY_API_VERSION=3
END



source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
cinder service-list
fn_log "cinder service-list"

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
	log_info "ceilometer had not installed."
fi









echo -e "\033[32m ####################################################### \033[0m"
echo -e "\033[32m ###       Install Cinder Service  Sucessed         #### \033[0m"
echo -e "\033[32m ####################################################### \033[0m"

if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/cinder.tag
    
	
	
























