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

if [ -f  /etc/openstack_tag/install_glance.tag ]
then 
	echo -e "\033[41;37m you haved install glance \033[0m"
	log_info "you haved install glance."	
	exit
fi

#create glance databases 

fn_create_database glance ${ALL_PASSWORD}


unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
fn_create_user glance ${ALL_PASSWORD}



openstack role add --project service --user glance admin
fn_log "openstack role add --project service --user glance admin"



fn_create_service glance "OpenStack Image" image
fn_log "fn_create_service glance "OpenStack Image" image"

fn_create_endpoint image 9292
fn_log "fn_create_endpoint image 9292"


#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi



yum clean all && yum install openstack-glance -y
fn_log "yum clean all && yum install openstack-glance -y"
unset http_proxy https_proxy ftp_proxy no_proxy 



cat <<END >/tmp/tmp
database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance
keystone_authtoken auth_uri  http://${HOSTNAME}:5000
keystone_authtoken auth_url  http://${HOSTNAME}:35357
keystone_authtoken memcached_servers  ${HOSTNAME}:11211
keystone_authtoken auth_type  password
keystone_authtoken project_domain_name  default
keystone_authtoken user_domain_name  default
keystone_authtoken project_name  service
keystone_authtoken username  glance
keystone_authtoken password  ${ALL_PASSWORD}
paste_deploy flavor  keystone
glance_store stores  file,http
glance_store default_store  file
glance_store filesystem_store_datadir  /var/lib/glance/images/
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/glance/glance-api.conf
fn_log "fn_set_conf /etc/glance/glance-api.conf" 



cat <<END >/tmp/tmp
database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance
keystone_authtoken auth_uri  http://${HOSTNAME}:5000
keystone_authtoken auth_url  http://${HOSTNAME}:35357
keystone_authtoken memcached_servers  ${HOSTNAME}:11211
keystone_authtoken auth_type  password
keystone_authtoken project_domain_name  default
keystone_authtoken user_domain_name  default
keystone_authtoken project_name  service
keystone_authtoken username  glance
keystone_authtoken password  ${ALL_PASSWORD}
paste_deploy flavor  keystone
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/glance/glance-registry.conf
fn_log "fn_set_conf /etc/glance/glance-registry.conf" 




su -s /bin/sh -c "glance-manage db_sync" glance 
fn_log "su -s /bin/sh -c "glance-manage db_sync" glance"


systemctl enable openstack-glance-api.service   openstack-glance-registry.service  && systemctl start openstack-glance-api.service   openstack-glance-registry.service
fn_log "systemctl enable openstack-glance-api.service   openstack-glance-registry.service  && systemctl start openstack-glance-api.service   openstack-glance-registry.service"



sleep 5



function fn_create_image () {
source /root/admin-openrc.sh  && \
cp -a ${TOPDIR}/lib/cirros-0.3.4-x86_64-disk.img /tmp/  && \
openstack image create "cirros"   --file /tmp/cirros-0.3.4-x86_64-disk.img   --disk-format qcow2 --container-format bare   --public
fn_log "create image"

openstack image list
fn_log "openstack image list"
}
GLANCE_ID=`openstack image list | grep cirros  | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${GLANCE_ID}x = cirrosx ]
then
	log_info "glance image cirros-0.3.4-x86_64 have  been  create."
else
	fn_create_image
fi


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Glance Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/install_glance.tag