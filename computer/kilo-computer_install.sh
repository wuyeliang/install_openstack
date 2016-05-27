#！/bin/bash
#log function
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
if [ -f  /etc/openstack-kilo_tag/computer.tag ]
then 
	echo -e "\033[41;37m you haved install computer \033[0m"
	log_info "you haved install computer."	
	exit
fi
read -p "the IP address of the instance tunnels network interface on your network node :" TUNNELS_IP
read -p "management interface IP address of the controller node :" MANAGER_IP
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`

yum clean all && yum install openstack-selinux -y 
fn_log "yum clean all && yum install openstack-selinux -y "


yum clean all &&  yum install openstack-nova-compute sysfsutils -y
fn_log "yum clean all &&  yum install openstack-nova-compute sysfsutils -y"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"

[ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak && openstack-config --set /etc/nova/nova.conf   DEFAULT  rpc_backend  rabbit && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_host  controller && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_userid  openstack && openstack-config --set /etc/nova/nova.conf   oslo_messaging_rabbit  rabbit_password  Changeme_123 && openstack-config --set /etc/nova/nova.conf DEFAULT  auth_strategy  keystone && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_uri  http://controller:5000 && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_url  http://controller:35357 && openstack-config --set /etc/nova/nova.conf keystone_authtoken  auth_plugin  password && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_domain_id  default && openstack-config --set /etc/nova/nova.conf keystone_authtoken  user_domain_id  default && openstack-config --set /etc/nova/nova.conf keystone_authtoken  project_name  service && openstack-config --set /etc/nova/nova.conf keystone_authtoken  username  nova && openstack-config --set /etc/nova/nova.conf keystone_authtoken  password Changeme_123 && openstack-config --set /etc/nova/nova.conf DEFAULT  my_ip  ${FIRST_ETH_IP} && openstack-config --set /etc/nova/nova.conf DEFAULT  vnc_enabled  True && openstack-config --set /etc/nova/nova.conf DEFAULT  vncserver_listen  0.0.0.0 && openstack-config --set /etc/nova/nova.conf DEFAULT  vncserver_proxyclient_address  ${FIRST_ETH_IP} && openstack-config --set /etc/nova/nova.conf DEFAULT  novncproxy_base_url  http://${MANAGER_IP}:6080/vnc_auto.html && openstack-config --set /etc/nova/nova.conf DEFAULT  verbose  True && openstack-config --set /etc/nova/nova.conf glance  host  controller && openstack-config --set /etc/nova/nova.conf oslo_concurrency  lock_path  /var/lib/nova/tmp
fn_log "config /etc/nova/nova.conf "

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





function fn_set_sysctl () {
echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >>/etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables" >>/etc/sysctl.conf
sysctl -p >>/dev/null
}


SYSCT=`cat /etc/sysctl.conf | grep net.ipv4.conf.all.rp_filter |awk -F "=" '{print$1}'`
if [ ${SYSCT}x = net.ipv4.conf.default.rp_filterx ]
then
	log_info "/etc/sysctl.conf had config."
else
	fn_set_sysctl
fi
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y 
fn_log "yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y "


[ -f  /etc/neutron/neutron.conf_bak ]  ||  cp -a /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak   && \
sed -i '/^connection/d' /etc/neutron/neutron.conf  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit  && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  controller   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack   && \
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  Changeme_123   && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://controller:5000  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://controller:35357  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron  && \
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  Changeme_123  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True  && \
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True
fn_log "config /etc/neutron/neutron.conf "



[ -f  /etc/neutron/plugins/ml2/ml2_conf.ini_bak ]  ||  cp -a /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2 type_drivers  flat,vlan,gre,vxlan   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  tenant_network_types  gre   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  mechanism_drivers  openvswitch   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2_type_gre tunnel_id_ranges  1:1000   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip  ${TUNNELS_IP}   && \
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre
fn_log "/etc/neutron/plugins/ml2/ml2_conf.ini"
systemctl enable openvswitch.service && systemctl start openvswitch.service
fn_log "systemctl enable openvswitch.service && systemctl start openvswitch.service"



openstack-config --set  /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API && \
openstack-config --set  /etc/nova/nova.conf DEFAULT security_group_api  neutron && \
openstack-config --set  /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver && \
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver && \
openstack-config --set  /etc/nova/nova.conf neutron url  http://controller:9696 && \
openstack-config --set  /etc/nova/nova.conf neutron auth_strategy  keystone && \
openstack-config --set  /etc/nova/nova.conf neutron admin_auth_url  http://controller:35357/v2.0 && \
openstack-config --set  /etc/nova/nova.conf neutron admin_tenant_name  service && \
openstack-config --set  /etc/nova/nova.conf neutron admin_username  neutron && \
openstack-config --set  /etc/nova/nova.conf neutron admin_password  Changeme_123
fn_log "config /etc/nova/nova.conf"
rm -rf /etc/neutron/plugin.ini &&  ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fn_log "rm -rf /etc/neutron/plugin.ini &&  ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"
rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig

fn_log "rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig"


sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service
fn_log "sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service"
systemctl restart openstack-nova-compute.service && systemctl enable neutron-openvswitch-agent.service && systemctl start neutron-openvswitch-agent.service
fn_log "systemctl restart openstack-nova-compute.service && systemctl enable neutron-openvswitch-agent.service && systemctl start neutron-openvswitch-agent.service"


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       install computer sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/computer.tag
    
	
	
























