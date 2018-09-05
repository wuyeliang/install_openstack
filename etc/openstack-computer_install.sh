#!/bin/bash
#log function
if [  -e $PWD/lib/openstack-log.sh ]
then	
	source $PWD/lib/openstack-log.sh
else
	echo -e "\033[41;37m $PWD/openstack-log.sh is not exist. \033[0m"
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


if [  -e /etc/openstack_tag/config_keystone.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script oncontroller.  \033[0m"
	log_error "Oh no ! you can't execute this script oncontroller. "
	exit 1
fi
if [ -f  /etc/openstack_tag/computer.tag ]
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

#for computer node
function fn_computer_service () {
yum clean all && yum install openstack-nova-compute -y
fn_log "yum clean all && yum install openstack-nova-compute -y"

FIRST_ETH_IP=${COMPUTER_MANAGER_IP}

HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi

cat <<END >/tmp/tmp
DEFAULT my_ip   ${COMPUTER_MANAGER_IP}
DEFAULT state_path   /var/lib/nova
DEFAULT enabled_apis   osapi_compute,metadata
DEFAULT log_dir   /var/log/nova
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
api auth_strategy   keystone
vnc enabled   True
vnc server_listen   0.0.0.0
vnc server_proxyclient_address   ${COMPUTER_MANAGER_IP}
vnc novncproxy_base_url   http://${MANAGER_IP}:6080/vnc_auto.html
glance api_servers   http://${MANAGER_IP}:9292
oslo_concurrency lock_path   /var/lib/nova/tmp
keystone_authtoken www_authenticate_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:5000
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   nova
keystone_authtoken password   ${ALL_PASSWORD}
placement auth_url   http://${MANAGER_IP}:5000
placement os_region_name   RegionOne
placement auth_type   password
placement project_domain_name   default
placement user_domain_name   default
placement project_name   service
placement username   placement
placement password   ${ALL_PASSWORD}
wsgi api_paste_config   /etc/nova/api-paste.ini
libvirt cpu_mode  none
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"


cat <<"END" >/tmp/tmp
DEFAULT resize_confirm_window  1
DEFAULT allow_resize_to_same_host True
DEFAULT scheduler_default_filters RetryFilter,AvailabilityZoneFilter,RamFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter
libvirt live_migration_flag   'VIR_MIGRATE_UNDEFINE_SOURCE, VIR_MIGRATE_PEER2PEER, VIR_MIGRATE_LIVE, VIR_MIGRATE_TUNNELLED,VIR_MIGRATE_UNSAFE'
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"



cat <<"END" >/etc/libvirt/qemu.conf
vnc_listen = "0.0.0.0"
user = "root"
group = "root"
dynamic_ownership = 1
END

fn_log "/etc/libvirt/qemu.conf"

cat <<"END" > /etc/libvirt/libvirtd.conf
listen_tls = 0
auth_tcp="none"
listen_tcp = 1
tcp_port = "16509"
listen_addr = "0.0.0.0"
END

fn_log "/etc/libvirt/libvirtd.conf"
cat <<"END" > /etc/sysconfig/libvirtd
LIBVIRTD_CONFIG=/etc/libvirt/libvirtd.conf
LIBVIRTD_ARGS="--listen"
END

fn_log "/etc/sysconfig/libvirtd"



systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "
#su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
#fn_log "su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova"
}


fn_computer_service 

function fn_neutron_computer_node () {
yum clean all && yum install openstack-neutron-linuxbridge ebtables ipset -y
fn_log "yum clean all && yum install openstack-neutron-linuxbridge ebtables ipset -y"
cat <<END >/tmp/tmp
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
DEFAULT auth_strategy   keystone
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   neutron
keystone_authtoken password   ${ALL_PASSWORD}
oslo_concurrency lock_path   /var/lib/neutron/tmp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/neutron.conf
fn_log "fn_set_conf /etc/neutron/neutron.conf"

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

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"

systemctl restart openstack-nova-compute.service
fn_log "systemctl restart openstack-nova-compute.service"


systemctl enable neutron-linuxbridge-agent.service
fn_log "systemctl enable neutron-linuxbridge-agent.service"
cat <<END >/tmp/tmp
linux_bridge physical_interface_mappings   provider:${DEV_NETWORK}
vxlan  enable_vxlan   true
vxlan local_ip   ${LOCAL_MANAGER_IP}
vxlan l2_population   true
securitygroup enable_security_group   true
securitygroup firewall_driver   neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/plugins/ml2/linuxbridge_agent.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/linuxbridge_agent.ini"

systemctl restart openstack-nova-compute.service
fn_log "systemctl restart openstack-nova-compute.service"

systemctl enable neutron-linuxbridge-agent.service
fn_log "systemctl enable neutron-linuxbridge-agent.service"
systemctl start neutron-linuxbridge-agent.service
fn_log "systemctl start neutron-linuxbridge-agent.service"


}

fn_neutron_computer_node


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


source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
sleep 10
openstack compute service list
fn_log "openstack compute service list"



#for ceilometer
function fn_install_ceilometer () {
yum clean all && yum install openstack-ceilometer-compute python-ceilometerclient python-pecan -y
fn_log "yum clean all && yum install openstack-ceilometer-compute python-ceilometerclient python-pecan -y"
[ -f /etc/ceilometer/ceilometer.conf_bak ] || cp -a /etc/ceilometer/ceilometer.conf /etc/ceilometer/ceilometer.conf_bak
openstack-config --set  /etc/ceilometer/ceilometer.conf database connection  mongodb://ceilometer:${ALL_PASSWORD}@${MANAGER_IP}:27017/ceilometer
openstack-config --set  /etc/ceilometer/ceilometer.conf DEFAULT  rpc_backend  rabbit
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_host  ${MANAGER_IP}
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid  openstack
openstack-config --set  /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
openstack-config --set  /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy  keystone
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri  http://${MANAGER_IP}:5000
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url  http://${MANAGER_IP}:35357
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken memcached_servers  ${MANAGER_IP}:11211
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken auth_type  password
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_name  default
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_name  default
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken project_name  service
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken username  ceilometer
openstack-config --set  /etc/ceilometer/ceilometer.conf keystone_authtoken  password  ${ALL_PASSWORD}
openstack-config --set  /etc/ceilometer/ceilometer.conf service_credentials os_auth_url  http://${MANAGER_IP}:5000/v2.0
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


if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/computer.tag








    
	
	
























