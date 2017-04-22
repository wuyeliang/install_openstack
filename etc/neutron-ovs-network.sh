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




yum clean all && yum install  -y install openstack-utils openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch
fn_log "yum clean all && yum install  -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch"



cat <<END >/tmp/tmp
DEFAULT core_plugin  ml2
DEFAULT service_plugins  router
DEFAULT auth_strategy  keystone
DEFAULT state_path  /var/lib/neutron
DEFAULT  allow_overlapping_ips  True
DEFAULT  transport_url  rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
keystone_authtoken auth_uri  http://${MANAGER_IP}:5000
keystone_authtoken auth_url  http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers  ${MANAGER_IP}:11211
keystone_authtoken auth_type  password
keystone_authtoken project_domain_name  default
keystone_authtoken user_domain_name  default
keystone_authtoken project_name  service
keystone_authtoken username  neutron
keystone_authtoken password  ${ALL_PASSWORD}
oslo_concurrency lock_path  \$state_path/lock
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/neutron.conf
fn_log "fn_set_conf /etc/neutron/neutron.conf"
chmod 640 /etc/neutron/neutron.conf
fn_log "chmod 640 /etc/neutron/neutron.conf" 
chgrp neutron /etc/neutron/neutron.conf 
fn_log "chgrp neutron /etc/neutron/neutron.conf "



cat <<END >/tmp/tmp
DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver
DEFAULT external_network_bridge 
END
fn_log "create /tmp/tmp "
fn_set_conf /etc/neutron/l3_agent.ini
fn_log "fn_set_conf /etc/neutron/l3_agent.ini"




cat <<END >/tmp/tmp
DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver
DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq
DEFAULT enable_isolated_metadata  True
END
fn_log "create /tmp/tmp "
fn_set_conf /etc/neutron/dhcp_agent.ini
fn_log "fn_set_conf /etc/neutron/dhcp_agent.ini"


cat <<END >/tmp/tmp
DEFAULT nova_metadata_ip  ${MANAGER_IP}
DEFAULT metadata_proxy_shared_secret  metadata_secret
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/metadata_agent.ini
fn_log "fn_set_conf /etc/neutron/metadata_agent.ini"


cat <<END >/tmp/tmp
ml2 type_drivers  flat,vlan,gre,vxlan
ml2 tenant_network_types 
ml2 mechanism_drivers openvswitch,l2population
ml2 extension_drivers  port_security
securitygroup enable_security_group  True
securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
END
fn_log "create /tmp/tmp "


fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"




rm -f /etc/neutron/plugin.ini  && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini 
fn_log "rm -f /etc/neutron/plugin.ini  && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini "
systemctl start openvswitch 
fn_log "systemctl start openvswitch "
systemctl enable openvswitch
fn_log "systemctl enable openvswitch" 


NET_INT=`ip add | grep br-int | wc -l `
if [ ${NET_INT} -eq 0  ] 
then
	ovs-vsctl add-br br-int 
	fn_log "ovs-vsctl add-br br-int"
fi




for service in dhcp-agent l3-agent metadata-agent openvswitch-agent
do
	systemctl start neutron-$service
	fn_log "systemctl start neutron-$service"
	systemctl enable neutron-$service
	fn_log "systemctl enable neutron-$service"
done 


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




if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/network_neutron.tag
echo -e "\033[32m ############################################### \033[0m"
echo -e "\033[32m ##  Install Neutron(network) Sucessed.     #### \033[0m"
echo -e "\033[32m ############################################### \033[0m"

