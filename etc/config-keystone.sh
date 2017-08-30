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
	source  ${TOPDIR}/lib/source-function
	fn_log "source  ${TOPDIR}/lib/source-function"
else
	echo -e "\033[41;37m ${TOPDIR}/source-function is not exist. \033[0m"
	exit 1
fi

if [ ${http_proxy}x = x -a  ${https_proxy}x = x  -a ${ftp_proxy}x = x ]
then
	log_info "proxy is none."
else
	echo -e "\033[41;37m you should unset proxy. \033[0m"
	exit 1
fi
if [  -e /etc/openstack_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack_tag/install_mariadb.tag ]
then 
	log_info "mariadb have installed ."
else
	echo -e "\033[41;37m you should install mariadb first. \033[0m"
	exit
fi

if [ -f  /etc/openstack_tag/config_keystone.tag ]
then 
	echo -e "\033[41;37m etc/openstack_tag/config_keystone.tag \033[0m"
	log_info "you have  been  install keystone."
	exit
fi



#create databases
fn_create_database keystone ${ALL_PASSWORD}
fn_log "fn_create_database keystone ${ALL_PASSWORD}"




yum clean all && yum install openstack-keystone httpd mod_wsgi   memcached python-memcached -y
fn_log "yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y"


cat <<END >/etc/sysconfig/memcached
PORT="11211"
USER="memcached"
MAXCONN="1024"
CACHESIZE="64"
OPTIONS="-l ${MANAGER_IP},::1"
END
fn_log "set /etc/sysconfig/memcached"

#start memcached.service
systemctl enable memcached.service &&  systemctl restart memcached.service 
fn_log "systemctl enable memcached.service &&  systemctl restart memcached.service"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"


cat <<END >/tmp/tmp
database connection  mysql+pymysql://keystone:${ALL_PASSWORD}@${MANAGER_IP}/keystone
token provider  fernet
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/keystone/keystone.conf
fn_log "fn_set_conf /etc/keystone/keystone.conf" 


su -s /bin/sh -c "keystone-manage db_sync" keystone
fn_log "su -s /bin/sh -c "keystone-manage db_sync" keystone"

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
fn_log "keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone "

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
fn_log "keystone-manage credential_setup --keystone-user keystone --keystone-group keystone"

keystone-manage bootstrap --bootstrap-password ${ALL_PASSWORD}   --bootstrap-admin-url http://${MANAGER_IP}:35357/v3/   --bootstrap-internal-url http://${MANAGER_IP}:35357/v3/   --bootstrap-public-url http://${MANAGER_IP}:5000/v3/   --bootstrap-region-id RegionOne
fn_log "keystone-manage bootstrap --bootstrap-password ${ALL_PASSWORD}   --bootstrap-admin-url http://${MANAGER_IP}:35357/v3/   --bootstrap-internal-url http://${MANAGER_IP}:35357/v3/   --bootstrap-public-url http://${MANAGER_IP}:5000/v3/   --bootstrap-region-id RegionOne"

[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak
fn_log "[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak"

sed  -i  "s/#ServerName www.example.com:80/ServerName ${HOSTNAME}/" /etc/httpd/conf/httpd.conf
fn_log "sed  -i  's/#ServerName www.example.com:80/ServerName $HOSTNAME/' /etc/httpd/conf/httpd.conf"

RESULT_HTTP=`cat /etc/httpd/conf/httpd.conf | grep $HOSTNAME | awk -F " " '{print$2}'`
if [ ${RESULT_HTTP} = ${HOSTNAME}  ]
then
	log_info "http servername is ${HOSTNAME} "
else
	log_error "http servername is null"
	exit 1
fi

rm -f /etc/httpd/conf.d/wsgi-keystone.conf  && ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
fn_log "rm -f /etc/httpd/conf.d/wsgi-keystone.conf  && ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/ "

systemctl enable httpd.service && systemctl start httpd.service 
fn_log "systemctl enable httpd.service && systemctl start httpd.service "
unset http_proxy https_proxy ftp_proxy no_proxy 

export OS_USERNAME=admin
export OS_PASSWORD=${ALL_PASSWORD}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${MANAGER_IP}:35357/v3
export OS_IDENTITY_API_VERSION=3
sleep 5 

fn_create_project service "Service Project"
fn_create_project demo "Demo Project"

fn_create_user demo ${ALL_PASSWORD}

fn_create_role user
fn_log "fn_create_role user"

openstack role add --project demo --user demo user
fn_log "openstack role add --project demo --user demo user"

unset OS_AUTH_URL OS_PASSWORD
fn_log "unset OS_AUTH_URL OS_PASSWORD"

openstack --os-auth-url http://${MANAGER_IP}:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password ${ALL_PASSWORD}
fn_log "openstack --os-auth-url http://${MANAGER_IP}:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password ${ALL_PASSWORD}"

openstack --os-auth-url http://${MANAGER_IP}:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password ${ALL_PASSWORD}
fn_log "openstack --os-auth-url http://${MANAGER_IP}:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password ${ALL_PASSWORD}"

cat <<END >/root/admin-openrc.sh 
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${HOST_NAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END

cat <<END >/root/demo-openrc.sh  
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${HOST_NAME}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END

source ~/admin-openrc.sh
openstack token issue
fn_log "openstack token issue"

echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       Install Keystone Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/config_keystone.tag
