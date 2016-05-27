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

if [  -e /etc/openstack-mitaka_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script oncontroller.  \033[0m"
	log_error "Oh no ! you can't execute this script oncontroller. "
	exit 1
fi
if [ -f  /etc/openstack-mitaka_tag/computer.tag ]
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

yum clean all && yum install openstack-selinux python-openstackclient yum-plugin-priorities -y 
fn_log "yum clean all && yum install openstack-selinux -y "


yum clean all &&  yum install openstack-nova-compute -y
fn_log "yum clean all &&  yum install openstack-nova-compute sysfsutils -y"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"

COMPUTER_MANAGER_IP=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`

[ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak && [ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak && openstack-config --set /etc/nova/nova.conf   DEFAULT  rpc_backend  rabbit && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_host  ${HOST_NAME} && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_userid  openstack && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_password  ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  auth_strategy  keystone  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_uri  http://${HOST_NAME}:5000  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_url  http://${HOST_NAME}:35357  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  memcached_servers  ${HOST_NAME}:11211  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_type  password && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_domain_name  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  user_domain_name  default  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_name  service  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  username  nova  && openstack-config --set /etc/nova/nova.conf keystone_authtoken  password ${ALL_PASSWORD} && openstack-config --set /etc/nova/nova.conf DEFAULT  my_ip  ${COMPUTER_MANAGER_IP} && openstack-config --set /etc/nova/nova.conf DEFAULT  use_neutron  True && openstack-config --set /etc/nova/nova.conf DEFAULT  firewall_driver  nova.virt.firewall.NoopFirewallDriver && openstack-config --set /etc/nova/nova.conf vnc   enabled  True   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_listen  0.0.0.0   && openstack-config --set /etc/nova/nova.conf vnc   vncserver_proxyclient_address  ${COMPUTER_MANAGER_IP}  &&  openstack-config --set /etc/nova/nova.conf vnc   novncproxy_base_url  http://${MANAGER_IP}:6080/vnc_auto.html  &&  openstack-config --set /etc/nova/nova.conf glance  api_servers  http://${HOST_NAME}:9292 && openstack-config --set /etc/nova/nova.conf oslo_concurrency  lock_path  /var/lib/nova/tmp 
fn_log "openstack-config --set /etc/nova/nova.conf "

HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
	openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False 
	fn_log "openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False "
	openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0
	fn_log "openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0"
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
	openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False 
	fn_log "openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False "
	openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0
	fn_log "openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0"
fi

systemctl enable libvirtd.service openstack-nova-compute.service  && systemctl start libvirtd.service openstack-nova-compute.service
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service  && systemctl start libvirtd.service openstack-nova-compute.service"

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
fn_log "source /root/admin-openrc.sh"
sleep 20
openstack compute service list
fn_log "openstack compute service list"

yum clean all && yum install openstack-neutron-linuxbridge ebtables ipset -y
fn_log "yum clean all && yum install openstack-neutron-linuxbridge ebtables ipset -y"



[ -f  /etc/neutron/neutron.conf_bak ]  ||  cp -a /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak   && \
sed -i '/^connection/d' /etc/neutron/neutron.conf  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit  && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${HOST_NAME}   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}   && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${HOST_NAME}:5000  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${HOST_NAME}:35357  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken  memcached_servers  ${HOST_NAME}:11211  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_type  password  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_name   default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_name  default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  ${ALL_PASSWORD}  && \
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency  lock_path  /var/lib/neutron/tmp  
fn_log "config /etc/neutron/neutron.conf "




[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  linux_bridge physical_interface_mappings  provider:${DEV_NETWORK} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  enable_vxlan  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  local_ip  ${COMPUTER_MANAGER_IP} && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan l2_population  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True && \
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
fn_log "config /etc/neutron/plugins/ml2/linuxbridge_agent.ini"




openstack-config --set  /etc/nova/nova.conf neutron url  http://${HOST_NAME}:9696 && \
openstack-config --set  /etc/nova/nova.conf neutron auth_url  http://${HOST_NAME}:35357 && \
openstack-config --set  /etc/nova/nova.conf neutron auth_type  password && \
openstack-config --set  /etc/nova/nova.conf neutron project_domain_name  default && \
openstack-config --set  /etc/nova/nova.conf neutron user_domain_name  default && \
openstack-config --set  /etc/nova/nova.conf neutron region_name  RegionOne && \
openstack-config --set  /etc/nova/nova.conf neutron project_name  service && \
openstack-config --set  /etc/nova/nova.conf neutron username  neutron && \
openstack-config --set  /etc/nova/nova.conf neutron password  ${ALL_PASSWORD}
fn_log "config /etc/nova/nova.conf"





systemctl restart openstack-nova-compute.service 
fn_log "systemctl restart openstack-nova-compute.service "
systemctl enable neutron-linuxbridge-agent.service && systemctl start neutron-linuxbridge-agent.service
fn_log "systemctl enable neutron-linuxbridge-agent.service && systemctl start neutron-linuxbridge-agent.service"

#for ceilometer
function fn_install_ceilometer () {
yum clean all && yum install openstack-ceilometer-compute python-ceilometerclient python-pecan -y
fn_log "yum clean all && yum install openstack-ceilometer-compute python-ceilometerclient python-pecan -y"
[ -f /etc/ceilometer/ceilometer.conf_bak ] || cp -a /etc/ceilometer/ceilometer.conf /etc/ceilometer/ceilometer.conf_bak
openstack-config --set  /etc/ceilometer/ceilometer.conf database connection  mongodb://ceilometer:${ALL_PASSWORD}@${HOSTNAME}:27017/ceilometer
openstack-config --set  /etc/ceilometer/ceilometer.conf DEFAULT  rpc_backend  rabbit
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_host  ${HOST_NAME}
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid  openstack
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
openstack-config --set  /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy  keystone
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri  http://${HOST_NAME}:5000
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url  http://${HOST_NAME}:35357
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken memcached_servers  ${HOST_NAME}:11211
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_name  default
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken project_name  service
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken username  ceilometer
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken  password  ${ALL_PASSWORD}
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials os_auth_url  http://${HOST_NAME}:5000/v2.0
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials os_username  ceilometer
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name  service
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials os_password  ${ALL_PASSWORD}
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials interface  internalURL
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials region_name  RegionOne
fn_log  "configure  /etc/ceilometer/ceilometer.conf"
openstack-config --set  /etc/nova/nova.conf DEFAULT  instance_usage_audit  True && \
openstack-config --set  /etc/nova/nova.conf DEFAULT  instance_usage_audit_period  hour && \
openstack-config --set  /etc/nova/nova.conf DEFAULT notify_on_state_change  vm_and_task_state && \
openstack-config --set  /etc/nova/nova.conf DEFAULT notification_driver  messagingv2
fn_log  "configure  /etc/nova/nova.conf"
systemctl enable openstack-ceilometer-compute.service && systemctl start openstack-ceilometer-compute.service
fn_log "systemctl enable openstack-ceilometer-compute.service && systemctl start openstack-ceilometer-compute.service"
}

source /root/admin-openrc.sh 
fn_log "source /root/admin-openrc.sh "


USER_ceilometer=`openstack user list | grep ceilometer | grep -v ceilometer_domain_admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_ceilometer}x = ceilometerx ]
then
	fn_install_ceilometer
	fn_log "fn_install_ceilometer"
else
	log_info "ceilometer had not installed."
fi

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

if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/computer.tag
    
	
	
























