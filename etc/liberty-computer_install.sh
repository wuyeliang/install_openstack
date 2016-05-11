#!/bin/bash
#log function
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

if [  -e /etc/openstack-liberty_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script oncontroller.  \033[0m"
	log_error "Oh no ! you can't execute this script oncontroller. "
	exit 1
fi
if [ -f  /etc/openstack-liberty_tag/computer.tag ]
then 
	echo -e "\033[41;37m you had installed computer \033[0m"
	log_info "you had installed computer."	
	exit
fi
read -p "please input the local host network interface name [eg:eth2]:" DEV_NETWORK
if [ -z  ${DEV_NETWORK}   ]
then
	echo -e "\033[41;37m please input the local host network interface name [eg:eth2]. \033[0m"
	exit 1
fi

yum clean all && yum install openstack-selinux python-openstackclient -y 
fn_log "yum clean all && yum install openstack-selinux -y "


yum clean all &&  yum install openstack-nova-compute sysfsutils -y
fn_log "yum clean all &&  yum install openstack-nova-compute sysfsutils -y"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"

COMPUTER_MANAGER_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`

[ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak && openstack-config --set /etc/nova/nova.conf   DEFAULT  rpc_backend  rabbit && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_host  ${HOST_NAME} && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_userid  openstack && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_password  ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  auth_strategy  keystone  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_uri  http://${HOST_NAME}:5000  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_url  http://${HOST_NAME}:35357  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_plugin  password && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_domain_id  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  user_domain_id  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_name  service  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  username  nova  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  password ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  my_ip  ${COMPUTER_MANAGER_IP} && openstack-config --set /etc/nova/nova.conf DEFAULT  network_api_class  nova.network.neutronv2.api.API && openstack-config --set /etc/nova/nova.conf DEFAULT  security_group_api  neutron && openstack-config --set /etc/nova/nova.conf DEFAULT  linuxnet_interface_driver  nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver && openstack-config --set /etc/nova/nova.conf DEFAULT  firewall_driver  nova.virt.firewall.NoopFirewallDriver && openstack-config --set /etc/nova/nova.conf DEFAULT  verbose  True && openstack-config --set /etc/nova/nova.conf vnc   enabled  True   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_listen  0.0.0.0   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_proxyclient_address  ${COMPUTER_MANAGER_IP}  &&  openstack-config --set /etc/nova/nova.conf vnc   novncproxy_base_url  http://${MANAGER_IP}:6080/vnc_auto.html  &&  openstack-config --set /etc/nova/nova.conf glance  host  ${HOST_NAME} && openstack-config --set /etc/nova/nova.conf oslo_concurrency  lock_path  /var/lib/nova/tmp
fn_log "openstack-config --set /etc/nova/nova.conf   DEFAULT  rpc_backend  rabbit && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_host  ${HOST_NAME} && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_userid  openstack && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_password  ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  auth_strategy  keystone  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_uri  http://${HOST_NAME}:5000  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_url  http://${HOST_NAME}:35357  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_plugin  password && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_domain_id  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  user_domain_id  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_name  service  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  username  nova  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  password ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  my_ip  ${COMPUTER_MANAGER_IP} && openstack-config --set /etc/nova/nova.conf DEFAULT  network_api_class  nova.network.neutronv2.api.API && openstack-config --set /etc/nova/nova.conf DEFAULT  security_group_api  neutron && openstack-config --set /etc/nova/nova.conf DEFAULT  linuxnet_interface_driver  nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver && openstack-config --set /etc/nova/nova.conf DEFAULT  firewall_driver  nova.virt.firewall.NoopFirewallDriver && openstack-config --set /etc/nova/nova.conf DEFAULT  verbose  True && openstack-config --set /etc/nova/nova.conf vnc   enabled  True   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_listen  0.0.0.0   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_proxyclient_address  $my_ip  &&  openstack-config --set /etc/nova/nova.conf vnc   novncproxy_base_url  http://${MANAGER_IP}:6080/vnc_auto.html  &&  openstack-config --set /etc/nova/nova.conf glance  host  ${HOST_NAME} && openstack-config --set /etc/nova/nova.conf oslo_concurrency  lock_path  /var/lib/nova/tmp"

HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi

systemctl enable libvirtd.service openstack-nova-compute.service  && systemctl start libvirtd.service openstack-nova-compute.service
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service  && systemctl start libvirtd.service openstack-nova-compute.service"

cat <<END >/root/admin-openrc.sh 
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_AUTH_URL=http://${HOST_NAME}:35357/v3
export OS_IDENTITY_API_VERSION=3 
export OS_PASSWORD=${ALL_PASSWORD}
END

cat <<END >/root/demo-openrc.sh  
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_AUTH_URL=http://${HOST_NAME}:5000/v3
export OS_IDENTITY_API_VERSION=3 
export OS_PASSWORD=${ALL_PASSWORD}
END

source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
sleep 20
nova service-list
fn_log "nova service-list"
nova endpoints
fn_log "nova endpoints"
nova image-list
fn_log "nova image-list"

yum install openstack-neutron openstack-neutron-linuxbridge ebtables ipset -y
fn_log "yum install openstack-neutron openstack-neutron-linuxbridge ebtables ipset -y"


[ -f  /etc/neutron/neutron.conf_bak ]  ||  cp -a /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak   && \
sed -i '/^connection/d' /etc/neutron/neutron.conf  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit  && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${HOST_NAME}   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}   && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${HOST_NAME}:5000  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${HOST_NAME}:35357  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  ${ALL_PASSWORD}  && \
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency  lock_path  /var/lib/neutron/tmp  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True 
fn_log "config /etc/neutron/neutron.conf "




[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  linux_bridge physical_interface_mappings  public:${DEV_NETWORK} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  enable_vxlan  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  local_ip  ${COMPUTER_MANAGER_IP} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan l2_population  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent  prevent_arp_spoofing  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver && \
fn_log "config /etc/neutron/plugins/ml2/linuxbridge_agent.ini"




openstack-config --set  /etc/nova/nova.conf neutron url  http://${HOST_NAME}:9696 && \
openstack-config --set  /etc/nova/nova.conf neutron auth_url  http://${HOST_NAME}:35357 && \
openstack-config --set  /etc/nova/nova.conf neutron auth_plugin  password && \
openstack-config --set  /etc/nova/nova.conf neutron project_domain_id  default && \
openstack-config --set  /etc/nova/nova.conf neutron user_domain_id  default && \
openstack-config --set  /etc/nova/nova.conf neutron region_name  RegionOne && \
openstack-config --set  /etc/nova/nova.conf neutron project_name  service && \
openstack-config --set  /etc/nova/nova.conf neutron username  neutron && \
openstack-config --set  /etc/nova/nova.conf neutron password  ${ALL_PASSWORD}
fn_log "config /etc/nova/nova.conf"



systemctl restart openstack-nova-compute.service 
fn_log "systemctl restart openstack-nova-compute.service "
systemctl enable neutron-linuxbridge-agent.service && systemctl start neutron-linuxbridge-agent.service
fn_log "systemctl enable neutron-linuxbridge-agent.service && systemctl start neutron-linuxbridge-agent.service"

source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
sleep 20
neutron ext-list
fn_log "neutron ext-list"
neutron agent-list
fn_log "neutron agent-list"


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       Install Computer Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack-liberty_tag ]
then 
	mkdir -p /etc/openstack-liberty_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-liberty_tag/computer.tag
    
	
	
























