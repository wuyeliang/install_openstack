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

if [ -f  /etc/openstack-ocata_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-ocata_tag/install_manila.tag ]
then 
	echo -e "\033[41;37m you haved install manila \033[0m"
	log_info "you haved install manila."	
	exit
fi

#create manila databases 
fn_create_database manila ${ALL_PASSWORD} 

unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 



fn_create_user manila ${ALL_PASSWORD}
fn_log "fn_create_user manila ${ALL_PASSWORD}"
openstack role add --project service --user manila admin
fn_log "openstack role add --project service --user manila admin"


fn_create_service manila "OpenStack Shared File Systems" share
fn_log "fn_create_service manila "OpenStack Shared File Systems" share"


fn_create_service manilav2  "OpenStack Shared File Systems" sharev2
fn_log "fn_create_service manilav2  "OpenStack Shared File Systems" sharev2"

fn_create_endpoint_version share  8786 v1
fn_log "fn_create_endpoint_version share  8786 v1"

fn_create_endpoint_version sharev2   8786 v2
fn_log "fn_create_endpoint_version sharev2   8786 v2"



#for controller
yum clean all &&  yum install openstack-manila python-manilaclient  openstack-manila-ui  -y
fn_log "yum clean all && yum install openstack-manila  openstack-manila-ui -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

cat <<END >/tmp/tmp
database connection   mysql+pymysql://manila:${ALL_PASSWORD}@${MANAGER_IP}/manila
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
DEFAULT default_share_type   default_share_type
DEFAULT share_name_template   share-%s
DEFAULT rootwrap_config   /etc/manila/rootwrap.conf
DEFAULT api_paste_config   /etc/manila/api-paste.ini
DEFAULT auth_strategy   keystone
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken auth_type   password
keystone_authtoken project_domain_id   default
keystone_authtoken user_domain_id   default
keystone_authtoken project_name   service
keystone_authtoken username   manila
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${MANAGER_IP}
oslo_concurrency lock_path   /var/lock/manila
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/manila/manila.conf
fn_log "fn_set_conf /etc/manila/manila.conf"



su -s /bin/sh -c "manila-manage db sync" manila
fn_log "su -s /bin/sh -c "manila-manage db sync" manila"


systemctl enable openstack-manila-api.service openstack-manila-scheduler.service  && systemctl start openstack-manila-api.service openstack-manila-scheduler.service
fn_log "systemctl enable openstack-manila-api.service openstack-manila-scheduler.service  && systemctl start openstack-manila-api.service openstack-manila-scheduler.service"


##for manila node

yum clean all &&  yum install openstack-manila-share python2-PyMySQL -y
fn_log "yum clean all && yum install openstack-manila-share python2-PyMySQL -y"
unset http_proxy https_proxy ftp_proxy no_proxy 




cat <<END >/tmp/tmp
database connection   mysql://manila:${ALL_PASSWORD}@${MANAGER_IP}/manila
database transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
DEFAULT  default_share_type   default_share_type
DEFAULT  rootwrap_config   /etc/manila/rootwrap.conf
DEFAULT auth_strategy   keystone
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken auth_type   password
keystone_authtoken project_domain_id   default
keystone_authtoken user_domain_id   default
keystone_authtoken project_name   service
keystone_authtoken username   manila
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${MANAGER_IP}
oslo_concurrency lock_path   /var/lib/manila/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/manila/manila.conf
fn_log "fn_set_conf /etc/manila/manila.conf"


function fn_driver_manila () {
yum clean all &&  yum install openstack-neutron openstack-neutron-linuxbridge ebtables -y
fn_log "yum clean all &&  yum install openstack-neutron openstack-neutron-linuxbridge ebtables -y"
LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`

cat <<END >/tmp/tmp
DEFAULT enabled_share_backends   generic
DEFAULT enabled_share_protocols   NFS
neutron url   http://${LOCAL_MANAGER_IP_ALL}:9696
neutron auth_uri   http://${LOCAL_MANAGER_IP_ALL}:5000
neutron auth_url   http://${LOCAL_MANAGER_IP_ALL}:35357
neutron memcached_servers   ${LOCAL_MANAGER_IP_ALL}:11211
neutron auth_type   password
neutron project_domain_name   default
neutron user_domain_name   default
neutron region_name   RegionOne
neutron project_name   service
neutron username   neutron
neutron password   ${ALL_PASSWORD}
nova auth_uri   http://${LOCAL_MANAGER_IP_ALL}:5000
nova auth_url   http://${LOCAL_MANAGER_IP_ALL}:35357
nova memcached_servers   ${LOCAL_MANAGER_IP_ALL}:11211
nova auth_type   password
nova project_domain_name   default
nova user_domain_name   default
nova region_name   RegionOne
nova project_name   service
nova username   nova
nova password   ${ALL_PASSWORD}
cinder auth_uri   http://${LOCAL_MANAGER_IP_ALL}:5000
cinder auth_url   http://${LOCAL_MANAGER_IP_ALL}:35357
cinder memcached_servers   ${LOCAL_MANAGER_IP_ALL}:11211
cinder auth_type   password
cinder project_domain_name   default
cinder user_domain_name   default
cinder region_name   RegionOne
cinder project_name   service
cinder username   cinder
cinder password   ${ALL_PASSWORD}
generic share_backend_name   GENERIC
generic share_driver   manila.share.drivers.generic.GenericShareDriver
generic driver_handles_share_servers   True
generic service_instance_flavor_id   100
generic service_image_name   manila-service-image
generic service_instance_user   manila
generic service_instance_password   manila
generic interface_driver   manila.network.linux.interface.BridgeInterfaceDriver
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/manila/manila.conf
fn_log "fn_set_conf /etc/manila/manila.conf"

systemctl enable openstack-manila-share.service target.service && systemctl start openstack-manila-share.service target.service
fn_log "systemctl enable openstack-manila-share.service target.service && systemctl start openstack-manila-share.service target.service"
}

function fn_no_driver_manila () {

yum clean all &&   yum install lvm2 nfs-utils nfs4-acl-tools portmap -y
fn_log "yum clean all &&   yum install lvm2 nfs-utils nfs4-acl-tools portmap -y"
systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service"


VOLUNE_NAME=`vgs | grep manila-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = manila-volumesx ]
then
	log_info "manila-volumes had created."
else
	pvcreate ${MANILA_DISK}  && vgcreate manila-volumes ${MANILA_DISK}
	fn_log "pvcreate ${MANILA_DISK}  && vgcreate manila-volumes ${MANILA_DISK}"
fi

LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
cat <<END >/tmp/tmp
DEFAULT enabled_share_backends   lvm
DEFAULT enabled_share_protocols   NFS
lvm share_backend_name   LVM
lvm share_driver   manila.share.drivers.lvm.LVMShareDriver
lvm driver_handles_share_servers   False
lvm lvm_share_volume_group   manila-volumes
lvm lvm_share_export_ip   ${LOCAL_MANAGER_IP_ALL}
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/manila/manila.conf
fn_log "fn_set_conf /etc/manila/manila.conf"
}



if [  -z  ${MANILA_DISK} ]
then 
	fn_driver_manila
	fn_log "fn_driver_manila"
else
	fn_no_driver_manila
	fn_log "fn_no_driver_manila"
fi
systemctl enable openstack-manila-share.service &&  systemctl start openstack-manila-share.service
fn_log "systemctl enable openstack-manila-share.service &&  systemctl start openstack-manila-share.service"




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
manila service-list
fn_log "manila service-list"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Manila Sucessed          #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_manila.tag