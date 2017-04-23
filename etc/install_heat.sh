#！/bin/bash
#log function
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

if [ -f  /etc/openstack-ocata_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-ocata_tag/install_heat.tag ]
then 
	echo -e "\033[41;37m you haved install heat \033[0m"
	log_info "you haved install heat."	
	exit
fi

#create heat databases

fn_create_database heat ${ALL_PASSWORD}
fn_log "fn_create_database heat ${ALL_PASSWORD}"


 


unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 


fn_create_user heat ${ALL_PASSWORD}
fn_log "fn_create_user heat ${ALL_PASSWORD}"
openstack role add --project service --user heat admin
fn_log "openstack role add --project service --user heat admin"




fn_create_service heat  "Orchestration" orchestration
fn_log "fn_create_service heat  "Orchestration" orchestration"


fn_create_service heat-cfn  "Orchestration" cloudformation
fn_log "fn_create_service heat-cfn  "Orchestration" cloudformation"



fn_create_endpoint_version orchestration  8004 v1
fn_log "fn_create_endpoint_version orchestration  8004 v1"


fn_create_endpoint_version cloudformation   8000 v1
fn_log "fn_create_endpoint_version cloudformation   8000 v1"




fn_create_domain heat  "Stack projects and users"
fn_log "fn_create_domain heat  "Stack projects and users""





HEAT_DOMAIN_ADMIN=`openstack user list | grep -v Name |grep heat_domain_admin | awk -F " " '{print$4}' | grep -v ^$`
if [  ${HEAT_DOMAIN_ADMIN}x = heat_domain_adminx ]
then
	log_info "user  heat_domain_admin have  been  created."
else
	openstack user create  --domain  heat  heat_domain_admin  --password ${ALL_PASSWORD}
	fn_log "openstack user create  --domain  heat  heat_domain_admin  --password ${ALL_PASSWORD}"
	openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
	fn_log "openstack role add --domain heat --user-domain heat --user heat_domain_admin admin"
fi



fn_create_role heat_stack_owner
fn_log "fn_create_role heat_stack_owner"

fn_create_role heat_stack_user
fn_log "fn_create_role heat_stack_user" 

openstack role add --project demo --user demo heat_stack_owner
fn_log "openstack role add --project demo --user demo heat_stack_owner"










#for controller
yum clean all && yum install yum install openstack-heat-api openstack-heat-api-cfn   openstack-heat-engine -y
fn_log "yum clean all && yum install yum install openstack-heat-api openstack-heat-api-cfn   openstack-heat-engine -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

cat <<END >/tmp/tmp
database connection   mysql+pymysql://heat:${ALL_PASSWORD}@${MANAGER_IP}/heat
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   heat
keystone_authtoken password   ${ALL_PASSWORD}
trustee auth_type   password
trustee auth_url   http://${MANAGER_IP}:35357
trustee username   heat
trustee password   ${ALL_PASSWORD}
trustee user_domain_name   default
clients_keystone auth_uri   http://${MANAGER_IP}:35357
ec2authtoken auth_uri   http://${MANAGER_IP}:5000
DEFAULT heat_metadata_server_url   http://${MANAGER_IP}:8000
DEFAULT heat_waitcondition_server_url   http://${MANAGER_IP}:8000/v1/waitcondition
DEFAULT stack_domain_admin   heat_domain_admin
DEFAULT stack_domain_admin_password   ${ALL_PASSWORD}
DEFAULT stack_user_domain_name   heat
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/heat/heat.conf
fn_log "fn_set_conf /etc/heat/heat.conf"


su -s /bin/sh -c "heat-manage db_sync" heat
fn_log "su -s /bin/sh -c "heat-manage db_sync" heat"


systemctl enable openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service && systemctl start openstack-heat-api.service  openstack-heat-api-cfn.service openstack-heat-engine.service
fn_log "systemctl enable openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service && systemctl start openstack-heat-api.service  openstack-heat-api-cfn.service openstack-heat-engine.service"







source /root/admin-openrc.sh
fn_log "source /root/admin-openrc.sh"
sleep 30 
openstack orchestration service list
fn_log "openstack orchestration service list"




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Heat Sucessed          #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_heat.tag