#!/bin/bash
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
if [ -f  /etc/openstack-kilo_tag/install_mariadb.tag ]
then 
	log_info "mariadb have installed ."
else
	echo -e "\033[41;37m you should install mariadb first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/config_keystone.tag ]
then 
	echo -e "\033[41;37m etc/openstack-kilo_tag/config_keystone.tag \033[0m"
	log_info "you had install keystone."	
	exit
fi
#test network
NAMEHOST=`cat $PWD/lib/hostname`
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


#create databases
function  fn_create_keystone_database () {
mysql -uroot -pChangeme_123 -e "CREATE DATABASE keystone;" &&  mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'Changeme_123';" && mysql -uroot -pChangeme_123 -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'Changeme_123';"   
fn_log "create databases"

}
mysql -uroot -pChangeme_123 -e "show databases ;" >test 
DATABASEKEYSTONE=`cat test | grep keystone`
rm -rf test 
if [ ${DATABASEKEYSTONE}x = keystonex ]
then
	log_info "keystone database had installed."
else
	fn_create_keystone_database
fi

yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y
fn_log "yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y"

#start memcached.service
systemctl enable memcached.service &&  systemctl start memcached.service 
fn_log "systemctl enable memcached.service &&  systemctl start memcached.service"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"


[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak
fn_log "[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak"
ADMIN_TOKEN=$(openssl rand -hex 10)
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN 
fn_log "openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN "
                                                      
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:Changeme_123@$HOSTNAME/keystone  
fn_log "openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:Changeme_123@$HOSTNAME/keystone "


openstack-config --set /etc/keystone/keystone.conf memcache servers localhost:11211

fn_log "openstack-config --set /etc/keystone/keystone.conf memcache servers localhost:11211"


openstack-config --set /etc/keystone/keystone.conf token provider  keystone.token.providers.uuid.Provider 
fn_log "openstack-config --set /etc/keystone/keystone.conf token provider  keystone.token.providers.uuid.Provider"

openstack-config --set /etc/keystone/keystone.conf token driver  keystone.token.persistence.backends.memcache.Token 
fn_log "openstack-config --set /etc/keystone/keystone.conf token driver  keystone.token.persistence.backends.memcache.Token "

openstack-config --set /etc/keystone/keystone.conf revoke driver  keystone.contrib.revoke.backends.sql.Revoke 
fn_log "openstack-config --set /etc/keystone/keystone.conf revoke driver  keystone.contrib.revoke.backends.sql.Revoke"
openstack-config --set /etc/keystone/keystone.conf  DEFAULT  verbose  True 
fn_log "openstack-config --set /etc/keystone/keystone.conf  DEFAULT  verbose  True "


su -s /bin/sh -c "keystone-manage db_sync" keystone 
fn_log "su -s /bin/sh -c "keystone-manage db_sync" keystone "

[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak
fn_log "[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak"

sed  -i  "s/#ServerName www.example.com:80/ServerName ${HOSTNAME}/" /etc/httpd/conf/httpd.conf
fn_log "sed  -i  's/#ServerName www.example.com:80/ServerName $HOSTNAME/' /etc/httpd/conf/httpd.conf"



rm -rf /etc/httpd/conf.d/wsgi-keystone.conf  && cp -a $PWD/lib/wsgi-keystone.conf  /etc/httpd/conf.d/wsgi-keystone.conf 
fn_log "cp -a $PWD/lib/wsgi-keystone.conf  /etc/httpd/conf.d/wsgi-keystone.conf "

rm -rf /var/www/cgi-bin/keystone && mkdir -p /var/www/cgi-bin/keystone

cat $PWD/lib/keystone_admin >>/var/www/cgi-bin/keystone/main  &&  cat $PWD/lib/keystone_admin >>/var/www/cgi-bin/keystone/admin && chown keystone:keystone  /var/www/cgi-bin/keystone/admin  /var/www/cgi-bin/keystone/main && chmod 755 /var/www/cgi-bin/keystone/admin  /var/www/cgi-bin/keystone/main
fn_log "cat $PWD/lib/keystone_admin >>/var/www/cgi-bin/keystone/main  &&  cat $PWD/lib/keystone_admin >>/var/www/cgi-bin/keystone/admin && chown keystone:keystone  /var/www/cgi-bin/keystone/admin  /var/www/cgi-bin/keystone/main && chmod 755 /var/www/cgi-bin/keystone/admin  /var/www/cgi-bin/keystone/main"

chown -R keystone:keystone /var/www/cgi-bin/keystone && chmod 755 /var/www/cgi-bin/keystone/* 
fn_log "chown -R keystone:keystone /var/www/cgi-bin/keystone && chmod 755 /var/www/cgi-bin/keystone/*"

systemctl enable httpd.service && systemctl start httpd.service 
fn_log "systemctl enable httpd.service && systemctl start httpd.service "
unset http_proxy https_proxy ftp_proxy no_proxy 

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://$HOSTNAME:35357/v2.0



SERVICE_NAME=`openstack service list | grep keystone |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${SERVICE_NAME}x  = keystonex ]
then 
	log_info "openstack service have create"
else
	openstack service create --name keystone --description "OpenStack Identity" identity
    fn_log "openstack service create --name keystone --description "OpenStack Identity" identity"
fi


ENDPOINT_LIST=`openstack endpoint list | grep keystone | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`
if [  ${ENDPOINT_LIST}x  = keystonex  ]
then
	log_info "openstack endpoint had created."
else
	openstack endpoint create --publicurl http://${NAMEHOST}:5000/v2.0 --internalurl http://${NAMEHOST}:5000/v2.0 --adminurl http://${NAMEHOST}:35357/v2.0 --region RegionOne identity
	fn_log "openstack endpoint create"
fi


PROJECT_ADMIN=`openstack project list | grep admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${PROJECT_ADMIN}x = adminx ]
then
	log_info "openstack project admin create."
else
	openstack project create --description "Admin Project" admin
	fn_log "openstack project create --description "Admin Project" admin"
fi


USER_LIST=`openstack user list | grep  admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

if [ ${USER_LIST}x = adminx ]
then
	log_info "openstack user had  created  admin"
else
	openstack user create  admin --password Changeme_123
	fn_log "openstack user create  admin --password Changeme_123"
fi



ROLE_ADMIN=`openstack role list | grep admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${ROLE_ADMIN}x = adminx ]
then 
	log_info "openstack role had created admin"
else
	openstack role create admin
	fn_log "openstack role create admin"
	openstack role add --project admin --user admin admin
	fn_log "openstack role add --project admin --user admin admin"
fi


PROJECT_SERVICE=`openstack project list |grep service | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_SERVICE}x = servicex ]
then
	log_info "openstack project had created service. "
else
	openstack project create --description "Service Project" service
	fn_log "openstack project create --description "Service Project" service"
fi


PROJECT_DEMO=`openstack project list |grep demo | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_DEMO}x = demox ]
then
	log_info "openstack project had created demo "
else
	openstack project create --description "Demo Project" demo
	fn_log "openstack project create --description "Demo Project" demo"
fi


USER_DEMO=` openstack user list |grep demo |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_DEMO}x  =  demox ]
then
	log_info "openstack user had created  demo "
else
	openstack user create  demo  --password Changeme_123
	fn_log "openstack user create  demo  --password Changeme_123"
fi

ROLE_LIST=`openstack role list | grep user  |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${ROLE_LIST}x = userx ]
then
	log_info "openstack role had  created user."
else
	openstack role create user
	fn_log "openstack role create user"
	openstack role add --project demo --user demo user
	fn_log "openstack role add --project demo --user demo user"
fi


unset OS_TOKEN OS_URL
openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password token issue --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password token issue --os-password Changeme_123"


openstack --os-auth-url http://$HOSTNAME:35357 --os-project-domain-id default --os-user-domain-id default --os-project-name admin --os-username admin --os-auth-type password token issue --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-domain-id default --os-user-domain-id default --os-project-name admin --os-username admin --os-auth-type password token issue --os-password Changeme_123"




openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password project list  --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password project list  --os-password Changeme_123"





openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password user list --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password user list --os-password Changeme_123"






openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password role list --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password role list --os-password Changeme_123"



openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password token issue  --os-password Changeme_123
fn_log "openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password token issue  --os-password Changeme_123"



openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password user list --os-password Changeme_123
if [  $? -eq 0  ]
then
	log_error "openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password user list --os-password Changeme_123 sucessed."
	exit
else
	log_info "openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password user list --os-password Changeme_123 failed."
	echo -e "\033[32m test openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password user list sucessed. \033[0m"
fi


[ -f /root/admin-openrc.sh  ] || cp -a $PWD/lib/admin-openrc.sh  /root/admin-openrc.sh 
fn_log "[ -f /root/admin-openrc.sh  ] || cp -a $PWD/lib/admin-openrc.sh  /root/admin-openrc.sh  "


[ -f /root/demo-openrc.sh  ]  || cp -a $PWD/lib/demo-openrc.sh  /root/demo-openrc.sh 
fn_log "cp -a $PWD/lib/demo-openrc.sh  /root/demo-openrc.sh "
source ~/admin-openrc.sh
openstack token issue
fn_log "openstack token issue"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       install keystone sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/config_keystone.tag
