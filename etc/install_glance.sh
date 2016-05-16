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

if [ -f  /etc/openstack-mitaka_tag/install_glance.tag ]
then 
	echo -e "\033[41;37m you haved install glance \033[0m"
	log_info "you haved install glance."	
	exit
fi

#create glance databases 
function  fn_create_glance_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE glance;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create glance databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASEGLANCE=`cat test | grep glance`
rm -rf test 
if [ ${DATABASEGLANCE}x = glancex ]
then
	log_info "glance database had installed."
else
	fn_create_glance_database
fi

unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
USER_GLANCE=`openstack user list | grep glance | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_GLANCE}x = glancex ]
then
	log_info "openstack user had created  glance"
else
	
	openstack user create  --domain default glance  --password ${ALL_PASSWORD}
	fn_log "openstack user create --domain default glance  --password ${ALL_PASSWORD}"
	openstack role add --project service --user glance admin
	fn_log "openstack role add --project service --user glance admin"
fi

SERVICE_IMAGE=`openstack service list | grep glance | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_IMAGE}x = glancex ]
then 
	log_info "openstack service create glance."
else
	openstack service create --name glance --description "OpenStack Image service" image
	fn_log "openstack service create --name glance --description "OpenStack Image service" image"
fi



ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep image  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep image   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep image   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]

then
	log_info "openstack endpoint create glance."
else
	openstack endpoint create --region RegionOne   image public http://${NAMEHOST}:9292  &&   openstack endpoint create --region RegionOne   image internal http://${NAMEHOST}:9292 &&   openstack endpoint create --region RegionOne   image admin http://${NAMEHOST}:9292
	fn_log "openstack endpoint create --region RegionOne   image public http://${NAMEHOST}:9292  &&   openstack endpoint create --region RegionOne   image internal http://${NAMEHOST}:9292 &&   openstack endpoint create --region RegionOne   image admin http://${NAMEHOST}:9292"
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

yum clean all && yum install openstack-glance -y
fn_log "yum clean all && yum install openstack-glance -y"
unset http_proxy https_proxy ftp_proxy no_proxy 

[ -f /etc/glance/glance-api.conf_bak ] || cp -a /etc/glance/glance-api.conf /etc/glance/glance-api.conf_bak
openstack-config --set  /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_type   password && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_name  default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_name   default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password  ${ALL_PASSWORD} && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name  service  && openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor  keystone && openstack-config --set  /etc/glance/glance-api.conf glance_store stores  file,http && openstack-config --set  /etc/glance/glance-api.conf glance_store default_store  file && openstack-config --set  /etc/glance/glance-api.conf glance_store filesystem_store_datadir  /var/lib/glance/images/  
fn_log  "openstack-config --set  /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_type   password && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_name  default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_name   default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password  ${ALL_PASSWORD} && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name  service  && openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor  keystone && openstack-config --set  /etc/glance/glance-api.conf glance_store stores  file,http && openstack-config --set  /etc/glance/glance-api.conf glance_store default_store  file && openstack-config --set  /etc/glance/glance-api.conf glance_store filesystem_store_datadir  /var/lib/glance/images/ && openstack-config --set  /etc/glance/glance-api.conf DEFAULT verbose  True "

[ -f /etc/glance/glance-registry.conf_bak ] || cp -a /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf_bak
openstack-config --set  /etc/glance/glance-registry.conf database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance &&  openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211  && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_type  password && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_name   default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_name   default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name  service && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken password ${ALL_PASSWORD} &&  openstack-config --set  /etc/glance/glance-registry.conf paste_deploy flavor  keystone  
fn_log  "openstack-config --set  /etc/glance/glance-registry.conf database connection  mysql+pymysql://glance:${ALL_PASSWORD}@${HOSTNAME}/glance &&  openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211  && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_type  password && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_name   default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_name   default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name  service && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken password ${ALL_PASSWORD} &&  openstack-config --set  /etc/glance/glance-registry.conf paste_deploy flavor  keystone && openstack-config --set  /etc/glance/glance-registry.conf DEFAULT verbose  True "

su -s /bin/sh -c "glance-manage db_sync" glance 
fn_log "su -s /bin/sh -c "glance-manage db_sync" glance"

systemctl enable openstack-glance-api.service   openstack-glance-registry.service  && systemctl start openstack-glance-api.service   openstack-glance-registry.service
fn_log "systemctl enable openstack-glance-api.service   openstack-glance-registry.service  && systemctl start openstack-glance-api.service   openstack-glance-registry.service"



function fn_add_source () {
echo " " >>  /root/admin-openrc.sh && \
echo " " >>  /root/demo-openrc.sh && \
echo "export OS_IMAGE_API_VERSION=2" | tee -a /root/admin-openrc.sh  /root/demo-openrc.sh
fn_log ""export OS_IMAGE_API_VERSION=2" | tee -a /root/admin-openrc.sh  /root/demo-openrc.sh"
}
VERSION_IMAGE=`cat /root/admin-openrc.sh | grep OS_IMAGE_API_VERSION | awk -F " " '{print$2}' | awk -F "=" '{print$1}'`
if [ ${VERSION_IMAGE}x = OS_IMAGE_API_VERSIONx  ]
then
	log_info "admin-openrc.sh have add OS_IMAGE_API_VERSION."
else
	fn_add_source
fi



sleep 20


function fn_create_image () {
source /root/admin-openrc.sh  && \
cp -a $PWD/lib/cirros-0.3.4-x86_64-disk.img /tmp/  && \
openstack image create "cirros"   --file /tmp/cirros-0.3.4-x86_64-disk.img   --disk-format qcow2 --container-format bare   --public
fn_log "create image"

glance image-list
fn_log "glance image-list"
}
GLANCE_ID=`glance image-list | grep cirros-0.3.4-x86_64  | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${GLANCE_ID}x = cirros-0.3.4-x86_64x ]
then
	log_info "glance image cirros-0.3.4-x86_64 had create."
else
	fn_create_image
fi


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        Install Glance Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_glance.tag