#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
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

if [  -e /etc/openstack-ocata_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-ocata_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-ocata_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi
unset http_proxy https_proxy ftp_proxy no_proxy 
#create nova databases 
fn_create_database nova_api ${ALL_PASSWORD}
fn_create_database nova ${ALL_PASSWORD}
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" '
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" '


fn_create_database nova_placement ${ALL_PASSWORD}
fn_log "fn_create_database nova_placement ${ALL_PASSWORD}"
fn_create_database nova_cell0 ${ALL_PASSWORD}
fn_log "fn_create_database nova_cell0 ${ALL_PASSWORD}"

mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" '
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" '

mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'nova'@'localhost'  IDENTIFIED BY '${ALL_PASSWORD}';" '
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log 'mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" '










fn_create_user nova ${ALL_PASSWORD}
fn_log "fn_create_user nova ${ALL_PASSWORD}"

openstack role add --project service --user nova admin
fn_log "openstack role add --project service --user nova admin"

fn_create_service nova "OpenStack Compute" compute
fn_log "fn_create_service nova "OpenStack Compute" compute"

fn_create_endpoint_version compute 8774 v2.1
fn_log "fn_create_endpoint_version compute 8774 v2.1"


#fix bug PlacementNotConfigured: This compute is not configured to talk to the placement service
yum -y install openstack-nova-placement-api
fn_log "yum -y install openstack-nova-placement-api"
fn_create_service placement "OpenStack Placement" placement
fn_log "fn_create_service placement "OpenStack Placement" placement"

fn_create_user placement ${ALL_PASSWORD}
fn_log "fn_create_user placement ${ALL_PASSWORD}"
openstack role add --project service --user placement admin
fn_log "openstack role add --project service --user placement admin"

fn_create_endpoint placement 8778
fn_log "fn_create_endpoint placement 8778"








#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi

				    
yum clean all && yum -y install openstack-nova-api openstack-nova-conductor   openstack-nova-console openstack-nova-novncproxy   openstack-nova-scheduler
fn_log  "yum clean all && yum -y install openstack-nova-api openstack-nova-conductor   openstack-nova-console openstack-nova-novncproxy   openstack-nova-scheduler"
unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=${MANAGER_IP}


cat <<END >/tmp/tmp
DEFAULT enabled_apis   osapi_compute,metadata
api_database connection   mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_api
database connection   mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${HOSTNAME}
api auth_strategy   keystone
keystone_authtoken auth_uri   http://${HOSTNAME}:5000
keystone_authtoken auth_url   http://${HOSTNAME}:35357
keystone_authtoken memcached_servers   ${HOSTNAME}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   nova
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${FIRST_ETH_IP}
DEFAULT use_neutron   True
DEFAULT firewall_driver   nova.virt.firewall.NoopFirewallDriver
vnc enabled   true
vnc  vncserver_listen   \$my_ip
vnc  vncserver_proxyclient_address   \$my_ip
glance api_servers   http://${HOSTNAME}:9292
oslo_concurrency lock_path   /var/lib/nova/tmp
scheduler discover_hosts_in_cells_interval   30
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"




su -s /bin/sh -c "nova-manage api_db sync" nova
fn_log "su -s /bin/sh -c "nova-manage api_db sync" nova"

su -s /bin/sh -c "nova-manage db sync" nova
fn_log "su -s /bin/sh -c "nova-manage db sync" nova"

su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0 --database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_cell0"
fn_log "su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0 --database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_cell0""




function fn_sync_create_cell () {
su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1 \
--database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova \
--transport-url rabbit://openstack:${ALL_PASSWORD}@${HOSTNAME}:5672"

fn_log "su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1 \
--database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova \
--transport-url rabbit://openstack:${ALL_PASSWORD}@${HOSTNAME}:5672""
}

nova-manage cell_v2 list_cells --verbose  | grep -v UUID | grep -v  none  | grep mysql+pymysql  >/dev/null
if [ $? -eq 0 ]
then
    log_info "cell1 have been sync."
else
    fn_sync_create_cell
fi



 su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
 fn_log " su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts""


systemctl enable openstack-nova-api.service   openstack-nova-consoleauth.service openstack-nova-scheduler.service   openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl enable openstack-nova-api.service   openstack-nova-consoleauth.service openstack-nova-scheduler.service   openstack-nova-conductor.service openstack-nova-novncproxy.service"


systemctl start openstack-nova-api.service   openstack-nova-consoleauth.service openstack-nova-scheduler.service   openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl start openstack-nova-api.service   openstack-nova-consoleauth.service openstack-nova-scheduler.service   openstack-nova-conductor.service openstack-nova-novncproxy.service"



#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi

yum clean all && yum install openstack-nova-compute -y
fn_log "yum clean all && yum install openstack-nova-compute -y"

unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH_IP=${MANAGER_IP}


#for computer node
function fn_computer_service () {
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
DEFAULT enabled_apis   osapi_compute,metadata
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${HOSTNAME}
api auth_strategy   keystone
keystone_authtoken auth_uri   http://${HOST_NAME}:5000
keystone_authtoken auth_url   http://${HOST_NAME}:35357
keystone_authtoken memcached_servers   ${HOST_NAME}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   nova
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT my_ip   ${FIRST_ETH_IP}
DEFAULT use_neutron   True
DEFAULT firewall_driver   nova.virt.firewall.NoopFirewallDriver
vnc enabled   True
vnc vncserver_listen   0.0.0.0
vnc vncserver_proxyclient_address   \$my_ip
vnc novncproxy_base_url   http://${MANAGER_IP}:6080/vnc_auto.html
glance api_servers   http://${HOST_NAME}:9292
oslo_concurrency lock_path   /var/lib/nova/tmp
libvirt cpu_mode  none
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"

#fix bug PlacementNotConfigured: This compute is not configured to talk to the placement service

cat <<END >/tmp/tmp
placement auth_uri  http://${MANAGER_IP}:5000
placement auth_url  http://${MANAGER_IP}:35357
placement memcached_servers  ${MANAGER_IP}:11211
placement auth_type  password
placement project_domain_name  default
placement user_domain_name  default
placement project_name  service
placement username  placement
placement password  ${ALL_PASSWORD}
placement os_region_name  RegionOne
placement_database connection  mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_placement
wsgi api_paste_config  /etc/nova/api-paste.ini
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/nova/nova.conf
fn_log "fn_set_conf /etc/nova/nova.conf"

cat ${TOPDIR}/lib/00-nova-placement-api.conf >  /etc/httpd/conf.d/00-nova-placement-api.conf
fn_log "cat ${TOPDIR}/lib/00-nova-placement-api.conf >  /etc/httpd/conf.d/00-nova-placement-api.conf"
systemctl restart openstack-nova-compute.service

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

systemctl restart  openstack-nova-compute.service
fn_log "systemctl restart  openstack-nova-compute.service"

service libvirtd restart
fn_log "service libvirtd restart"


systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "
su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
fn_log "su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts""
}

if [  ${CONTROLLER_COMPUTER}  = True   ]
then
	fn_computer_service 
	fn_log "fn_computer_service "
	echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/computer_neutron.tag
elif [ ${CONTROLLER_COMPUTER}  = False ]
then
	log_info "Do not install openstack-nova-compute on controller. "
else
	echo -e "\033[41;37m please check  CONTROLLER_COMPUTER option in installrc . \033[0m"
	exit 1
fi


su -s /bin/sh -c "nova-manage api_db sync" nova
fn_log "su -s /bin/sh -c "nova-manage api_db sync" nova"

su -s /bin/sh -c "nova-manage db sync" nova
fn_log "su -s /bin/sh -c "nova-manage db sync" nova"

su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0 --database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_cell0"
fn_log "su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0 --database_connection mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_cell0""

su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
fn_log "su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts""



source /root/admin-openrc.sh
openstack compute service list
fn_log "openstack compute service list"

openstack catalog list
fn_log "openstack catalog list"


openstack image list
fn_log "openstack image list"


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install Nova Sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_nova.tag




