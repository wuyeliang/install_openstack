yum clean all && yum install  -y install  openstack-utils openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch
fn_log "yum clean all && yum install  -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch"

cat <<END >/tmp/tmp
DEFAULT core_plugin  ml2
DEFAULT service_plugins  router
DEFAULT auth_strategy  keystone
DEFAULT state_path  /var/lib/neutron
DEFAULT allow_overlapping_ips  True
DEFAULT transport_url  rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
keystone_authtoken auth_uri  http://${MANAGER_IP}:5000
keystone_authtoken auth_url  http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers  ${MANAGER_IP}:11211
keystone_authtoken auth_type  password
keystone_authtoken project_domain_name  default
keystone_authtoken user_domain_name  default
keystone_authtoken project_name  service
keystone_authtoken username  neutron
keystone_authtoken password  ${ALL_PASSWORD}
oslo_concurrency lock_path  $state_path/lock
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/neutron/neutron.conf
fn_log "fn_set_conf /etc/neutron/neutron.conf"
chmod 640 /etc/neutron/neutron.conf
fn_log "chmod 640 /etc/neutron/neutron.conf" 
chgrp neutron /etc/neutron/neutron.conf 
fn_log "chgrp neutron /etc/neutron/neutron.conf "



cat <<END >/tmp/tmp
ml2 type_drivers = flat,vlan,gre,vxlan
ml2 tenant_network_types =
ml2 mechanism_drivers = openvswitch,l2population
ml2 extension_drivers = port_security
securitygroup enable_security_group = True
securitygroup  firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
END
fn_log "create /tmp/tmp "


fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"



cat <<END >/tmp/tmp
DEFAULT use_neutron   True
DEFAULT linuxnet_interface_driver   nova.network.linux_net.LinuxOVSInterfaceDriver
DEFAULT firewall_driver   nova.virt.firewall.NoopFirewallDriver
DEFAULT vif_plugging_is_fatal   True
DEFAULT vif_plugging_timeout   300
neutron url   http://${MANAGER_IP}:9696
neutron auth_url   http://${MANAGER_IP}:35357
neutron auth_type   password
neutron project_domain_name   default
neutron user_domain_name   default
neutron region_name   RegionOne
neutron project_name   service
neutron username   neutron
neutron password    ${ALL_PASSWORD}
neutron service_metadata_proxy   True
neutron  metadata_proxy_shared_secret   metadata_secret
END
fn_log "create /tmp/tmp "
fn_set_conf  /etc/nova/nova.conf
fn_log "fn_set_conf  /etc/nova/nova.conf"





rm -f /etc/neutron/plugin.ini  && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini 
fn_log "rm -f /etc/neutron/plugin.ini  && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini "
systemctl start openvswitch 
fn_log "systemctl start openvswitch "
systemctl enable openvswitch
fn_log "systemctl enable openvswitch" 





systemctl restart openstack-nova-compute  
systemctl start neutron-openvswitch-agent 
systemctl enable neutron-openvswitch-agent 


NET_INT=`ip add | grep br-int | wc -l `
if [ ${NET_INT} -eq 0  ] 
then
	ovs-vsctl add-br br-int 
	fn_log "ovs-vsctl add-br br-int"
fi




systemctl restart openstack-nova-compute  
fn_log "systemctl restart openstack-nova-compute  "
systemctl start neutron-openvswitch-agent
fn_log "systemctl start neutron-openvswitch-agent" 
systemctl enable neutron-openvswitch-agent
fn_log "systemctl enable neutron-openvswitch-agent"




if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/computer_neutron.tag
echo -e "\033[32m ############################################### \033[0m"
echo -e "\033[32m ##  Install Neutron(network) Sucessed.     #### \033[0m"
echo -e "\033[32m ############################################### \033[0m"

