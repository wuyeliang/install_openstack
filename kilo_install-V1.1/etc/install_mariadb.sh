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
if [ -f  /etc/openstack-kilo_tag/presystem.tag ]
then 
	log_info "config system have installed ."
else
	echo -e "\033[41;37m you should config system first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_mariadb.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment \033[0m"
	log_info "you had install mariadb."	
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



yum clean all && yum install openstack-selinux -y
fn_log "yum clean all && yum install openstack-selinux -y"
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`


function fn_install_mariadb () {
yum clean all && yum install mariadb mariadb-server MySQL-python -y
fn_log "yum clean all && yum install mariadb mariadb-server MySQL-python -y"
rm -rf /etc/my.cnf.d/mariadb_openstack.cnf &&  cp -a $PWD/lib/mariadb_openstack.cnf /etc/my.cnf.d/mariadb_openstack.cnf
fn_log "cp -a $PWD/lib/mariadb_openstack.cnf /etc/my.cnf.d/mariadb_openstack.cnf"
echo " " >>/etc/my.cnf.d/mariadb_openstack.cnf
echo "bind-address = ${FIRST_ETH_IP}" >>/etc/my.cnf.d/mariadb_openstack.cnf

#start mariadb
systemctl enable mariadb.service &&  systemctl start mariadb.service 
fn_log "systemctl enable mariadb.service &&  systemctl start mariadb.service"
mysql_secure_installation <<EOF

y
Changeme_123
Changeme_123
y
y
y
y
EOF
fn_log "mysql_secure_installation"
}
MARIADB_STATUS=`service mariadb status | grep Active | awk -F "("  '{print$2}' | awk -F ")"  '{print$1}'`
if [ "${MARIADB_STATUS}"  = running ]
then
	log_info "mairadb had installl."
else
	fn_install_mariadb
fi



function fn_install_rabbit () {
yum clean all && yum install rabbitmq-server -y
fn_log "yum clean all && yum install rabbitmq-server -y"

#start rabbitmq-server.service
systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service 
fn_log "systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service"

rabbitmqctl add_user openstack Changeme_123
fn_log "rabbitmqctl add_user openstack Changeme_123"
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
fn_log "rabbitmqctl set_permissions openstack ".*" ".*" ".*""
}
function fn_test_rabbit () {
RABBIT_STATUS=`rabbitmqctl list_users | grep openstack | awk -F " " '{print$1}'`
if [ ${RABBIT_STATUS}x  = openstackx ]
then 
	log_info "rabbit had installed."
else
	fn_install_rabbit
fi
}
if [ -f /usr/sbin/rabbitmqctl  ]
then
	log_info "rabbit had installed."
else
	fn_test_rabbit
fi



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###   install mariadb and rabbitmq sucessed.#### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_mariadb.tag
