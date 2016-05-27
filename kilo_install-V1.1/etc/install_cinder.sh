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
if [ -f  /etc/openstack-kilo_tag/install_nova.tag ]
then 
	log_info "nova have installed ."
else
	echo -e "\033[41;37m you should install nova first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_cinder.tag ]
then 
	echo -e "\033[41;37m you had install cinder \033[0m"
	log_info "you had install cinder."	
	exit
fi

#create cinder databases 
function  fn_create_cinder_database () {
mysql -uroot -pChangeme_123 -e "CREATE DATABASE cinder;" &&  mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'Changeme_123';" && mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'Changeme_123';" 
fn_log "create cinder databases"
}
mysql -uroot -pChangeme_123 -e "show databases ;" >test 
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
	openstack user create cinder --password Changeme_123
	fn_log "openstack user create cinder --password Changeme_123"
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

ENDPOINT_CINDER=`openstack endpoint  list | grep cinderv2 | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`
if [ ${ENDPOINT_CINDER}x = cinderv2x ]
then
	log_info "openstack endpoint create cinder and cinderv2 ."
else 
	openstack endpoint create --publicurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --region RegionOne volume  && openstack endpoint create --publicurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --region RegionOne volumev2
	fn_log "openstack endpoint create --publicurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --region RegionOne volume && openstack endpoint create --publicurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --internalurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --adminurl http://${NAMEHOST}:8776/v2/%\(tenant_id\)s --region RegionOne volumev2"
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

yum clean all &&  yum install openstack-cinder python-cinderclient python-oslo-db -y
fn_log "yum clean all &&  yum install openstack-cinder python-cinderclient python-oslo-db -y"
rm -rf /etc/cinder/cinder.conf  && cp /usr/share/cinder/cinder-dist.conf /etc/cinder/cinder.conf && chown -R cinder:cinder /etc/cinder/cinder.conf

fn_log "rm -rf /etc/cinder/cinder.conf  && cp /usr/share/cinder/cinder-dist.conf /etc/cinder/cinder.conf && chown -R cinder:cinder /etc/cinder/cinder.conf"
unset http_proxy https_proxy ftp_proxy no_proxy

FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`



openstack-config --set /etc/cinder/cinder.conf  database connection  mysql://cinder:Changeme_123@${NAMEHOST}/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit &&  openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  Changeme_123 && openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_plugin  password && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  Changeme_123 &&  openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${FIRST_ETH_IP} && openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True 
fn_log "openstack-config --set /etc/cinder/cinder.conf  database connection  mysql://cinder:Changeme_123@${NAMEHOST}/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit &&  openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  Changeme_123 && openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_plugin  password && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  Changeme_123 &&  openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${FIRST_ETH_IP} && openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True "


su -s /bin/sh -c "cinder-manage db sync" cinder 
fn_log "su -s /bin/sh -c "cinder-manage db sync" cinder"


systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service   
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



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi
yum clean all &&  yum install qemu  lvm2 -y
fn_log "yum clean all &&  yum install qemu  lvm2 -y"

systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service
fn_log "systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service"

CINDER_DISK=`cat  $PWD/lib/cinder_disk | grep ^CINDER_DISK | awk -F "=" '{print$2}'`


function fn_create_cinder_volumes () {
if [  -z  ${CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
else
	pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}
	fn_log "pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}"
fi

}



VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes had created."
else
	fn_create_cinder_volumes
fi
	


yum clean all &&  yum install openstack-cinder targetcli python-oslo-db python-oslo-log  MySQL-python  -y
fn_log "yum clean all &&  yum install openstack-cinder targetcli python-oslo-db python-oslo-log  MySQL-python  -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${NAMEHOST}  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm
fn_log "openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${NAMEHOST}  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm"

systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service 
fn_log "systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service "


VERSION_VOLUME=`cat /root/admin-openrc.sh | grep OS_VOLUME_API_VERSION | awk -F " " '{print$2}' | awk -F "=" '{print$1}'`
if [ ${VERSION_VOLUME}x = OS_VOLUME_API_VERSIONx  ]
then
	log_info "admin-openrc.sh have add VERSION_VOLUME."
else
	echo " " >>/root/admin-openrc.sh  && echo " " >>/root/demo-openrc.sh  && echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/admin-openrc.sh /root/demo-openrc.sh 
	fn_log "echo " " >>/root/admin-openrc.sh  && echo " " >>/root/demo-openrc.sh  && echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/admin-openrc.sh /root/demo-openrc.sh "
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
	echo -e "\033[41;37m cinder status is down. \033[0m"
	exit
fi
[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder && chown cinder:cinder /var/lock/cinder  -R
echo " " >>/etc/rc.d/rc.local 
echo "[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder " >>/etc/rc.d/rc.local 
echo "chown cinder:cinder /var/lock/cinder  -R" >>/etc/rc.d/rc.local 
chmod +x /etc/rc.d/rc.local


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install cinder sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_cinder.tag





