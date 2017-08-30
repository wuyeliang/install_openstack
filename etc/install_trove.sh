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
if [  -e /etc/openstack_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack_tag/install_trove.tag ]
then 
	echo -e "\033[41;37m you have  been  install trove \033[0m"
	log_info "you have  been  install trove."
	exit
fi

#get config function 
if [  -e ${TOPDIR}/lib/source-function ]
then	
	source ${TOPDIR}/lib/source-function
else
	echo -e "\033[41;37m ${TOPDIR}/source-function is not exist. \033[0m"
	exit 1
fi

#create trove databases 
fn_create_database trove ${ALL_PASSWORD}
fn_log "fn_create_database trove ${ALL_PASSWORD}"


source /root/admin-openrc.sh
fn_create_user trove ${ALL_PASSWORD}
fn_log "fn_create_user trove ${ALL_PASSWORD}"



openstack role add --project service --user trove admin
fn_log "openstack role add --project service --user trove admin"


fn_create_service trove "Database" database
fn_log "fn_create_service trove "Database" database"

  

fn_create_endpoint_version database  8779 v1.0
fn_log "fn_create_endpoint_version database  8779 v1.0"

				  
yum clean all &&  yum install openstack-trove python-troveclient openstack-trove-guestagent openstack-trove-ui  puppet-trove  python-trove-tests  -y
fn_log "yum clean all &&  yum install openstack-trove python-troveclient openstack-trove-guestagent openstack-trove-ui  puppet-trove  python-trove-tests  -y"

function fn_get_trove_config () {
cat <<END >/tmp/tmp
DEFAULT log_dir  /var/log/trove
DEFAULT trove_auth_url  http://${MANAGER_IP}:5000/v2.0
DEFAULT nova_compute_url  http://${MANAGER_IP}:8774/v2
DEFAULT cinder_url  http://${MANAGER_IP}:8776/v1
DEFAULT swift_url  http://${MANAGER_IP}:8080/v1/AUTH_
DEFAULT notifier_queue_hostname  ${MANAGER_IP}
database connection  mysql+pymysql://trove:${ALL_PASSWORD}@${MANAGER_IP}/trove
DEFAULT rpc_backend  rabbit
oslo_messaging_rabbit rabbit_host  ${MANAGER_IP}
oslo_messaging_rabbit rabbit_userid  openstack
oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "
}

fn_get_trove_config
fn_set_conf /etc/trove/trove.conf
fn_log "fn_set_conf /etc/trove/trove.conf"


fn_get_trove_config
fn_set_conf /etc/trove/trove-taskmanager.conf
fn_log "fn_set_conf /etc/trove/trove-taskmanager.conf"

fn_get_trove_config
fn_set_conf /etc/trove/trove-conductor.conf
fn_log "fn_set_conf /etc/trove/trove-conductor.conf"



cat <<END >/etc/trove/api-paste.ini
[composite:trove]
use = call:trove.common.wsgi:versioned_urlmap
/: versions
/v1.0: troveapi
[app:versions]
paste.app_factory = trove.versions:app_factory
[pipeline:troveapi]
pipeline = cors faultwrapper osprofiler authtoken authorization contextwrapper ratelimit extensions troveapp
#pipeline = debug extensions troveapp
[filter:extensions]
paste.filter_factory = trove.common.extensions:factory
[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
[filter:authorization]
paste.filter_factory = trove.common.auth:AuthorizationMiddleware.factory
[filter:cors]
paste.filter_factory = oslo_middleware.cors:filter_factory
oslo_config_project = trove
[filter:contextwrapper]
paste.filter_factory = trove.common.wsgi:ContextMiddleware.factory
[filter:faultwrapper]
paste.filter_factory = trove.common.wsgi:FaultWrapper.factory
[filter:ratelimit]
paste.filter_factory = trove.common.limits:RateLimitingMiddleware.factory
[filter:osprofiler]
paste.filter_factory = osprofiler.web:WsgiMiddleware.factory
[app:troveapp]
paste.app_factory = trove.common.api:app_factory
#Add this filter to log request and response for debugging
[filter:debug]
paste.filter_factory = trove.common.wsgi:Debug
END
fn_log "/etc/trove/api-paste.ini"




cat <<END >/tmp/tmp
DEFAULT auth_strategy   keystone
DEFAULT add_addresses   True
DEFAULT network_label_regex   ^NETWORK_LABEL$
DEFAULT api_paste_config   /etc/trove/api-paste.ini
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   trove
keystone_authtoken password   ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/trove/trove.conf
fn_log "fn_set_conf /etc/trove/trove.conf"


cat <<END >/tmp/tmp
DEFAULT nova_proxy_admin_user   admin
DEFAULT nova_proxy_admin_pass   ${ALL_PASSWORD}
DEFAULT nova_proxy_admin_tenant_name   service
DEFAULT taskmanager_manager   trove.taskmanager.manager.Manager
DEFAULT use_nova_server_config_drive   True
DEFAULT network_driver trove.network.neutron.NeutronDriver
DEFAULT network_label_regex .*
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/trove/trove-taskmanager.conf
fn_log "fn_set_conf /etc/trove/trove-taskmanager.conf"






cat <<END >/tmp/tmp
DEFAULT rpc_backend   rabbit
DEFAULT nova_proxy_admin_user   trove
DEFAULT nova_proxy_admin_pass   trove_test
DEFAULT nova_proxy_admin_tenant_name   service
DEFAULT trove_auth_url   http://${MANAGER_IP}:35357/v2.0
oslo_messaging_rabbit rabbit_host   ${MANAGER_IP}
oslo_messaging_rabbit rabbit_userid   openstack
oslo_messaging_rabbit rabbit_password   ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/trove/trove-guestagent.conf
fn_log "fn_set_conf /etc/trove/trove-guestagent.conf"


su -s /bin/sh -c "trove-manage db_sync" trove
fn_log "su -s /bin/sh -c "trove-manage db_sync" trove"



systemctl enable openstack-trove-api.service   openstack-trove-taskmanager.service   openstack-trove-conductor.service
fn_log "systemctl enable openstack-trove-api.service   openstack-trove-taskmanager.service   openstack-trove-conductor.service"
systemctl restart  openstack-trove-api.service   openstack-trove-taskmanager.service   openstack-trove-conductor.service
fn_log "systemctl restart  openstack-trove-api.service   openstack-trove-taskmanager.service   openstack-trove-conductor.service"

sleep 30
source /root/admin-openrc.sh &&  trove list
fn_log "source /root/admin-openrc.sh &&  trove list"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install trove Sucessed          #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/install_trove.tag





