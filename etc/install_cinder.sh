#！/bin/bash
#log function
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


if [  -e /etc/openstack-ocata_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi
if [ -f  /etc/openstack-ocata_tag/install_nova.tag ]
then 
	log_info "nova have installed ."
else
	echo -e "\033[41;37m you should install nova first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-ocata_tag/install_cinder.tag ]
then 
	echo -e "\033[41;37m you have  been  install cinder \033[0m"
	log_info "you have  been  install cinder."
	exit
fi

#create cinder databases 
fn_create_database cinder ${ALL_PASSWORD}
source /root/admin-openrc.sh
fn_create_user cinder ${ALL_PASSWORD}
fn_log "fn_create_user cinder ${ALL_PASSWORD}"

openstack role add --project service --user cinder admin
fn_log "openstack role add --project service --user cinder admin"


fn_create_service cinder "OpenStack Block Storage" volume
fn_log "fn_create_service cinder "OpenStack Block Storage" volume"


fn_create_service cinderv2 "OpenStack Block Storage" volumev2
fn_log "fn_create_service cinderv2 "OpenStack Block Storage" volumev2"



fn_create_endpoint_version volume 8776 v1
fn_log "fn_create_endpoint_version volume 8776 v1"

fn_create_endpoint_version volumev2 8776 v2
fn_log "fn_create_endpoint_version volumev2 8776 v2"

#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null "
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi
				  
yum clean all &&  yum install openstack-cinder -y
fn_log "yum clean all &&  yum install openstack-cinder -y"

FIRST_ETH_IP=${MANAGER_IP}


cat <<END >/tmp/tmp
database connection   mysql+pymysql://cinder:${ALL_PASSWORD}@${NAMEHOST}/cinder
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${NAMEHOST}
DEFAULT auth_strategy   keystone
keystone_authtoken auth_uri   http://${NAMEHOST}:5000
keystone_authtoken auth_url   http://${NAMEHOST}:35357
keystone_authtoken memcached_servers   ${NAMEHOST}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   cinder
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${MANAGER_IP}
oslo_concurrency lock_path   /var/lib/cinder/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/cinder/cinder.conf
fn_log "fn_set_conf /etc/cinder/cinder.conf" 




su -s /bin/sh -c "cinder-manage db sync" cinder 
fn_log "su -s /bin/sh -c "cinder-manage db sync" cinder"

openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne
fn_log "openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne"

systemctl restart openstack-nova-api.service
fn_log "systemctl restart openstack-nova-api.service"
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service   
fn_log "systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service   "

#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null "
}


#for storage service 
if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi
yum clean all &&  yum install   lvm2 -y
fn_log "yum clean all &&  yum install   lvm2 -y"

systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service"




function fn_create_cinder_volumes () {
if [  -z  ${CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
	return 1
else
	pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}
	fn_log "pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}"
fi
yum clean all &&  yum install openstack-cinder targetcli python-keystone   -y
fn_log "yum clean all &&  yum install openstack-cinder targetcli python-keystone -y"
unset http_proxy https_proxy ftp_proxy no_proxy 






cat <<END >/tmp/tmp
database connection   mysql+pymysql://cinder:${ALL_PASSWORD}@${NAMEHOST}/cinder
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${NAMEHOST}
DEFAULT auth_strategy   keystone
keystone_authtoken auth_uri   http://${NAMEHOST}:5000
keystone_authtoken auth_url   http://${NAMEHOST}:35357
keystone_authtoken memcached_servers   ${NAMEHOST}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   cinder
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${MANAGER_IP}
lvm volume_driver   cinder.volume.drivers.lvm.LVMVolumeDriver
lvm volume_group   cinder-volumes
lvm iscsi_protocol   iscsi
lvm iscsi_helper   lioadm
DEFAULT enabled_backends   lvm
DEFAULT glance_api_servers   http://${NAMEHOST}:9292
oslo_concurrency lock_path   /var/lib/cinder/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/cinder/cinder.conf
fn_log "fn_set_conf /etc/cinder/cinder.conf" 






systemctl enable openstack-cinder-volume.service target.service &&  systemctl restart openstack-cinder-volume.service target.service 
fn_log "systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service "
}



VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes have  been  created."
else
	fn_create_cinder_volumes
fi
	

                    



sleep 15


source /root/admin-openrc.sh && openstack volume service list
fn_log "source /root/admin-openrc.sh && openstack volume service list"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install Cinder Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_cinder.tag





