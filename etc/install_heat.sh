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

if [ -f  /etc/openstack-mitaka_tag/install_heat.tag ]
then 
	echo -e "\033[41;37m you haved install heat \033[0m"
	log_info "you haved install heat."	
	exit
fi

#create heat databases 
function  fn_create_heat_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE heat;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost'   IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%'   IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create heat databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASEheat=`cat test | grep heat`
rm -rf test 
if [ ${DATABASEheat}x = heatx ]
then
	log_info "heat database had installed."
else
	fn_create_heat_database
fi

unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
USER_heat=`openstack user list | grep heat | grep -v heat_domain_admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_heat}x = heatx ]
then
	log_info "openstack user had created  heat"
else
	openstack user create  --domain default heat  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default heat  --password ${ALL_PASSWORD}"
	openstack role add --project service --user heat admin
	fn_log "openstack role add --project service --user heat admin"
fi

SERVICE_IMAGE=`openstack service list | grep heat | awk -F "|" '{print$3}' | awk -F " " '{print$1}' | grep -v   heat-cfn`
if [  ${SERVICE_IMAGE}x = heatx ]
then 
	log_info "openstack service create heat."
else
	openstack service create --name heat --description "Orchestration" orchestration
	fn_log "openstack service create --name heat --description "Orchestration" orchestration"
fi
SERVICE_IMAGEV2=`openstack service list | grep heat-cfn | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_IMAGEV2}x =  heat-cfnx ]
then
	log_info "openstack service create heat-cfn."
else
	openstack service create --name heat-cfn    --description "Orchestration"  cloudformation
	fn_log "openstack service create --name heat-cfn    --description "Orchestration"  cloudformation"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep orchestration  |grep internal  | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep orchestration   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep orchestration  |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create heat."
else
	openstack endpoint create --region RegionOne   orchestration public http://${HOSTNAME}:8004/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   orchestration internal http://${HOSTNAME}:8004/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   orchestration admin http://${HOSTNAME}:8004/v1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   orchestration public http://${HOSTNAME}:8004/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   orchestration internal http://${HOSTNAME}:8004/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   orchestration admin http://${HOSTNAME}:8004/v1/%\(tenant_id\)s"
fi

ENDPOINT_LIST_INTERNAL_V2=`openstack endpoint list  | grep cloudformation  |grep internal  | wc -l`
ENDPOINT_LIST_PUBLIC_V2=`openstack endpoint list | grep cloudformation   |grep public | wc -l`
ENDPOINT_LIST_ADMIN_V2=`openstack endpoint list | grep cloudformation   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL_V2}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC_V2}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN_V2} -eq 1  ]
then
	log_info "openstack endpoint create heatv2."
else
	openstack endpoint create --region RegionOne   cloudformation public http://${HOSTNAME}:8000/v1 && openstack endpoint create --region RegionOne   cloudformation internal http://${HOSTNAME}:8000/v1 && openstack endpoint create --region RegionOne   cloudformation admin http://${HOSTNAME}:8000/v1
	fn_log "openstack endpoint create --region RegionOne   cloudformation public http://${HOSTNAME}:8000/v1 && openstack endpoint create --region RegionOne   cloudformation internal http://${HOSTNAME}:8000/v1 && openstack endpoint create --region RegionOne   cloudformation admin http://${HOSTNAME}:8000/v1"
fi



DOMAIN_HEAT=`openstack domain  list | grep heat |  awk -F " " '{print$4}'`
if [  ${DOMAIN_HEAT}x = heatx ]
then
	log_info "domain heat had created."
else
	openstack domain create --description "Stack projects and users" heat
	fn_log "openstack domain create --description "Stack projects and users" heat"
fi



HEAT_DOMAIN_ADMIN=`openstack user list | grep -v Name |grep heat_domain_admin | awk -F " " '{print$4}' | grep -v ^$`
if [  ${HEAT_DOMAIN_ADMIN}x = heat_domain_adminx ]
then
	log_info "user  heat_domain_admin had created."
else
	openstack user create  --domain  heat  heat_domain_admin  --password ${ALL_PASSWORD}
	fn_log "openstack user create  --domain  heat  heat_domain_admin  --password ${ALL_PASSWORD}"
	openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
	fn_log "openstack role add --domain heat --user-domain heat --user heat_domain_admin admin"
fi

HEAT_STACK_OWNER=`openstack role list | grep -v Name |grep heat_stack_owner  | awk -F " " '{print$4}' | grep -v ^$`
if [ ${HEAT_STACK_OWNER}x = heat_stack_ownerx  ]
then
	log_info "heat_stack_owner had created."
else
	openstack role create heat_stack_owner
	fn_log "openstack role create heat_stack_owner"
fi
openstack role add --project demo --user demo heat_stack_owner
fn_log "openstack role add --project demo --user demo heat_stack_owner"

HEAT_STACK_USER=`openstack role list | grep heat_stack_user | awk -F " " '{print$4}'`
if [ ${HEAT_STACK_USER}x = heat_stack_userx ]
then
	log_info "heat_stack_user had created."
else
	openstack role create heat_stack_user
	fn_log "openstack role create heat_stack_user"
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
yum clean all && yum install openstack-heat-api openstack-heat-api-cfn   openstack-heat-engine -y
fn_log "yum clean all && yum install openstack-heat-api openstack-heat-api-cfn   openstack-heat-engine -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

[ -f /etc/heat/heat.conf_bak ] || cp -a /etc/heat/heat.conf /etc/heat/heat.conf_bak
openstack-config --set  /etc/heat/heat.conf database connection  mysql+pymysql://heat:${ALL_PASSWORD}@${HOSTNAME}/heat 
openstack-config --set  /etc/heat/heat.conf  DEFAULT  rpc_backend  rabbit
openstack-config --set  /etc/heat/heat.conf    oslo_messaging_rabbit rabbit_host  ${HOSTNAME}
openstack-config --set  /etc/heat/heat.conf    oslo_messaging_rabbit rabbit_userid  openstack
openstack-config --set  /etc/heat/heat.conf    oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD}
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken auth_uri    http://${HOSTNAME}:5000
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken auth_url    http://${HOSTNAME}:35357
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken memcached_servers    ${HOSTNAME}:11211
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken auth_type    password
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken project_domain_name    default
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken user_domain_name    default
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken project_name    service
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken username    heat
openstack-config --set  /etc/heat/heat.conf  keystone_authtoken password    ${ALL_PASSWORD}
openstack-config --set  /etc/heat/heat.conf  trustee auth_plugin    password
openstack-config --set  /etc/heat/heat.conf  trustee auth_url    http://${HOSTNAME}:35357
openstack-config --set  /etc/heat/heat.conf  trustee username    heat
openstack-config --set  /etc/heat/heat.conf  trustee password    ${ALL_PASSWORD}
openstack-config --set  /etc/heat/heat.conf  trustee user_domain_name    default
openstack-config --set  /etc/heat/heat.conf  clients_keystone  auth_uri    http://${HOSTNAME}:35357
openstack-config --set  /etc/heat/heat.conf   ec2authtoken auth_uri    http://${HOSTNAME}:5000
openstack-config --set  /etc/heat/heat.conf   DEFAULT heat_metadata_server_url    http://${HOSTNAME}:8000
openstack-config --set  /etc/heat/heat.conf   DEFAULT heat_waitcondition_server_url    http://${HOSTNAME}:8000/v1/waitcondition
openstack-config --set  /etc/heat/heat.conf   DEFAULT stack_domain_admin    heat_domain_admin
openstack-config --set  /etc/heat/heat.conf   DEFAULT stack_domain_admin_password    ${ALL_PASSWORD}
openstack-config --set  /etc/heat/heat.conf   DEFAULT stack_user_domain_name    heat
fn_log  "configure  /etc/heat/heat.conf"


su -s /bin/sh -c "heat-manage db_sync" heat
fn_log "su -s /bin/sh -c "heat-manage db_sync" heat"


systemctl enable openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service && systemctl start openstack-heat-api.service  openstack-heat-api-cfn.service openstack-heat-engine.service
fn_log "systemctl enable openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service && systemctl start openstack-heat-api.service  openstack-heat-api-cfn.service openstack-heat-engine.service"







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
sleep 30 
openstack orchestration service list
fn_log "openstack orchestration service list"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Heat Sucessed          #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_heat.tag