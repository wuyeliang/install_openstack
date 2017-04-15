#!/bin/bash
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

if [ -f  /etc/openstack-ocata_tag/install_magnum.tag ]
then 
	echo -e "\033[41;37m you had install magnum \033[0m"
	log_info "you had install magnum."	
	exit
fi

#create magnum databases 
fn_create_database magnum ${ALL_PASSWORD} 
fn_log "fn_create_database magnum ${ALL_PASSWORD}"


source /root/admin-openrc.sh
fn_create_user magnum ${ALL_PASSWORD} 
fn_log "fn_create_user magnum ${ALL_PASSWORD}"

openstack role add --project service --user magnum admin
fn_log "openstack role add --project service --user magnum admin"

fn_create_service magnum  "OpenStack Container Infrastructure Management Service" container-infra
fn_log "fn_create_service magnum  "OpenStack Container Infrastructure Management Service" container-infra"



fn_create_endpoint container-infra '9511/v1'
fn_log "fn_create_endpoint container-infra '9511/v1'"


fn_create_domain magnum "Owns users and projects   created by magnum"
fn_log "fn_create_domain magnum "Owns users and projects   created by magnum""





USER_magnum=`openstack user list | grep magnum_domain_admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_magnum}x = magnum_domain_adminx ]
then
	log_info "openstack user had created  magnum"
else
	openstack user create --domain magnum    magnum_domain_admin --password ${ALL_PASSWORD} 
	fn_log "openstack user create magnum --password ${ALL_PASSWORD}"
	openstack role add --domain magnum --user magnum_domain_admin admin
	fn_log "openstack role add --project service --user magnum admin"
fi


yum clean all &&  yum install openstack-magnum-api openstack-magnum-conductor *magnum* -y
fn_log "yum clean all &&  yum install openstack-magnum-api openstack-magnum-conductor *magnum* -y"



unset http_proxy https_proxy ftp_proxy no_proxy

cat <<END >/tmp/tmp
api host   ${MANAGER_IP}
certificates cert_manager_type   barbican
cinder_client region_name   RegionOne
database connection   mysql+pymysql://magnum:${ALL_PASSWORD}@${MANAGER_IP}/magnum
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_version   v3
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000/v3
keystone_authtoken project_domain_id   default
keystone_authtoken project_name   service
keystone_authtoken user_domain_id   default
keystone_authtoken password   ${ALL_PASSWORD}
keystone_authtoken username   magnum
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken auth_type   password
trust trustee_domain_name   magnum
trust trustee_domain_admin_name   magnum_domain_admin
trust trustee_domain_admin_password   ${ALL_PASSWORD}
oslo_messaging_notifications driver   messaging
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
oslo_concurrency lock_path   /var/lib/magnum/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/magnum/magnum.conf
fn_log "fn_set_conf /etc/magnum/magnum.conf"


su -s /bin/sh -c "magnum-db-manage upgrade" magnum
fn_log "su -s /bin/sh -c "magnum-db-manage upgrade" magnum"
systemctl enable openstack-magnum-api.service   openstack-magnum-conductor.service
fn_log "systemctl enable openstack-magnum-api.service   openstack-magnum-conductor.service"
systemctl restart openstack-magnum-api.service   openstack-magnum-conductor.service
fn_log "systemctl restart openstack-magnum-api.service   openstack-magnum-conductor.service"

sleep 10
source /root/admin-openrc.sh &&  magnum service-list
fn_log "source /root/admin-openrc.sh &&  magnum service-list"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install magnum Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_magnum.tag





