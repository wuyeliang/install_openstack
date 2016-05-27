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
if [ -f  /etc/openstack-kilo_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-kilo_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi
unset http_proxy https_proxy ftp_proxy no_proxy 
#create nova databases 
function  fn_create_nova_database () {
mysql -uroot -pChangeme_123 -e "CREATE DATABASE nova;" &&  mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'Changeme_123';" && mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'Changeme_123';" 
fn_log "create nova databases"
}
mysql -uroot -pChangeme_123 -e "show databases ;" >test 
DATABASENOVA=`cat test | grep nova`
rm -rf test 
if [ ${DATABASENOVA}x = novax ]
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
	openstack user create  nova  --password Changeme_123
	fn_log "openstack user create  nova  --password Changeme_123"
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

ENDPOINT_NOVA=`openstack endpoint  list | grep nova | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`
if [ ${ENDPOINT_NOVA}x = novax ]
then
	log_info "openstack endpoint create nova."
else
	openstack endpoint create --publicurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --region RegionOne compute
	fn_log "openstack endpoint create --publicurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8774/v2/%\(tenant_id\)s --region RegionOne compute"
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

yum clean all && yum install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient -y
fn_log "yum clean all && yum install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient -y"
unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`
[ -f /etc/nova/nova.conf_bak ]  || cp -a /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set  /etc/nova/nova.conf database connection  mysql://nova:Changeme_123@${NAMEHOST}/nova && openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit &&  openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  Changeme_123 && openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_plugin  password && openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_id  default && openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_id  default &&  openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service && openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova && openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  Changeme_123 && openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_listen  ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address  ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT verbose  True && openstack-config --set  /etc/nova/nova.conf glance host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp && openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf  DEFAULT   vncserver_listen  0.0.0.0
fn_log "openstack-config --set  /etc/nova/nova.conf database connection  mysql://nova:Changeme_123@${NAMEHOST}/nova && openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit &&  openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  Changeme_123 && openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_plugin  password && openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_id  default && openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_id  default &&  openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service && openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova && openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  Changeme_123 && openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_listen  ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address  ${FIRST_ETH_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT verbose  True && openstack-config --set  /etc/nova/nova.conf glance host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp && openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf  DEFAULT   vncserver_listen  0.0.0.0"

su -s /bin/sh -c "nova-manage db sync" nova 
fn_log "su -s /bin/sh -c "nova-manage db sync" nova "
systemctl start  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  && systemctl enable  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  
fn_log "systemctl start  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  && systemctl enable  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  "
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

yum clean all && yum install openstack-nova-compute sysfsutils -y
fn_log "yum clean all && yum install openstack-nova-compute sysfsutils -y"

unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`
openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf DEFAULT novncproxy_base_url  http://${FIRST_ETH_IP}:6080/vnc_auto.html
fn_log "openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf DEFAULT novncproxy_base_url  http://${FIRST_ETH_IP}:6080/vnc_auto.html"




HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "


source /root/admin-openrc.sh
nova service-list 
NOVA_STATUS=`nova service-list | awk -F "|" '{print$7}'  | grep -v State | grep -v ^$ | grep down`
if [  -z ${NOVA_STATUS} ]
then
	echo "nova status is ok"
	log_info  "nova status is ok"
	echo -e "\033[32m nova status is ok \033[0m"
else
	echo "nova status is down"
	log_error "nova status is down."
	exit
fi
nova endpoints

fn_log "nova endpoints"
nova image-list
fn_log "nova image-list"
NOVA_IMAGE_STATUS=` nova image-list  | grep cirros-0.3.4-x86_64  | awk -F "|"  '{print$4}'`
if [ ${NOVA_IMAGE_STATUS}  = ACTIVE ]
then
	log_info  "nova image status is ok"
	echo -e "\033[32m nova image status is ok \033[0m"
else
	echo "nova image status is error."
	log_error "nova image status is error."
	exit
fi
chkconfig openstack-nova-consoleauth  on  && service  openstack-nova-consoleauth start
fn_log "chkconfig openstack-nova-consoleauth  on  && service  openstack-nova-consoleauth start"


fn_log "systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"
echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install nova sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_nova.tag




