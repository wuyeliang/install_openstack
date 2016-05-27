#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
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
if [  -e /etc/openstack-mitaka_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-mitaka_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-mitaka_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi
unset http_proxy https_proxy ftp_proxy no_proxy 
#create nova databases 
function  fn_create_nova_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE nova;" &&  \
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE nova_api;" && \
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && \
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${ALL_PASSWORD}';"  && \
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost'   IDENTIFIED BY '${ALL_PASSWORD}';" && \
mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create nova databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASENOVA=`cat test | grep nova_api`
rm -rf test 
if [ ${DATABASENOVA}x = nova_apix ]
then
	log_info "nova database had installed."
else
	fn_create_nova_database
fi


source /root/admin-openrc.sh 
USER_NOVA=`openstack user list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NOVA}x = novax ]
then
	log_info "openstack user had created  nova"
else
	openstack user create --domain default   nova  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default   nova  --password ${ALL_PASSWORD}"
	openstack role add --project service --user nova admin
	fn_log "openstack role add --project service --user nova admin"
fi



SERVICE_NOVA=`openstack service list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NOVA}x = novax ]
then 
	log_info "openstack service create nova."
else
	openstack service create --name nova --description "OpenStack Compute" compute
	fn_log "openstack service create --name nova --description "OpenStack Compute" compute"
fi


ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep compute  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep compute   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep compute   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create nova."
else
	openstack endpoint create --region RegionOne   compute public http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute internal http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute admin http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   compute public http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute internal http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute admin http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s"
fi






#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
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


yum clean all && yum install openstack-nova-api openstack-nova-cert   openstack-nova-conductor openstack-nova-console   openstack-nova-novncproxy openstack-nova-scheduler -y
fn_log  "yum clean all && yum install openstack-nova-api openstack-nova-cert   openstack-nova-conductor openstack-nova-console   openstack-nova-novncproxy openstack-nova-scheduler -y"
unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=${MANAGER_IP}
[ -f /etc/nova/nova.conf_bak ]  || cp -a /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata && \
openstack-config --set  /etc/nova/nova.conf database connection  mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova && \
openstack-config --set  /etc/nova/nova.conf api_database connection   mysql+pymysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova_api && \
openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit &&  \
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME}&& \
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   && \
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && \
openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone && \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken memcached_servers   ${HOSTNAME}:11211 &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_type   password &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_name   default &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_name   default &&    \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  ${ALL_PASSWORD} &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${FIRST_ETH_IP} &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT use_neutron True  &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver &&   \
openstack-config --set  /etc/nova/nova.conf vnc vncserver_listen  ${FIRST_ETH_IP}  &&   \
openstack-config --set  /etc/nova/nova.conf vnc vncserver_proxyclient_address   ${FIRST_ETH_IP} &&   \
openstack-config --set  /etc/nova/nova.conf glance api_servers  http://${HOSTNAME}:9292&&   \
openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp 
fn_log "config /etc/nova/nova.conf "


su -s /bin/sh -c "nova-manage api_db sync" nova
fn_log "su -s /bin/sh -c "nova-manage api_db sync" nova"
su -s /bin/sh -c "nova-manage db sync" nova
fn_log "su -s /bin/sh -c "nova-manage db sync" nova"


systemctl enable openstack-nova-api.service openstack-nova-cert.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl enable openstack-nova-api.service openstack-nova-cert.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"


systemctl restart openstack-nova-api.service openstack-nova-cert.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl start openstack-nova-api.service openstack-nova-cert.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"



#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
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


openstack-config --set  /etc/nova/nova.conf vnc vncserver_listen  0.0.0.0  &&   \
openstack-config --set  /etc/nova/nova.conf vnc enabled  True  &&   \
openstack-config --set  /etc/nova/nova.conf vnc novncproxy_base_url  http://${FIRST_ETH_IP}:6080/vnc_auto.html  
fn_log "config /etc/nova/nova.conf "

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "
}

if [  ${CONTROLLER_COMPUTER}  = True   ]
then
	fn_computer_service 
	fn_log "fn_computer_service "
elif [ ${CONTROLLER_COMPUTER}  = False ]
then
	log_info "Do not install openstack-nova-compute on controller. "
else
	echo -e "\033[41;37m please check  CONTROLLER_COMPUTER option in installrc . \033[0m"
	exit 1
fi


source /root/admin-openrc.sh
openstack compute service list
fn_log "openstack compute service list"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install Nova Sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_nova.tag




