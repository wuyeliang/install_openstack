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
if [ -f  /etc/openstack-mitaka_tag/install_nova.tag ]
then 
	log_info "nova have installed ."
else
	echo -e "\033[41;37m you should install nova first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-mitaka_tag/install_cinder.tag ]
then 
	echo -e "\033[41;37m you had install cinder \033[0m"
	log_info "you had install cinder."	
	exit
fi

#create cinder databases 
function  fn_create_cinder_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE cinder;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create cinder databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASECINDER=`cat test | grep cinder`
rm -rf test 
if [ ${DATABASECINDER}x = cinderx ]
then
	log_info "cinder database had installed."
else
	fn_create_cinder_database
fi
source /root/admin-openrc.sh


USER_CINDER=`openstack user list | grep cinder | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_CINDER}x = cinderx ]
then
	log_info "openstack user had created  cinder"
else
	openstack user create  --domain default   cinder --password ${ALL_PASSWORD}
	fn_log "openstack user create cinder --password ${ALL_PASSWORD}"
	openstack role add --project service --user cinder admin
	fn_log "openstack role add --project service --user cinder admin"
fi

SERVICE_CINDER=`openstack service list | grep cinderv2 | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_CINDER}x = cinderv2x ]
then 
	log_info "openstack service create cinder and cinderv2."
else
	openstack service create --name cinder --description "OpenStack Block Storage" volume && openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	fn_log "openstack service create --name cinder --description "OpenStack Block Storage" volume && openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep volume  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep volume   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep volume   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 0  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  0   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 0  ]
then
	openstack endpoint create --region RegionOne   volume public http://${NAMEHOST}:8776/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volume internal http://${NAMEHOST}:8776/v1/%\(tenant_id\)s  && openstack endpoint create --region RegionOne   volume admin http://${NAMEHOST}:8776/v1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   volume public http://${NAMEHOST}:8776/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volume internal http://${NAMEHOST}:8776/v1/%\(tenant_id\)s  && openstack endpoint create --region RegionOne   volume admin http://${NAMEHOST}:8776/v1/%\(tenant_id\)s"
else
	log_info "openstack endpoint create cinder."
fi


ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep volumev2  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep volumev2   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep volumev2   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 0 ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  0   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 0  ]
then
	openstack endpoint create --region RegionOne   volumev2 public http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 internal http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 admin http://${NAMEHOST}:8776/v2/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   volumev2 public http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 internal http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 admin http://${NAMEHOST}:8776/v2/%\(tenant_id\)s"
else
	log_info "openstack endpoint create cinderv2."
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
				  
yum clean all &&  yum install openstack-cinder -y
fn_log "yum clean all &&  yum install openstack-cinder -y"


[ -f /etc/cinder/cinder.conf_bak  ] || cp -a  /etc/cinder/cinder.conf  /etc/cinder/cinder.conf_bak 
fn_log "[ -f /etc/cinder/cinder.conf_bak  ] || cp -a  /etc/cinder/cinder.conf  /etc/cinder/cinder.conf_bak "

unset http_proxy https_proxy ftp_proxy no_proxy

FIRST_ETH_IP=${MANAGER_IP}

openstack-config --set /etc/cinder/cinder.conf  database connection  mysql+pymysql://cinder:${ALL_PASSWORD}@${NAMEHOST}/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit &&  openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken memcached_servers  ${NAMEHOST}:11211 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_type   password && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_name   default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_name   default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  ${ALL_PASSWORD} &&  openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lib/cinder/tmp && openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${MANAGER_IP}
fn_log "configurer /etc/cinder/cinder.conf "


su -s /bin/sh -c "cinder-manage db sync" cinder 
fn_log "su -s /bin/sh -c "cinder-manage db sync" cinder"

openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne
fn_log "openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne"
systemctl restart openstack-nova-api.service
fn_log "systemctl restart openstack-nova-api.service"
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service   
fn_log "systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service   "

#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null "
}


#for storage service 
if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi
yum clean all &&  yum install   lvm2 -y
fn_log "yum clean all &&  yum install   lvm2 -y"

systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service"




function fn_create_cinder_volumes () {
if [  -z  ${CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
	return 1
else
	pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}
	fn_log "pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}"
fi
yum clean all &&  yum install openstack-cinder targetcli   -y
fn_log "yum clean all &&  yum install openstack-cinder targetcli -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && \
openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && \
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && \
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${NAMEHOST}  && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm && \
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_api_servers  http://${NAMEHOST}:9292
fn_log "openstack-config --set /etc/cinder/cinder.conf  "

systemctl enable openstack-cinder-volume.service target.service &&  systemctl restart openstack-cinder-volume.service target.service 
fn_log "systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service "
}



VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes had created."
else
	fn_create_cinder_volumes
fi
	

                    






source /root/admin-openrc.sh && cinder service-list

sleep 30
CINDER_STATUS=`source /root/admin-openrc.sh && cinder service-list | awk -F "|" '{print$6}' | grep -v State  | grep -v ^$ | grep -i down`

if [  -z  ${CINDER_STATUS} ]
then
	log_info "cinder status is ok."
	echo -e "\033[32m cinder status is ok \033[0m"
else
	log_error "cinder status is down."
	echo -e "\033[41;37m cinder service-list result is down. \033[0m"
	exit
fi


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install Cinder Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_cinder.tag





