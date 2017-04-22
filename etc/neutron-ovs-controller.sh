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
	echo -e "\033[41;37m ${TOPDIR}/lib/source-function is not exist. \033[0m"
	exit 1
fi





if [  -e /etc/openstack-ocata_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-ocata_tag/install_cinder.tag ]
then 
	log_info "cinder have installed ."
else
	echo -e "\033[41;37m you should install cinder first. \033[0m"
    exit 1
fi

if [ -f  /etc/openstack-ocata_tag/controller_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit 1
fi


yum clean all && yum install  -y install openstack-utils openstack-neutron openstack-neutron-ml2 
fn_log "yum clean all && yum install  -y install openstack-neutron openstack-neutron-ml2 "


#create neutron databases 
fn_create_database neutron ${ALL_PASSWORD}
unset http_proxy https_proxy ftp_proxy no_proxy 

source /root/admin-openrc.sh

fn_create_user neutron ${ALL_PASSWORD}
fn_log "fn_create_user neutron ${ALL_PASSWORD}"
openstack role add --project service --user neutron admin
fn_log "openstack role add --project service --user neutron admin"

fn_create_service neutron "OpenStack Networking" network
fn_log "fn_create_service neutron "OpenStack Networking" network"

fn_create_endpoint network 9696
fn_log "fn_create_endpoint network 9696"

cat <<END >/tmp/tmp
DEFAULT core_plugin   ml2
DEFAULT service_plugins   router
DEFAULT auth_strategy   keystone
DEFAULT state_path   /var/lib/neutron
DEFAULT dhcp_agent_notification   True
DEFAULT allow_overlapping_ips   True
DEFAULT notify_nova_on_port_status_changes   True
DEFAULT notify_nova_on_port_data_changes   True
DEFAULT  transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   neutron
keystone_authtoken password   ${ALL_PASSWORD}
database  connection   mysql+pymysql://neutron:${ALL_PASSWORD}@${MANAGER_IP}/neutron
nova auth_url   http://${MANAGER_IP}:35357
nova auth_type   password
nova project_domain_name   default
nova user_domain_name   default
nova region_name   RegionOne
nova project_name   service
nova username   nova
nova password   ${ALL_PASSWORD}
oslo_concurrency lock_path   \$state_path/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/neutron.conf
fn_log "fn_set_conf /etc/neutron/neutron.conf"


chmod 640 /etc/neutron/neutron.conf
fn_log "chmod 640 /etc/neutron/neutron.conf" 
chgrp neutron /etc/neutron/neutron.conf 
fn_log "chgrp neutron /etc/neutron/neutron.conf "


cat <<END >/tmp/tmp
ml2 type_drivers   flat,vlan,gre,vxlan
ml2 tenant_network_types  
ml2 mechanism_drivers   openvswitch,l2population
ml2 extension_drivers   port_security
securitygroup enable_security_group   True
securitygroup  firewall_driver   neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
securitygroup  enable_ipset   True
END
fn_log "create /tmp/tmp "

fn_set_conf  /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf  /etc/neutron/plugins/ml2/ml2_conf.ini"




cat <<END >/tmp/tmp
neutron url   http://${MANAGER_IP}:9696
neutron auth_url   http://${MANAGER_IP}:35357
neutron auth_type   password
neutron project_domain_name   default
neutron user_domain_name   default
neutron region_name   RegionOne
neutron project_name   service
neutron username   neutron
neutron password   ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "
fn_set_conf  /etc/nova/nova.conf
fn_log "fn_set_conf  /etc/nova/nova.conf"

rm -f /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini 
fn_log "rm -f /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini "


su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head" 
fn_log "su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head" "
systemctl start neutron-server
fn_log "systemctl start neutron-server" 
systemctl enable neutron-server
fn_log "systemctl enable neutron-server" 
systemctl restart openstack-nova-api
fn_log "systemctl restart openstack-nova-api" 



if [  ${CONTROLLER_COMPUTER}  = True   ]
then
	/usr/bin/bash ${TOPDIR}/etc/ocata-computer_install.sh
	fn_log "/usr/bin/bash ${TOPDIR}/etc/ocata-computer_install.sh"
elif [ ${CONTROLLER_COMPUTER}  = False ]
then
	log_info "Do not install openstack-nova-compute on controller. "
else
	echo -e "\033[41;37m please check  CONTROLLER_COMPUTER option in installrc . \033[0m"
	exit 1
fi





if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/controller_neutron.tag
echo -e "\033[32m ############################################### \033[0m"
echo -e "\033[32m ##  Install Neutron(controller) Sucessed.  #### \033[0m"
echo -e "\033[32m ############################################### \033[0m"
