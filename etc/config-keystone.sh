#!/bin/bash
#log function
NAMEHOST=$HOSTNAME
if [  -e $PWD/lib/newton-log.sh ]
then	
	source $PWD/lib/newton-log.sh
else
	echo -e "\033[41;37m $PWD/newton-log.sh is not exist. \033[0m"
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
if [ ${http_proxy}x = x -a  ${https_proxy}x = x  -a ${ftp_proxy}x = x ]
then
	log_info "proxy is none."
else
	echo -e "\033[41;37m you should unset proxy. \033[0m"
	exit 1
fi
if [  -e /etc/openstack-newton_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-newton_tag/install_mariadb.tag ]
then 
	log_info "mariadb have installed ."
else
	echo -e "\033[41;37m you should install mariadb first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-newton_tag/config_keystone.tag ]
then 
	echo -e "\033[41;37m etc/openstack-newton_tag/config_keystone.tag \033[0m"
	log_info "you had install keystone."	
	exit
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


#create databases
function  fn_create_keystone_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE keystone;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${ALL_PASSWORD}';"   
fn_log "create databases"

}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASEKEYSTONE=`cat test | grep keystone`
rm -rf test 
if [ ${DATABASEKEYSTONE}x = keystonex ]
then
	log_info "keystone database had installed."
else
	fn_create_keystone_database
fi
                   
		   
yum clean all && yum install openstack-keystone httpd mod_wsgi   memcached python-memcached -y
fn_log "yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y"

#start memcached.service
systemctl enable memcached.service &&  systemctl start memcached.service 
fn_log "systemctl enable memcached.service &&  systemctl start memcached.service"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"


[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak
fn_log "[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak"

                                 
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:${ALL_PASSWORD}@$HOSTNAME/keystone  
fn_log "openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:${ALL_PASSWORD}@$HOSTNAME/keystone "

openstack-config --set /etc/keystone/keystone.conf token provider  fernet
fn_log "openstack-config --set /etc/keystone/keystone.conf token provider  fernet"



su -s /bin/sh -c "keystone-manage db_sync" keystone
fn_log "su -s /bin/sh -c "keystone-manage db_sync" keystone"

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
fn_log "keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone "

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
fn_log "keystone-manage credential_setup --keystone-user keystone --keystone-group keystone"



keystone-manage bootstrap --bootstrap-password ${ALL_PASSWORD}   --bootstrap-admin-url http://$HOSTNAME:35357/v3/   --bootstrap-internal-url http://$HOSTNAME:35357/v3/   --bootstrap-public-url http://$HOSTNAME:5000/v3/   --bootstrap-region-id RegionOne
fn_log "keystone-manage bootstrap --bootstrap-password ${ALL_PASSWORD}   --bootstrap-admin-url http://$HOSTNAME:35357/v3/   --bootstrap-internal-url http://$HOSTNAME:35357/v3/   --bootstrap-public-url http://$HOSTNAME:5000/v3/   --bootstrap-region-id RegionOne"




[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak
fn_log "[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak"

sed  -i  "s/#ServerName www.example.com:80/ServerName ${HOSTNAME}/" /etc/httpd/conf/httpd.conf
fn_log "sed  -i  's/#ServerName www.example.com:80/ServerName $HOSTNAME/' /etc/httpd/conf/httpd.conf"

RESULT_HTTP=`cat /etc/httpd/conf/httpd.conf | grep $HOSTNAME | awk -F " " '{print$2}'`
if [ ${RESULT_HTTP} = ${HOSTNAME}  ]
then
	log_info "http servername is ${HOSTNAME} "
else
	log_error "http servername is null"
	exit 1
fi

rm -f /etc/httpd/conf.d/wsgi-keystone.conf  && ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
fn_log "rm -f /etc/httpd/conf.d/wsgi-keystone.conf  && ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/ "


systemctl enable httpd.service && systemctl start httpd.service 
fn_log "systemctl enable httpd.service && systemctl start httpd.service "
unset http_proxy https_proxy ftp_proxy no_proxy 



export OS_USERNAME=admin
export OS_PASSWORD=${ALL_PASSWORD}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$HOSTNAME:35357/v3
export OS_IDENTITY_API_VERSION=3
sleep 10 




PROJECT_SERVICE=`openstack project list |grep service | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_SERVICE}x = servicex ]
then
	log_info "openstack project had created service. "
else
	openstack project create --domain default   --description "Service Project" service
	fn_log "openstack project create --domain default   --description "Service Project" service"
fi

PROJECT_DEMO=`openstack project list |grep demo | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_DEMO}x = demox ]
then
	log_info "openstack project had created demo "
else
	openstack project create --domain default   --description "Demo Project" demo
	fn_log "openstack project create --domain default   --description "Demo Project" demo"
fi

USER_DEMO=` openstack user list |grep demo |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_DEMO}x  =  demox ]
then
	log_info "openstack user had created  demo "
else
	openstack user create --domain default  demo  --password ${ALL_PASSWORD}
	fn_log "openstack user create  demo  --password ${ALL_PASSWORD}"
fi


ROLE_LIST=`openstack role list | grep user  |awk -F "|" '{print$3}' | awk -F " " '{print$1}'  | grep -v  heat_stack_user`
if [ ${ROLE_LIST}x = userx ]
then
	log_info "openstack role had  created user."
else
	openstack role create user
	fn_log "openstack role create user"
	openstack role add --project demo --user demo user
	fn_log "openstack role add --project demo --user demo user"
fi



openstack role add --project admin --user admin admin
fn_log "	openstack role add --project admin --user admin admin"


unset OS_URL
fn_log "unset OS_URL"
openstack --os-auth-url http://$HOSTNAME:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password ${ALL_PASSWORD}
fn_log "openstack --os-auth-url http://$HOSTNAME:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password ${ALL_PASSWORD}"


openstack --os-auth-url http://$HOSTNAME:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password ${ALL_PASSWORD}
fn_log "openstack --os-auth-url http://$HOSTNAME:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password ${ALL_PASSWORD}"








cat <<END >/root/admin-openrc.sh 
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${HOST_NAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END







cat <<END >/root/demo-openrc.sh  
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=${ALL_PASSWORD}
export OS_AUTH_URL=http://${HOST_NAME}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
END


source ~/admin-openrc.sh
openstack token issue
fn_log "openstack token issue"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       Install Keystone Sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack-newton_tag ]
then 
	mkdir -p /etc/openstack-newton_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-newton_tag/config_keystone.tag
