#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
if [  -e $PWD/lib/liberty-log.sh ]
then	
	source $PWD/lib/liberty-log.sh
else
	echo -e "\033[41;37m $PWD/liberty-log.sh is not exist. \033[0m"
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
if [  -e /etc/openstack-liberty_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-liberty_tag/install_cinder.tag ]
then 
	log_info "cinder have installed ."
else
	echo -e "\033[41;37m you should install cinder first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-liberty_tag/install_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit
fi

#create neutron databases 
function  fn_create_neutron_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE neutron;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create  database neutron"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASENEUTRON=`cat test | grep neutron`
rm -rf test 
if [ ${DATABASENEUTRON}x = neutronx ]
then
	log_info "neutron database had installed."
else
	fn_create_neutron_database
fi

unset http_proxy https_proxy ftp_proxy no_proxy 

source /root/admin-openrc.sh
USER_NEUTRON=`openstack user list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NEUTRON}x = neutronx ]
then
	log_info "openstack user had created  neutron"
else
	openstack user create neutron  --password ${ALL_PASSWORD}
	fn_log "openstack user create neutron  --password ${ALL_PASSWORD}"
	openstack role add --project service --user neutron admin
	fn_log "openstack role add --project service --user neutron admin"
fi

SERVICE_NEUTRON=`openstack service list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NEUTRON}x = neutronx ]
then 
	log_info "openstack service create neutron."
else
	openstack service create --name neutron --description "OpenStack Networking" network
	fn_log "openstack service create --name neutron --description "OpenStack Networking" networ"
fi



ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep network  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep network   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep network   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create neutron."
else
	openstack endpoint create --region RegionOne   network public http://${NAMEHOST}:9696  &&   openstack endpoint create --region RegionOne   network internal http://${NAMEHOST}:9696 &&   openstack endpoint create --region RegionOne   network admin http://${NAMEHOST}:9696
	fn_log "openstack endpoint create --region RegionOne   network public http://${NAMEHOST}:9696  &&   openstack endpoint create --region RegionOne   network internal http://${NAMEHOST}:9696 &&   openstack endpoint create --region RegionOne   network admin http://${NAMEHOST}:9696"
fi





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


yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge python-neutronclient -y
fn_log "yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge python-neutronclient -y"
[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak 
openstack-config --set  /etc/neutron/neutron.conf database connection  mysql://neutron:${ALL_PASSWORD}@${NAMEHOST}/neutron &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST}  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  ${ALL_PASSWORD}  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT nova_url  http://${NAMEHOST}:8774/v2  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${NAMEHOST}:35357  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova auth_plugin  password  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova project_domain_id  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova user_domain_id  default  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova project_name  service  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova username  nova  &&   \
openstack-config --set  /etc/neutron/neutron.conf nova password  ${ALL_PASSWORD}  &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp  &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True
fn_log "config /etc/neutron/neutron.conf "

[ -f  /etc/neutron/plugins/ml2/ml2_conf.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/ml2_conf.ini  /etc/neutron/plugins/ml2/ml2_conf.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,vxlan && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  linuxbridge,l2population && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers  port_security && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  vxlan && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  public && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges  1:1000 && \
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True
fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini "

SECONF_ETH=${NET_DEVICE_NAME}
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`
[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  linux_bridge physical_interface_mappings  public:${SECONF_ETH} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  enable_vxlan  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  local_ip  ${FIRST_ETH_IP} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan l2_population  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent  prevent_arp_spoofing  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver && \
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
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     verbose  True   && \
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     dnsmasq_config_file  /etc/neutron/dnsmasq-neutron.conf   && \
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     interface_driver  neutron.agent.linux.interface.BridgeInterfaceDriver
fn_log "config /etc/neutron/dhcp_agent.ini "

echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf
fn_log "echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf"
[ -f /etc/neutron/metadata_agent.ini_bak-2 ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak-2 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_uri  http://${NAMEHOST}:5000 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_url  http://${NAMEHOST}:35357 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_region  RegionOne && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_plugin  password && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_domain_id  default && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT user_domain_id  default && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_name  service && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT username  neutron && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT password  ${ALL_PASSWORD} && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT nova_metadata_ip  ${NAMEHOST} && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT metadata_proxy_shared_secret  ${ALL_PASSWORD} && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
fn_log "config /etc/neutron/metadata_agent.ini"

openstack-config --set  /etc/nova/nova.conf  neutron url  http://${NAMEHOST}:9696 && \
openstack-config --set  /etc/nova/nova.conf  neutron auth_url  http://${NAMEHOST}:35357 && \
openstack-config --set  /etc/nova/nova.conf  neutron auth_plugin  password && \
openstack-config --set  /etc/nova/nova.conf  neutron project_domain_id  default && \
openstack-config --set  /etc/nova/nova.conf  neutron user_domain_id  default && \
openstack-config --set  /etc/nova/nova.conf  neutron region_name  RegionOne && \
openstack-config --set  /etc/nova/nova.conf  neutron project_name service && \
openstack-config --set  /etc/nova/nova.conf  neutron username  neutron && \
openstack-config --set  /etc/nova/nova.conf  neutron password  ${ALL_PASSWORD} && \
openstack-config --set  /etc/nova/nova.conf  neutron service_metadata_proxy  True && \
openstack-config --set  /etc/nova/nova.conf  neutron metadata_proxy_shared_secret  ${ALL_PASSWORD} && \

fn_log "config /etc/nova/nova.conf"

rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
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



source /root/admin-openrc.sh
neutron ext-list
fn_log "neutron ext-list"
neutron agent-list
fn_log "neutron agent-list"
source /root/demo-openrc.sh

KEYPAIR=`nova keypair-list | grep  demo-key | awk -F " " '{print$2}'`
if [  ${KEYPAIR}x = demo-keyx ]
then
	log_info "keypair had added."
else
	nova keypair-add demo-key
	fn_log "nova keypair-add demo-key"
fi

SECRULE=`nova secgroup-list-rules  default | grep 22 | awk -F " " '{print$4}'`
if [ x${SECRULE} = x22 ]
then 
	log_info "port 22 and icmp had add to secgroup."
else
	nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
	fn_log "nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 "
	nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
	fn_log "nova secgroup-add-rule default tcp 22 22 0.0.0.0/0"
fi
source /root/admin-openrc.sh

PUBLIC_NET=`neutron net-list | grep public |wc -l`
if [ ${PUBLIC_NET}  -eq 0 ]
then
	neutron net-create public --shared --provider:physical_network public   --provider:network_type flat
	fn_log "neutron net-create public --shared --provider:physical_network public   --provider:network_type flat"
else
	log_info "public net is exist."
fi

SUB_PUBLIC_NET=`neutron subnet-list | grep public |wc -l `
if [ ${SUB_PUBLIC_NET}  -eq 0 ]
then
	neutron subnet-create public ${NEUTRON_PUBLIC_NET} --name public   --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END}   --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}
	fn_log "neutron subnet-create public ${NEUTRON_PUBLIC_NET} --name public   --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END}   --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}"
else
	log_info "sub_public is exist."
fi
source /root/demo-openrc.sh
PRIVATE_NET=`neutron net-list | grep private |wc -l`
if [ ${PRIVATE_NET}  -eq 0 ]
then
	neutron net-create private
	fn_log "neutron net-create private"
else
	log_info "private net is exist."
fi
SUB_PRIVATE_NET=`neutron subnet-list | grep private |wc -l`
if [ ${SUB_PRIVATE_NET}  -eq 0 ]
then
	neutron subnet-create private ${NEUTRON_PRIVATE_NET} --name private   --dns-nameserver ${PRIVATE_NET_DNS} --gateway ${PRIVATE_NET_GW}
	fn_log "neutron subnet-create private ${NEUTRON_PRIVATE_NET} --name private   --dns-nameserver ${PRIVATE_NET_DNS} --gateway ${PRIVATE_NET_GW}"
else
	log_info "private subnet is exist."
fi
source /root/admin-openrc.sh
ROUTE_VALUE=`neutron net-show public | grep router:external | awk -F " "  '{print$4}'`
if [ ${ROUTE_VALUE}x  = Truex  ]
then
	log_info "the value had changed."
else
	neutron net-update public --router:external
	fn_log "neutron net-update public --router:external"
fi
source /root/demo-openrc.sh
ROUTE_NU=`neutron router-list | grep router | wc -l`
if [ ${ROUTE_NU}  -eq 0 ]
then
	neutron router-create router
	fn_log "neutron router-create router"
	neutron router-interface-add router private
	fn_log "neutron router-interface-add router private"
	neutron router-gateway-set router public
	fn_log "neutron router-gateway-set router public"
else
	log_info "router had created."
fi

source /root/admin-openrc.sh
ip netns
fn_log "ip netns"
neutron router-port-list router
fn_log "neutron router-port-list router"
systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "

systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server
fn_log "systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server"

if  [ ! -d /etc/openstack-liberty_tag ]
then 
	mkdir -p /etc/openstack-liberty_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-liberty_tag/install_neutron.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  Install Neutron Sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

















