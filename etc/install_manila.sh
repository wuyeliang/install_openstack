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

if [ -f  /etc/openstack-mitaka_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-mitaka_tag/install_manila.tag ]
then 
	echo -e "\033[41;37m you haved install manila \033[0m"
	log_info "you haved install manila."	
	exit
fi

#create manila databases 
function  fn_create_manila_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE manila;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'localhost'   IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create manila databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASEmanila=`cat test | grep manila`
rm -rf test 
if [ ${DATABASEmanila}x = manilax ]
then
	log_info "manila database had installed."
else
	fn_create_manila_database
fi

unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
USER_manila=`openstack user list | grep manila | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_manila}x = manilax ]
then
	log_info "openstack user had created  manila"
else
	openstack user create  --domain default manila  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default manila  --password ${ALL_PASSWORD}"
	openstack role add --project service --user manila admin
	fn_log "openstack role add --project service --user manila admin"
fi

SERVICE_IMAGE=`openstack service list | grep manila | awk -F "|" '{print$3}' | awk -F " " '{print$1}' | grep -v  manilav2`
if [  ${SERVICE_IMAGE}x = manilax ]
then 
	log_info "openstack service create manila."
else
	openstack service create --name manila --description "OpenStack Shared File Systems" share
	fn_log "openstack service create --name manila --description "OpenStack Shared File Systems" share"
fi
SERVICE_IMAGEV2=`openstack service list | grep sharev2 | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_IMAGEV2}x =  manilav2x ]
then
	log_info "openstack service create manilav2."
else
	openstack service create --name manilav2   --description "OpenStack Shared File Systems" sharev2
	fn_log "openstack service create --name manilav2   --description "OpenStack Shared File Systems" sharev2"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep share  |grep internal |grep -v manilav2 | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep share  |grep -v manilav2 |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep share  |grep -v manilav2 |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create manila."
else
	openstack endpoint create --region RegionOne   share public http://${NAMEHOST}:8786/v1/%\(tenant_id\)s && 	openstack endpoint create --region RegionOne   share internal http://${NAMEHOST}:8786/v1/%\(tenant_id\)s && 	openstack endpoint create --region RegionOne   share admin http://${NAMEHOST}:8786/v1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   share public http://${NAMEHOST}:8786/v1/%\(tenant_id\)s && 	openstack endpoint create --region RegionOne   share internal http://${NAMEHOST}:8786/v1/%\(tenant_id\)s && 	openstack endpoint create --region RegionOne   share admin http://${NAMEHOST}:8786/v1/%\(tenant_id\)s"
fi

ENDPOINT_LIST_INTERNAL_V2=`openstack endpoint list  | grep sharev2  |grep internal  | wc -l`
ENDPOINT_LIST_PUBLIC_V2=`openstack endpoint list | grep sharev2   |grep public | wc -l`
ENDPOINT_LIST_ADMIN_V2=`openstack endpoint list | grep sharev2   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL_V2}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC_V2}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN_V2} -eq 1  ]
then
	log_info "openstack endpoint create manilav2."
else
	openstack endpoint create --region RegionOne   sharev2 public http://${NAMEHOST}:8786/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   sharev2 internal http://${NAMEHOST}:8786/v2/%\(tenant_id\)s &&  openstack endpoint create --region RegionOne   sharev2 admin http://${NAMEHOST}:8786/v2/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   sharev2 public http://${NAMEHOST}:8786/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   sharev2 internal http://${NAMEHOST}:8786/v2/%\(tenant_id\)s &&  openstack endpoint create --region RegionOne   sharev2 admin http://${NAMEHOST}:8786/v2/%\(tenant_id\)s"
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
#for controller
yum clean all &&  yum install openstack-manila python-manilaclient -y
fn_log "yum clean all && yum install openstack-manila -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

[ -f /etc/manila/manila.conf_bak ] || cp -a /etc/manila/manila.conf /etc/manila/manila.conf_bak
openstack-config --set  /etc/manila/manila.conf database connection  mysql+pymysql://manila:${ALL_PASSWORD}@${HOSTNAME}/manila   && openstack-config --set  /etc/manila/manila.conf DEFAULT rpc_backend  rabbit  && openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME} &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_userid  openstack  &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && openstack-config --set  /etc/manila/manila.conf DEFAULT default_share_type  default_share_type &&  openstack-config --set  /etc/manila/manila.conf DEFAULT rootwrap_config  /etc/manila/rootwrap.conf &&  openstack-config --set  /etc/manila/manila.conf DEFAULT auth_strategy  keystone &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_type  password &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken user_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_name  service &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken username  manila &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken  password  ${ALL_PASSWORD} &&  openstack-config --set  /etc/manila/manila.conf DEFAULT my_ip  ${MANAGER_IP} &&  openstack-config --set  /etc/manila/manila.conf oslo_concurrency  lock_path  /var/lib/manila/tmp
fn_log  "openstack-config --set  /etc/manila/manila.conf database connection  mysql+pymysql://manila:${ALL_PASSWORD}@${HOSTNAME}/manila   && openstack-config --set  /etc/manila/manila.conf DEFAULT rpc_backend  rabbit  && openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME} &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_userid  openstack  &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && openstack-config --set  /etc/manila/manila.conf DEFAULT default_share_type  default_share_type &&  openstack-config --set  /etc/manila/manila.conf DEFAULT rootwrap_config  /etc/manila/rootwrap.conf &&  openstack-config --set  /etc/manila/manila.conf DEFAULT auth_strategy  keystone &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_type  password &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken user_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_name  service &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken username  manila &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken  password  ${ALL_PASSWORD} &&  openstack-config --set  /etc/manila/manila.conf DEFAULT my_ip  ${MANAGER_IP} &&  openstack-config --set  /etc/manila/manila.conf oslo_concurrency  lock_path  /var/lib/manila/tmp"


su -s /bin/sh -c "manila-manage db sync" manila
fn_log "su -s /bin/sh -c "manila-manage db sync" manila"

systemctl enable openstack-manila-api.service openstack-manila-scheduler.service  && systemctl start openstack-manila-api.service openstack-manila-scheduler.service
fn_log "systemctl enable openstack-manila-api.service openstack-manila-scheduler.service  && systemctl start openstack-manila-api.service openstack-manila-scheduler.service"




yum clean all &&  yum install openstack-manila-share python2-PyMySQL -y
fn_log "yum clean all && yum install openstack-manila-share python2-PyMySQL -y"
unset http_proxy https_proxy ftp_proxy no_proxy 


##for manila node

[ -f /etc/manila/manila.conf_bak ] || cp -a /etc/manila/manila.conf /etc/manila/manila.conf_bak
openstack-config --set  /etc/manila/manila.conf database connection  mysql+pymysql://manila:${ALL_PASSWORD}@${HOSTNAME}/manila   && openstack-config --set  /etc/manila/manila.conf DEFAULT rpc_backend  rabbit  && openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME} &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_userid  openstack  &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && openstack-config --set  /etc/manila/manila.conf DEFAULT default_share_type  default_share_type &&  openstack-config --set  /etc/manila/manila.conf DEFAULT rootwrap_config  /etc/manila/rootwrap.conf &&  openstack-config --set  /etc/manila/manila.conf DEFAULT auth_strategy  keystone &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_type  password &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken user_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_name  service &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken username  manila &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken  password  ${ALL_PASSWORD} &&  openstack-config --set  /etc/manila/manila.conf DEFAULT my_ip  ${MANAGER_IP} &&  openstack-config --set  /etc/manila/manila.conf oslo_concurrency  lock_path  /var/lib/manila/tmp
fn_log  "openstack-config --set  /etc/manila/manila.conf database connection  mysql+pymysql://manila:${ALL_PASSWORD}@${HOSTNAME}/manila   && openstack-config --set  /etc/manila/manila.conf DEFAULT rpc_backend  rabbit  && openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME} &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_userid  openstack  &&  openstack-config --set  /etc/manila/manila.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && openstack-config --set  /etc/manila/manila.conf DEFAULT default_share_type  default_share_type &&  openstack-config --set  /etc/manila/manila.conf DEFAULT rootwrap_config  /etc/manila/rootwrap.conf &&  openstack-config --set  /etc/manila/manila.conf DEFAULT auth_strategy  keystone &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken auth_type  password &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken user_domain_name  default &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken project_name  service &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken username  manila &&  openstack-config --set  /etc/manila/manila.conf keystone_authtoken  password  ${ALL_PASSWORD} &&  openstack-config --set  /etc/manila/manila.conf DEFAULT my_ip  ${MANAGER_IP} &&  openstack-config --set  /etc/manila/manila.conf oslo_concurrency  lock_path  /var/lib/manila/tmp"

function fn_driver_manila () {
yum clean all &&  yum install openstack-neutron openstack-neutron-linuxbridge ebtables -y
fn_log "yum clean all &&  yum install openstack-neutron openstack-neutron-linuxbridge ebtables -y"
openstack-config --set  /etc/manila/manila.conf DEFAULT enabled_share_backends  generic
openstack-config --set  /etc/manila/manila.conf DEFAULT enabled_share_protocols  NFS,CIFS
openstack-config --set  /etc/manila/manila.conf  neutron url  http://${HOSTNAME}:9696
openstack-config --set  /etc/manila/manila.conf  neutron auth_uri  http://${HOSTNAME}:5000
openstack-config --set  /etc/manila/manila.conf  neutron auth_url  http://${HOSTNAME}:35357
openstack-config --set  /etc/manila/manila.conf  neutron memcached_servers  ${HOSTNAME}:11211
openstack-config --set  /etc/manila/manila.conf  neutron auth_type  password
openstack-config --set  /etc/manila/manila.conf  neutron project_domain_name  default
openstack-config --set  /etc/manila/manila.conf  neutron user_domain_name  default
openstack-config --set  /etc/manila/manila.conf  neutron region_name  RegionOne
openstack-config --set  /etc/manila/manila.conf  neutron project_name  service
openstack-config --set  /etc/manila/manila.conf  neutron username  neutron
openstack-config --set  /etc/manila/manila.conf  neutron password  ${ALL_PASSWORD}
openstack-config --set  /etc/manila/manila.conf nova  auth_uri  http://${HOSTNAME}:5000
openstack-config --set  /etc/manila/manila.conf nova auth_url  http://${HOSTNAME}:35357
openstack-config --set  /etc/manila/manila.conf nova memcached_servers  ${HOSTNAME}:11211
openstack-config --set  /etc/manila/manila.conf nova auth_type  password
openstack-config --set  /etc/manila/manila.conf nova project_domain_name  default
openstack-config --set  /etc/manila/manila.conf nova  user_domain_name  default
openstack-config --set  /etc/manila/manila.conf nova region_name  RegionOne
openstack-config --set  /etc/manila/manila.conf nova project_name  service
openstack-config --set  /etc/manila/manila.conf nova username  nova
openstack-config --set  /etc/manila/manila.conf nova password  ${ALL_PASSWORD}
openstack-config --set  /etc/manila/manila.conf cinder auth_uri  http://${HOSTNAME}:5000
openstack-config --set  /etc/manila/manila.conf cinder auth_url  http://${HOSTNAME}:35357
openstack-config --set  /etc/manila/manila.conf cinder memcached_servers  ${HOSTNAME}:11211
openstack-config --set  /etc/manila/manila.conf cinder auth_type  password
openstack-config --set  /etc/manila/manila.conf cinder project_domain_name  default
openstack-config --set  /etc/manila/manila.conf cinder user_domain_name  default
openstack-config --set  /etc/manila/manila.conf cinder region_name  RegionOne
openstack-config --set  /etc/manila/manila.conf cinder project_name  service
openstack-config --set  /etc/manila/manila.conf cinder username  cinder
openstack-config --set  /etc/manila/manila.conf cinder password  ${ALL_PASSWORD}
openstack-config --set  /etc/manila/manila.conf generic  share_backend_name  GENERIC
openstack-config --set  /etc/manila/manila.conf generic share_backend_name  GENERIC
openstack-config --set  /etc/manila/manila.conf generic  share_driver  manila.share.drivers.generic.GenericShareDriver
openstack-config --set  /etc/manila/manila.conf generic driver_handles_share_servers  True
openstack-config --set  /etc/manila/manila.conf generic service_instance_flavor_id  100
openstack-config --set  /etc/manila/manila.conf generic service_image_name  manila-service-image
openstack-config --set  /etc/manila/manila.conf generic service_instance_user  manila
openstack-config --set  /etc/manila/manila.conf generic service_instance_password  manila
openstack-config --set  /etc/manila/manila.conf generic interface_driver  manila.network.linux.interface.BridgeInterfaceDriver
}

function fn_no_driver_manila () {
yum clean all &&   yum install lvm2 nfs-utils nfs4-acl-tools portmap -y
fn_log "yum clean all &&   yum install lvm2 nfs-utils nfs4-acl-tools portmap -y"
systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service && systemctl start lvm2-lvmetad.service"


VOLUNE_NAME=`vgs | grep manila-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = manila-volumesx ]
then
	log_info "manila-volumes had created."
else
	pvcreate ${MANILA_DISK}  && vgcreate manila-volumes ${MANILA_DISK}
	fn_log "pvcreate ${MANILA_DISK}  && vgcreate manila-volumes ${MANILA_DISK}"
fi

LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
openstack-config --set  /etc/manila/manila.conf  DEFAULT enabled_share_backends  lvm
openstack-config --set  /etc/manila/manila.conf  DEFAULT enabled_share_protocols  NFS,CIFS
openstack-config --set  /etc/manila/manila.conf  lvm share_backend_name  LVM
openstack-config --set  /etc/manila/manila.conf  lvm share_driver  manila.share.drivers.lvm.LVMShareDriver
openstack-config --set  /etc/manila/manila.conf  lvm driver_handles_share_servers  False
openstack-config --set  /etc/manila/manila.conf  lvm lvm_share_volume_group  manila-volumes
openstack-config --set  /etc/manila/manila.conf  lvm lvm_share_export_ip  ${LOCAL_MANAGER_IP_ALL}
}

if [  -z  ${MANILA_DISK} ]
then 
	fn_driver_manila
	fn_log "fn_driver_manila"
else
	fn_no_driver_manila
	fn_log "fn_no_driver_manila"
fi
systemctl enable openstack-manila-share.service &&  systemctl start openstack-manila-share.service
fn_log "systemctl enable openstack-manila-share.service &&  systemctl start openstack-manila-share.service"




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
manila service-list
fn_log "manila service-list"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Manila Sucessed          #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_manila.tag