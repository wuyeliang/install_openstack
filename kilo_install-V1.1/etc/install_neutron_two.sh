#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ sucessed."
	echo -e "\033[32m $@ sucessed. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}
if [ -f  /etc/openstack-kilo_tag/install_cinder.tag ]
then 
	log_info "cinder have installed ."
else
	echo -e "\033[41;37m you should install cinder first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit
fi
#create neutron databases 
function  fn_create_neutron_database () {
mysql -uroot -pChangeme_123 -e "CREATE DATABASE neutron;" &&  mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'Changeme_123';" && mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'Changeme_123';" 
fn_log "create  database neutron"
}
mysql -uroot -pChangeme_123 -e "show databases ;" >test 
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
	openstack user create neutron  --password Changeme_123
	fn_log "openstack user create neutron  --password Changeme_123"
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
ENDPOINT_NEUTRON=`openstack endpoint  list | grep neutron | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`
if [ ${ENDPOINT_NEUTRON}x = neutronx ]
then
	log_info "openstack endpoint create neutron."
else
	openstack endpoint create --publicurl http://${NAMEHOST}:9696 --adminurl http://${NAMEHOST}:9696 --internalurl http://${NAMEHOST}:9696 --region RegionOne network
	fn_log "openstack endpoint create --publicurl http://${NAMEHOST}:9696 --adminurl http://${NAMEHOST}:9696 --internalurl http://${NAMEHOST}:9696 --region RegionOne network" "openstack endpoint create --publicurl http://${HOSTNAME}:9292 --internalurl http://${HOSTNAME}:9292 --adminurl http://${HOSTNAME}:9292 --region RegionOne image"
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
yum clean all && yum install openstack-neutron openstack-neutron-ml2 python-neutronclient  which  -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2 python-neutronclient  which  -y"
unset http_proxy https_proxy ftp_proxy no_proxy 
[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak 
openstack-config --set  /etc/neutron/neutron.conf database connection  mysql://neutron:Changeme_123@${NAMEHOST}/neutron &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST} &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack &&   \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  Changeme_123 &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service &&  \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron &&  \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  Changeme_123 &&  \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2 &&  \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router &&  \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True &&  \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True &&  \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT nova_url  http://${NAMEHOST}:8774/v2 &&   \
openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${NAMEHOST}:35357 &&   \
openstack-config --set  /etc/neutron/neutron.conf nova auth_plugin  password &&   \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password &&   \
openstack-config --set  /etc/neutron/neutron.conf nova project_domain_id  default &&   \
openstack-config --set  /etc/neutron/neutron.conf nova user_domain_id  default &&   \
openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne &&   \
openstack-config --set  /etc/neutron/neutron.conf nova project_name  service &&   \
openstack-config --set  /etc/neutron/neutron.conf nova username  nova &&   \
openstack-config --set  /etc/neutron/neutron.conf nova password  Changeme_123 &&   \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True 
fn_log "config /etc/neutron/neutron.conf"
[ -f /etc/neutron/plugins/ml2/ml2_conf.ini_bak  ] || cp -a  /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,gre,vxlan && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  openvswitch && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000 && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 

fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini"
rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

fn_log "ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
fn_log "su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron"
systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service  
fn_log "systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service "
systemctl enable neutron-server.service &&  systemctl start neutron-server.service 
fn_log "systemctl enable neutron-server.service &&  systemctl start neutron-server.service "
source /root/admin-openrc.sh
neutron ext-list
fn_log "neutron ext-list"

sysctl -p 


#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}

source $PWD/lib/neutron_net_config

if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi
yum clean all && yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y"

FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`


[ -f /etc/neutron/plugins/ml2/ml2_conf.ini_bak-1  ] || cp -a  /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak-1  
 openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  external && \
 openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip  ${FIRST_ETH_IP} && \
 openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings  external:br-ex && \
 openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre
fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini"
[ -f /etc/neutron/l3_agent.ini_bak ] || cp -a  /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini_bak
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver && \
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT external_network_bridge  &&  \
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces  True  && \
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT  verbose   True
fn_log "config /etc/neutron/l3_agent.ini" 


[ -f /etc/neutron/dhcp_agent.ini_bak ] || cp -a /etc/neutron/dhcp_agent.ini  /etc/neutron/dhcp_agent.ini_bak  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver  &&  \
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq  && \
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces  True  && \
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT verbose  True   && \
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file  /etc/neutron/dnsmasq-neutron.conf
fn_log "config /etc/neutron/dhcp_agent.ini"



echo "dhcp-option-force=26,1454" >/etc/neutron/dnsmasq-neutron.conf

pkill dnsmasq
[ -f /etc/neutron/metadata_agent.ini_bak-2 ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak-2 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_uri  http://${NAMEHOST}:5000 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_url  http://${NAMEHOST}:35357 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_region  RegionOne && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_plugin  password && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_domain_id  default && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT user_domain_id  default && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_name  service && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT username  neutron && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT password  Changeme_123 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT nova_metadata_ip  ${NAMEHOST} && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT metadata_proxy_shared_secret  Changeme_123 && \
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
fn_log "config /etc/neutron/metadata_agent.ini"


openstack-config --set  /etc/nova/nova.conf  neutron service_metadata_proxy  True && \
openstack-config --set  /etc/nova/nova.conf  neutron metadata_proxy_shared_secret  Changeme_123
fn_log "config /etc/nova/nova.conf"




systemctl restart openstack-nova-api.service &&  systemctl enable openvswitch.service && systemctl start openvswitch.service
fn_log "systemctl restart openstack-nova-api.service &&  systemctl enable openvswitch.service && systemctl start openvswitch.service"

SECONF_ETH=`ip addr | grep ^3: |awk -F ":" '{print$2}' | awk -F " " '{print$1}'`
SECONF_ETH_MAC=`ifconfig ${SECONF_ETH} | grep ether | awk -F " " '{print$2}'`



nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} 
fn_log "nmcli connection modify ${SECONF_ETH} ipv4.addresses "${SECOND_NET}" && nmcli connection modify ${SECONF_ETH} ipv4.method manual && nmcli connection up  ${SECONF_ETH} "


function fn_create_br () {
ovs-vsctl add-br br-ex
fn_log "ovs-vsctl add-br br-ex"
SECONF_ETH=`ip addr | grep ^3: |awk -F ":" '{print$2}' | awk -F " " '{print$1}'`
ovs-vsctl add-port br-ex ${SECONF_ETH}  &&  ethtool -K ${SECONF_ETH} gro off
fn_log "ovs-vsctl add-port br-ex ${SECONF_ETH}  &&  ethtool -K ${SECONF_ETH} gro off"
}

BR_NAME=`ovs-vsctl show | grep 'Bridge br-ex' | awk -F " " '{print$2}'`
if [ ${BR_NAME}x = br-exx ]
then
	log_info "bridge br-ex had create."
else
	fn_create_br
fi

	



rm -rf /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig && \
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
/usr/lib/systemd/system/neutron-openvswitch-agent.service
fn_log "modify /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig"


systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && \
systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service \
neutron-dhcp-agent.service neutron-metadata-agent.service 
if [  $? -eq 0  ]
then
	log_info "systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service sucessed."
	echo -e "\033[32m systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service sucessed. \033[0m"
else
	log_error "systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service failed."
	exit
fi
fn_log "systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service."

source /root/admin-openrc.sh
neutron agent-list
function fn_set_sysctl () {
echo "net.bridge.bridge-nf-call-ip6tables=1" >>/etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >>/etc/sysctl.conf
sysctl -p >>/dev/null
}

SYSCT=`cat /etc/sysctl.conf | grep net.ipv4.conf.default.rp_filter |awk -F "=" '{print$1}'`
if [ ${SYSCT}x = net.ipv4.conf.default.rp_filterx ]
then
	log_info "/etc/sysctl.conf had config."
else
	fn_set_sysctl
fi

#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null   "
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi

yum clean all && yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y"
unset http_proxy https_proxy ftp_proxy no_proxy
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ovs local_ip  ${FIRST_ETH_IP} && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  agent tunnel_types  gre

fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini"



systemctl enable openvswitch.service && systemctl start openvswitch.service 
fn_log "systemctl enable openvswitch.service && systemctl start openvswitch.service "




openstack-config --set  /etc/nova/nova.conf  DEFAULT network_api_class  nova.network.neutronv2.api.API && \
openstack-config --set  /etc/nova/nova.conf  DEFAULT security_group_api  neutron && \
openstack-config --set  /etc/nova/nova.conf  DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver && \
openstack-config --set  /etc/nova/nova.conf  DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver && \
openstack-config --set  /etc/nova/nova.conf  neutron url  http://${NAMEHOST}:9696 && \
openstack-config --set  /etc/nova/nova.conf  neutron auth_strategy  keystone && \
openstack-config --set  /etc/nova/nova.conf  neutron admin_auth_url  http://${NAMEHOST}:35357/v2.0 && \
openstack-config --set  /etc/nova/nova.conf  neutron admin_tenant_name  service && \
openstack-config --set  /etc/nova/nova.conf  neutron admin_username  neutron && \
openstack-config --set  /etc/nova/nova.conf  neutron admin_password  Changeme_123

fn_log "config /etc/nova/nova.conf"

systemctl restart openstack-nova-compute.service && \
systemctl enable neutron-openvswitch-agent.service && \
systemctl start neutron-openvswitch-agent.service  

fn_log "systemctl restart openstack-nova-compute.service && systemctl enable neutron-openvswitch-agent.service && systemctl start neutron-openvswitch-agent.service"
unset http_proxy https_proxy ftp_proxy no_proxy
source /root/admin-openrc.sh
neutron agent-list

EXT_NET=`neutron net-list | grep ext-net | awk -F " " '{print$4}'`
if [ ${EXT_NET}x = ext-netx  ]
then
	log_info "ext-net had created."
else
	neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat
	fn_log "neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat"
fi
EXT_SUB=`neutron subnet-list|grep ext-subnet | awk -F " " '{print$4}'`
if [ ${EXT_SUB}x  = ext-subnetx ]
then 
	log_info "ext-subnet had created."
else
	neutron subnet-create ext-net ${NEUTRON_EXT_NET} --name ext-subnet --allocation-pool start=${EXT_NET_START},end=${EXT_NET_END}  --disable-dhcp --gateway ${EXT_NET_GW}
	fn_log "neutron subnet-create ext-net ${NEUTRON_EXT_NET} --name ext-subnet --allocation-pool start=${EXT_NET_START},end=${EXT_NET_END}  --disable-dhcp --gateway ${EXT_NET_GW}"
fi

DEMO_NET=`neutron net-list | grep demo-net | awk -F " " '{print$4}'`
if [ ${DEMO_NET}x = demo-netx ]
then
	log_info "demo-net had created."
else
	source /root/demo-openrc.sh && neutron net-create demo-net
	fn_log "source /root/demo-openrc.sh && \neutron net-create demo-net"
fi


DEMO_SUB=`neutron subnet-list|grep demo-subnet | awk -F " " '{print$4}'`
if [ ${DEMO_SUB}x = demo-subnetx ]
then
	log_info "demo-subnet had created."
else
	source /root/demo-openrc.sh && neutron subnet-create demo-net ${NEUTRON_DEMO_NET} --name demo-subnet --gateway ${DEMO_NET_GW}
	fn_log "source /root/demo-openrc.sh && neutron subnet-create demo-net ${NEUTRON_DEMO_NET} --name demo-subnet --gateway ${DEMO_NET_GW}"
fi









ROUTE_ID=`neutron router-list | grep demo-router | awk -F " " '{print$4}'`
if [ ${ROUTE_ID}x  = demo-routerx ]
then
	log_info "demo-router had create."
else
	neutron router-create demo-router
	fn_log "neutron router-create demo-router"
fi





source /root/demo-openrc.sh 
ROUTR_PORT=`neutron router-port-list  demo-router |grep  ip_address  |awk -F "\"" '{print$6}' | awk -F " " '{print$1}'`
if [  ${ROUTR_PORT}x  = ip_addressx ]
then 
	log_info "subnet had add to router."
else
	neutron router-interface-add demo-router demo-subnet && neutron router-gateway-set demo-router ext-net
	fn_log "neutron router-interface-add demo-router demo-subnet && neutron router-gateway-set demo-router ext-net"
fi





RC_FILE=`cat /etc/rc.d/rc.local  | grep ^ip\ addr | awk -F " " '{print$6}'`
if [ ${RC_FILE}x = br-exx ]
then
	log_info "rc.local had config"
else
	echo " " >>/etc/rc.d/rc.local 
	echo "ip link set br-ex up" >>/etc/rc.d/rc.local 
	echo "ip addr add ${BR_EX_NET} dev br-ex" >>/etc/rc.d/rc.local 
	chmod +x /etc/rc.d/rc.local
fi
ip link set br-ex up
ip addr add ${BR_EX_NET} dev br-ex

systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"
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
	nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0  && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
	fn_log "nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0  && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0"
fi
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_neutron.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  install neutron sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

















