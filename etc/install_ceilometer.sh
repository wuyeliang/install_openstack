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

if [ -f  /etc/openstack-mitaka_tag/install_ceilometer.tag ]
then 
	echo -e "\033[41;37m you haved install ceilometer \033[0m"
	log_info "you haved install ceilometer."	
	exit
fi

yum clean all && yum install mongodb-server mongodb -y
fn_log "yum clean all && yum install mongodb-server mongodb -y"

LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`

rm -f /etc/mongod.conf
fn_log " rm -f /etc/mongod.conf"
cp -a  $PWD/lib/mongod.conf /etc/mongod.conf
fn_log "cp -a  $PWD/lib/mongod.conf /etc/mongod.conf"
sed -i "/^bind_ip/d" /etc/mongod.conf
fn_log "sed -i "/^bind_ip/d" /etc/mongod.conf"
sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf
fn_log "sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf"

systemctl enable mongod.service &&  systemctl restart mongod.service
fn_log "systemctl enable mongod.service &&  systemctl start mongod.service"


#create ceilometer databases 
#mongo --host ${HOSTNAME} >testceilometer 2>/dev/null <<EOF
#use admin ;
#db.system.users.find()
#exit
#EOF

cp -a  $PWD/lib/mongodb ./mongodb
sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb
fn_log "sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb"
sed -i "s/mitaka/${HOSTNAME}/g" ./mongodb
fn_log "sed -i "/mitaka/${HOSTNAME}" ./mongodb"
#if [ -e  testceilometer ]
#then
#	TEST_DB=`cat testceilometer  | grep ceilometer | wc -l `
#	fn_log "TEST_DB=`cat testceilometer`"
#	rm -f testceilometer
#	fn_log "rm -f testceilometer"
#fi
#if [ ${TEST_DB} -eq 1 ]
#then
#	log_info "celeilometer databases had created."
#else
#	bash -x  ./mongodb
#	log_info "bash -x  ./mongodb"
#	rm -f ./mongodb 
#fi


bash -x  ./mongodb
log_info "bash -x  ./mongodb"
rm -f ./mongodb 






unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
USER_ceilometer=`openstack user list | grep ceilometer | grep -v ceilometer_domain_admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_ceilometer}x = ceilometerx ]
then
	log_info "openstack user had created  ceilometer"
else
	openstack user create  --domain default ceilometer  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default ceilometer  --password ${ALL_PASSWORD}"
	openstack role add --project service --user ceilometer admin
	fn_log "openstack role add --project service --user ceilometer admin"
fi

SERVICE_IMAGE=`openstack service list | grep ceilometer | awk -F "|" '{print$3}' | awk -F " " '{print$1}' | grep -v  ceilometerv2`
if [  ${SERVICE_IMAGE}x = ceilometerx ]
then 
	log_info "openstack service create ceilometer."
else
	openstack service create --name ceilometer   --description "Telemetry" metering
	fn_log "openstack service create --name ceilometer   --description "Telemetry" metering"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep metering  |grep internal  | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep metering   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep metering  |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create ceilometer."
else
	openstack endpoint create --region RegionOne   metering public http://${HOSTNAME}:8777 && openstack endpoint create --region RegionOne   metering internal http://${HOSTNAME}:8777 && openstack endpoint create --region RegionOne   metering admin http://${HOSTNAME}:8777
	fn_log "openstack endpoint create --region RegionOne   metering public http://${HOSTNAME}:8777 && openstack endpoint create --region RegionOne   metering internal http://${HOSTNAME}:8777 && openstack endpoint create --region RegionOne   metering admin http://${HOSTNAME}:8777"
fi





#for controller
yum clean all &&  yum install openstack-ceilometer-api   openstack-ceilometer-collector openstack-ceilometer-notification   openstack-ceilometer-central python-ceilometerclient -y
fn_log "yum clean all &&  yum install openstack-ceilometer-api   openstack-ceilometer-collector openstack-ceilometer-notification   openstack-ceilometer-central python-ceilometerclient -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

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


systemctl enable openstack-ceilometer-api.service   openstack-ceilometer-notification.service   openstack-ceilometer-central.service   openstack-ceilometer-collector.service
fn_log "systemctl enable openstack-ceilometer-api.service   openstack-ceilometer-notification.service   openstack-ceilometer-central.service   openstack-ceilometer-collector.service"
systemctl restart openstack-ceilometer-api.service   openstack-ceilometer-notification.service   openstack-ceilometer-central.service   openstack-ceilometer-collector.service
fn_log "systemctl restart openstack-ceilometer-api.service   openstack-ceilometer-notification.service   openstack-ceilometer-central.service   openstack-ceilometer-collector.service"

#for glance 

openstack-config --set  /etc/glance/glance-api.conf   DEFAULT rpc_backend  rabbit && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_notifications driver  messagingv2 && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_host  ${HOSTNAME} && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
fn_log "openstack-config --set  /etc/glance/glance-api.conf   DEFAULT rpc_backend  rabbit && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_notifications driver  messagingv2 && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_host  ${HOSTNAME} && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set  /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}"
openstack-config --set  /etc/glance/glance-registry.conf   DEFAULT rpc_backend  rabbit && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_notifications driver  messagingv2 && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_host  ${HOSTNAME} && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
fn_log "openstack-config --set  /etc/glance/glance-registry.conf   DEFAULT rpc_backend  rabbit && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_notifications driver  messagingv2 && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_host  ${HOSTNAME} && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set  /etc/glance/glance-registry.conf  oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}"

systemctl restart openstack-glance-api.service openstack-glance-registry.service
fn_log "systemctl restart openstack-glance-api.service openstack-glance-registry.service"

#for computer node
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



if [ -e /etc/systemd/system/multi-user.target.wants/openstack-nova-compute.service ]
then
	systemctl restart openstack-nova-compute.service
	fn_log "systemctl restart openstack-nova-compute.service"
fi
#for cinder
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_notifications driver  messagingv2
fn_log "openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_notifications driver  messagingv2"
systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service 


if [ -e /etc/systemd/system/multi-user.target.wants/openstack-cinder-api.service  ]
then
	systemctl restart openstack-cinder-volume.service
	fn_log "systemctl restart openstack-cinder-volume.service"
fi


ResellerAdmin_role=`openstack role  list | grep ResellerAdmin | wc -l`
if [  ${ResellerAdmin_role} -eq 0 ]
then
	openstack role create ResellerAdmin
	fn_log "openstack role create ResellerAdmin"
	openstack role add --project service --user ceilometer ResellerAdmin
	fn_log "openstack role add --project service --user ceilometer ResellerAdmin"
fi

yum clean all &&  yum install python-ceilometermiddleware -y

#create aodh databases 
function  fn_create_aodh_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE aodh;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'localhost'   IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create aodh databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASEaodh=`cat test | grep aodh`
rm -rf test 
if [ ${DATABASEaodh}x = aodhx ]
then
	log_info "aodh database had installed."
else
	fn_create_aodh_database
fi

unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
USER_aodh=`openstack user list | grep aodh | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_aodh}x = aodhx ]
then
	log_info "openstack user had created  aodh"
else
	openstack user create  --domain default aodh  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default aodh  --password ${ALL_PASSWORD}"
	openstack role add --project service --user aodh admin
	fn_log "openstack role add --project service --user aodh admin"
fi

SERVICE_IMAGE=`openstack service list | grep alarming | awk -F "|" '{print$3}' | awk -F " " '{print$1}' `
if [  ${SERVICE_IMAGE}x = aodhx ]
then 
	log_info "openstack service create aodh."
else
	openstack service create --name aodh   --description "Telemetry" alarming
	fn_log "openstack service create --name aodh   --description "Telemetry" alarming"
fi


ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep alarming   |grep internal |grep -v aodhv2 | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep alarming   |grep -v aodhv2 |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep alarming   |grep -v aodhv2 |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create aodh."
else
	openstack endpoint create --region RegionOne   alarming public http://${HOSTNAME}:8042 &&   openstack endpoint create --region RegionOne   alarming internal http://${HOSTNAME}:8042 &&   openstack endpoint create --region RegionOne   alarming admin http://${HOSTNAME}:8042
	fn_log "openstack endpoint create --region RegionOne   alarming public http://${HOSTNAME}:8042 &&   openstack endpoint create --region RegionOne   alarming internal http://${HOSTNAME}:8042 &&   openstack endpoint create --region RegionOne   alarming admin http://${HOSTNAME}:8042"
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


yum clean all &&  yum install openstack-aodh-api   openstack-aodh-evaluator openstack-aodh-notifier   openstack-aodh-listener openstack-aodh-expirer   python-ceilometerclient -y
fn_log "yum clean all &&  yum install openstack-aodh-api   openstack-aodh-evaluator openstack-aodh-notifier   openstack-aodh-listener openstack-aodh-expirer   python-ceilometerclient -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

[ -f /etc/aodh/aodh.conf_bak ] || cp -a /etc/aodh/aodh.conf /etc/aodh/aodh.conf_bak
openstack-config --set  /etc/aodh/aodh.conf database connection    mysql+pymysql://aodh:${ALL_PASSWORD}@${HOSTNAME}/aodh  && \
openstack-config --set  /etc/aodh/aodh.conf DEFAULT rpc_backend  rabbit  && \
openstack-config --set  /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME} &&  \
openstack-config --set  /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_userid  openstack  &&  \
openstack-config --set  /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && \
openstack-config --set  /etc/aodh/aodh.conf DEFAULT auth_strategy  keystone &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken auth_type  password &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken project_domain_name  default &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken user_domain_name  default &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken project_name  service &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken username  aodh &&  \
openstack-config --set  /etc/aodh/aodh.conf keystone_authtoken  password  ${ALL_PASSWORD}   &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials os_auth_url  http://${HOSTNAME}:5000/v2.0 &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials os_username  aodh &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials os_tenant_name  service &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials os_password  ${ALL_PASSWORD}  &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials interface  internalURL &&  \
openstack-config --set  /etc/aodh/aodh.conf service_credentials region_name  RegionOne
fn_log   "configure /etc/aodh/aodh.conf"



systemctl enable openstack-aodh-api.service   openstack-aodh-evaluator.service   openstack-aodh-notifier.service   openstack-aodh-listener.service
fn_log "systemctl enable openstack-aodh-api.service   openstack-aodh-evaluator.service   openstack-aodh-notifier.service   openstack-aodh-listener.service"
systemctl restart openstack-aodh-api.service   openstack-aodh-evaluator.service   openstack-aodh-notifier.service   openstack-aodh-listener.service
fn_log "systemctl restart openstack-aodh-api.service   openstack-aodh-evaluator.service   openstack-aodh-notifier.service   openstack-aodh-listener.service"


function fn_reinstall_mongodb () {
LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
rpm -qa | grep mongodb | xargs  rpm -e --nodeps 
fn_log "rpm -qa | grep mongodb | xargs  rpm -e --nodeps"
rm -rf /var/lib/mongodb/
fn_log "rm -rf /var/lib/mongodb/"
yum install mongodb-server mongodb -y
fn_log "yum install mongodb-server mongodb -y"
systemctl enable mongod.service &&  systemctl restart mongod.service
rm -f /etc/mongod.conf
fn_log " rm -f /etc/mongod.conf"
cp -a  $PWD/lib/mongod.conf /etc/mongod.conf
fn_log "cp -a  $PWD/lib/mongod.conf /etc/mongod.conf"
sed -i "/^bind_ip/d" /etc/mongod.conf
fn_log "sed -i "/^bind_ip/d" /etc/mongod.conf"
sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf
fn_log "sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf"
cp -a  $PWD/lib/mongodb ./mongodb
sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb
fn_log "sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb"
sed -i "s/mitaka/${HOSTNAME}/g" ./mongodb
fn_log "sed -i "/mitaka/${HOSTNAME}" ./mongodb"
cat ./mongodb
bash -x  ./mongodb
log_info "bash -x  ./mongodb"
rm -f ./mongodb 
fn_log "rm -f ./mongodb "
}

# fn_reinstall_mongodb
rpm -qa | grep mongodb | xargs  rpm -e --nodeps 
fn_log "rpm -qa | grep mongodb | xargs  rpm -e --nodeps "
rm -rf /var/lib/mongodb/
fn_log "rm -rf /var/lib/mongodb/"
yum install mongodb-server mongodb -y
fn_log "yum install mongodb-server mongodb -y"
LOCAL_MANAGER_IP_ALL=`cat /etc/hosts | grep -v localhost | grep ${HOSTNAME} | awk -F " " '{print$1}'`
rm -rf  /etc/mongod.conf
fn_log "rm -rf  /etc/mongod.conf"
cp -a  $PWD/lib/mongod.conf /etc/mongod.conf
fn_log "cp -a  $PWD/lib/mongod.conf /etc/mongod.conf"
sed -i "/^bind_ip/d" /etc/mongod.conf
fn_log "sed -i "/^bind_ip/d" /etc/mongod.conf"
sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf
fn_log "sed -i "/^fork/a bind_ip\ =\ ${LOCAL_MANAGER_IP_ALL}" /etc/mongod.conf"
systemctl enable mongod.service &&  systemctl restart mongod.service
fn_log "systemctl enable mongod.service &&  systemctl restart mongod.service"
cp -a  $PWD/lib/mongodb ./mongodb
fn_log "cp -a  $PWD/lib/mongodb ./mongodb"
sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb
fn_log "sed -i "s/Changeme_123/${ALL_PASSWORD}/g" ./mongodb"
sed -i "s/mitaka/${HOSTNAME}/g" ./mongodb
fn_log "sed -i "/mitaka/${HOSTNAME}" ./mongodb"
cat ./mongodb
fn_log "cat ./mongodb"
bash -x  ./mongodb
fn_log "bash -x  ./mongodb"
rm -rf  ./mongodb
fn_log "rm -rf  ./mongodb"
source /root/admin-openrc.sh 
fn_log "source /root/admin-openrc.sh "


ceilometer meter-list
fn_log "ceilometer meter-list "
IMAGE_ID=$(glance image-list | grep 'cirros' | awk '{ print $2 }')
glance image-download $IMAGE_ID > /tmp/cirros.img
fn_log "glance image-download $IMAGE_ID > /tmp/cirros.img"
ceilometer meter-list
fn_log "ceilometer meter-list"
ceilometer statistics -m image.download -p 60
fn_log "ceilometer statistics -m image.download -p 60"
rm -f /tmp/cirros.img



echo -e "\033[32m #################################################### \033[0m"
echo -e "\033[32m ###        Install Ceilometer Sucessed          #### \033[0m"
echo -e "\033[32m #################################################### \033[0m"


if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_ceilometer.tag