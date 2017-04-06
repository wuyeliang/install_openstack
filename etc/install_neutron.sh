#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
if [  -e $PWD/lib/ocata-log.sh ]
then	
	source $PWD/lib/ocata-log.sh
else
	echo -e "\033[41;37m $PWD/ocata-log.sh is not exist. \033[0m"
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


#get config function 
if [  -e $PWD/lib/source-function ]
then	
	source $PWD/lib/source-function
else
	echo -e "\033[41;37m $PWD/source-function is not exist. \033[0m"
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

if [ -f  /etc/openstack-ocata_tag/install_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit 1
fi

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


#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
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


yum clean all && yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables -y"
cat <<END >/tmp/tmp
database connection   mysql+pymysql://neutron:${ALL_PASSWORD}@${HOSTNAME}/neutron
DEFAULT core_plugin   ml2
DEFAULT service_plugins   router
DEFAULT allow_overlapping_ips   true
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${HOSTNAME}
DEFAULT  auth_strategy   keystone
keystone_authtoken auth_uri   http://${HOST_NAME}:5000
keystone_authtoken  auth_url   http://${HOST_NAME}:35357
keystone_authtoken memcached_servers   ${HOST_NAME}:11211
keystone_authtoken  auth_type   password
keystone_authtoken  project_domain_name   default
keystone_authtoken  user_domain_name   default
keystone_authtoken  project_name   service
keystone_authtoken  username   neutron
keystone_authtoken  password   ${ALL_PASSWORD}
DEFAULT notify_nova_on_port_status_changes   true
DEFAULT notify_nova_on_port_data_changes   true
nova auth_url   http://${HOST_NAME}:35357
nova auth_type   password
nova project_domain_name   default
nova user_domain_name   default
nova region_name   RegionOne
nova project_name   service
nova username   nova
nova  password   ${ALL_PASSWORD}
oslo_concurrency lock_path   /var/lib/neutron/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/neutron.conf
fn_log "fn_set_conf /etc/neutron/neutron.conf"


cat <<END >/tmp/tmp
ml2 type_drivers  flat,vlan,vxlan
ml2  tenant_network_types  vxlan
ml2  mechanism_drivers  linuxbridge,l2population
ml2  extension_drivers  port_security
ml2_type_flat flat_networks  provider
ml2_type_vxlan vni_ranges  1:1000
securitygroup enable_ipset  true
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"


SECONF_ETH=${NET_DEVICE_NAME}
FIRST_ETH_IP=${MANAGER_IP}

cat <<END >/tmp/tmp
linux_bridge physical_interface_mappings   provider:${SECONF_ETH}
vxlan enable_vxlan   true
vxlan local_ip   ${FIRST_ETH_IP}
vxlan l2_population   true
securitygroup enable_security_group   true
securitygroup firewall_driver   neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/plugins/ml2/linuxbridge_agent.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/linuxbridge_agent.ini"



cat <<END >/tmp/tmp
DEFAULT interface_driver  linuxbridge
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/l3_agent.ini
fn_log "fn_set_conf /etc/neutron/l3_agent.ini"



cat <<END >/tmp/tmp
DEFAULT interface_driver  linuxbridge
DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq
DEFAULT enable_isolated_metadata  true
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/dhcp_agent.ini
fn_log "fn_set_conf /etc/neutron/dhcp_agent.ini"




cat <<END >/tmp/tmp
DEFAULT nova_metadata_ip  ${HOST_NAME}
DEFAULT metadata_proxy_shared_secret  ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/metadata_agent.ini
fn_log "fn_set_conf /etc/neutron/metadata_agent.ini"


cat <<END >/tmp/tmp
neutron url  http://${HOST_NAME}:9696
neutron auth_url  http://${HOST_NAME}:35357
neutron auth_type  password
neutron project_domain_name  default
neutron user_domain_name  default
neutron region_name  RegionOne
neutron project_name  service
neutron username  neutron
neutron password  ${ALL_PASSWORD}
neutron service_metadata_proxy  true
neutron metadata_proxy_shared_secret  ${ALL_PASSWORD}
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"

rm -f /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fn_log "rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
fn_log "su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron"

systemctl restart openstack-nova-api.service
fn_log "systemctl restart openstack-nova-api.service"


systemctl enable neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service &&  systemctl start neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service
fn_log "systemctl enable neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service &&  systemctl start neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service"
systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service
fn_log "systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service"

SECONF_ETH=${NET_DEVICE_NAME}

nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} 
fn_log "nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} "

nmcli con mod ${SECONF_ETH} connection.autoconnect yes
fn_log "nmcli con mod ${SECONF_ETH} connection.autoconnect yes"

source /root/admin-openrc.sh
neutron ext-list
fn_log "neutron ext-list"
neutron agent-list
fn_log "neutron agent-list"
source /root/demo-openrc.sh

if [ -e /root/.ssh ]
then
    rm -rf  /root/.ssh
    fn_log "rm -rf  /root/.ssh"
fi

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
FLAVOR_NANO=`openstack flavor list | grep m1.nano | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${FLAVOR_NANO}x = m1.nanox ]
then
    log_info  "m1.nanox had created."
else
     openstack flavor create --id 0 --vcpus 1 --ram 512 --disk 1 m1.nano
     fn_log "openstack flavor create --id 0 --vcpus 1 --ram 512 --disk 1 m1.nano"
fi







systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "

systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server
fn_log "systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server"

if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_neutron.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  Install Neutron Sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

















