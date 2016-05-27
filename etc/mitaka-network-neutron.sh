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

if [ -f  /etc/openstack-mitaka_tag/network_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit
fi
NAMEHOST=${HOST_NAME}


yum clean all && yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables openstack-utils python-openstackclient -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables openstack-utils python-openstackclient -y"







[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST}  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken memcached_servers  ${NAMEHOST}:11211 &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_type  password  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_name  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_name  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  ${ALL_PASSWORD}  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True
fn_log "config /etc/neutron/neutron.conf "


SECONF_ETH=${NET_DEVICE_NAME}
FIRST_ETH_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  linux_bridge physical_interface_mappings  provider:${SECONF_ETH} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  enable_vxlan  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  local_ip  ${FIRST_ETH_IP} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan l2_population  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
fn_log "config /etc/neutron/plugins/ml2/linuxbridge_agent.ini"

[ -f   /etc/neutron/l3_agent.ini_bak ] || cp -a    /etc/neutron/l3_agent.ini    /etc/neutron/l3_agent.ini_bak 
openstack-config --set  /etc/neutron/l3_agent.ini  DEFAULT     interface_driver  neutron.agent.linux.interface.BridgeInterfaceDriver && \
openstack-config --set   /etc/neutron/l3_agent.ini  DEFAULT     external_network_bridge    && \
openstack-config --set  /etc/neutron/l3_agent.ini  DEFAULT     verbose  True  
fn_log "config /etc/neutron/l3_agent.ini "

[ -f   /etc/neutron/dhcp_agent.ini_bak ] || cp -a    /etc/neutron/dhcp_agent.ini    /etc/neutron/dhcp_agent.ini_bak 
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     interface_driver  neutron.agent.linux.interface.BridgeInterfaceDriver    && \
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq   && \
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     enable_isolated_metadata  True   && \
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     verbose  True   
fn_log "config /etc/neutron/dhcp_agent.ini "

echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf
fn_log "echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf"
[ -f /etc/neutron/metadata_agent.ini_bak-2 ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak-2 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT nova_metadata_ip  ${NAMEHOST}   && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT metadata_proxy_shared_secret  ${ALL_PASSWORD} && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
fn_log "config /etc/neutron/metadata_agent.ini"


rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fn_log "rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"


SECONF_ETH=${NET_DEVICE_NAME}

nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} 
fn_log "nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} "
systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent 
fn_log "systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent "


systemctl enable neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service &&  systemctl start    neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service
fn_log "systemctl enable   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service &&  systemctl start  neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service"
systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service
fn_log "systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service"


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
neutron ext-list
fn_log "neutron ext-list"
neutron agent-list
fn_log "neutron agent-list"
source /root/demo-openrc.sh

KEYPAIR=`nova keypair-list | grep  mykey | awk -F " " '{print$2}'`
if [  ${KEYPAIR}x = mykeyx ]
then
	log_info "keypair had added."
else
	ssh-keygen -t dsa -f ~/.ssh/id_dsa -N ""
	fn_log "ssh-keygen -t dsa -f ~/.ssh/id_dsa -N """
	openstack keypair create --public-key ~/.ssh/id_dsa.pub mykey
	fn_log "openstack keypair create --public-key ~/.ssh/id_dsa.pub mykey"
fi

SECRULE=`nova secgroup-list-rules  default | grep 22 | awk -F " " '{print$4}'`
if [ x${SECRULE} = x22 ]
then 
	log_info "port 22 and icmp had add to secgroup."
else
	openstack security group rule create --proto icmp default 
	fn_log "openstack security group rule create --proto icmp default "
	openstack security group rule create --proto tcp --dst-port 22 default
	fn_log "openstack security group rule create --proto tcp --dst-port 22 default"
fi
source /root/admin-openrc.sh

PUBLIC_NET=`neutron net-list | grep provider |wc -l`
if [ ${PUBLIC_NET}  -eq 0 ]
then
	neutron net-create --shared --provider:physical_network provider   --provider:network_type flat provider
	fn_log "neutron net-create --shared --provider:physical_network provider   --provider:network_type flat provider"
else
	log_info "provider net is exist."
fi

SUB_PUBLIC_NET=`neutron subnet-list | grep provider |wc -l `
if [ ${SUB_PUBLIC_NET}  -eq 0 ]
then
	neutron subnet-create --name provider   --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END}   --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}    provider ${NEUTRON_PUBLIC_NET}
	fn_log "neutron subnet-create --name provider   --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END}   --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}    provider ${NEUTRON_PUBLIC_NET}"
else
	log_info "sub_public is exist."
fi
source /root/demo-openrc.sh
PRIVATE_NET=`neutron net-list | grep selfservice |wc -l`
if [ ${PRIVATE_NET}  -eq 0 ]
then
	neutron net-create selfservice
	fn_log "neutron net-create selfservice"
else
	log_info "selfservice net is exist."
fi
SUB_PRIVATE_NET=`neutron subnet-list | grep selfservice |wc -l`
if [ ${SUB_PRIVATE_NET}  -eq 0 ]
then
	neutron subnet-create --name selfservice   --dns-nameserver ${PRIVATE_NET_DNS} --gateway ${PRIVATE_NET_GW}  selfservice ${NEUTRON_PRIVATE_NET}
	fn_log "neutron subnet-create --name selfservice   --dns-nameserver ${PRIVATE_NET_DNS}--gateway ${PRIVATE_NET_GW}  selfservice ${NEUTRON_PRIVATE_NET}"
else
	log_info "selfservice subnet is exist."
fi
source /root/admin-openrc.sh
ROUTE_VALUE=`neutron net-show provider | grep router:external | awk -F " "  '{print$4}'`
if [ ${ROUTE_VALUE}x  = Truex  ]
then
	log_info "the value had changed."
else
	neutron net-update provider --router:external
	fn_log "neutron net-update provider --router:external"
fi
source /root/demo-openrc.sh
ROUTE_NU=`neutron router-list | grep router | wc -l`
if [ ${ROUTE_NU}  -eq 0 ]
then
	neutron router-create router
	fn_log "neutron router-create router"
	neutron router-interface-add router selfservice
	fn_log "neutron router-interface-add router selfservice"
	neutron router-gateway-set router provider
	fn_log "neutron router-gateway-set router provider"
else
	log_info "router had created."
fi

source /root/admin-openrc.sh
ip netns
fn_log "ip netns"
neutron router-port-list router
fn_log "neutron router-port-list router"









systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent 
fn_log "systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent "

if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/network_neutron.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  Install Neutron Sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"