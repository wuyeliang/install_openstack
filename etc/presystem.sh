#！/bin/bash
#log function
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
if [  -e /etc/openstack-mitaka_tag/presystem-computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi



if [   ${HOST_NAME}x = x  -o ${MANAGER_IP}x = x -o ${ALL_PASSWORD}x  = x  -o ${NET_DEVICE_NAME}x = x ]
then
	echo -e "\033[41;37m please check $PWD/lib/installr . \033[0m"
	exit 1
fi

function fn_check_os_version () {
if [ -e /etc/system-release  ]
then
	OS_VERSION=`cat /etc/system-release | awk -F " " '{print$7}'`
	fn_log "OS_VERSION=`cat /etc/redhat-release | awk -F " " '{print$7}'`"
	if [ -z  ${OS_VERSION} ]
	then
		OS_VERSION=`cat /etc/system-release | awk -F " " '{print$4}'`
		fn_log "OS_VERSION=`cat /etc/redhat-release | awk -F " " '{print$4}'`"
	fi
else
	echo -e "\033[41;37m please run script on rhel7.2 or CentOS7.2 \033[0m"
	log_error "please run script on rhel7.2 or CentOS7.2"
	exit 1
fi
	
if [  ${OS_VERSION}x  = 7.2x  ] 
then
	echo "system is rhel7.2"
	fn_log "echo "system is rhel7.2""
elif [ ${OS_VERSION}x = 7.2.1511x   ]
then
	echo "system is CentOS7.2"
	fn_log "echo "system is CentOS7.2""	
else
	echo "please install system by rhel-server-7.2-x86_64-dvd.iso or CentOS-7-x86_64-DVD-1511.iso"
	log_error "echo "please install system by rhel-server-7.2-x86_64-dvd.iso or CentOS-7-x86_64-DVD-1511.iso""
	exit 1
fi 

}
fn_check_os_version

NAMEHOST=${HOST_NAME}
FIRST_ETH_IP=${MANAGER_IP}

if [  -z ${FIRST_ETH_IP} ]
then
	echo -e "\033[41;37m you should config the first network by the manager ip. \033[0m"
	log_error "you should config the first network by the manager ip."
	exit 1
fi

if [ -f  /etc/openstack-mitaka_tag/presystem.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment \033[0m"
	log_info "you haved config Basic environment."	
	exit
fi


if  [ ! -d /etc/openstack-mitaka_tag ]
then 
	mkdir -p /etc/openstack-mitaka_tag  
fi







#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi



hostnamectl set-hostname ${NAMEHOST}
fn_log "hostnamectl set-hostname ${NAMEHOST}"
cat $PWD/lib/hosts >/etc/hosts
fn_log "cat $PWD/lib/hosts >/etc/hosts"






#stop firewall
service firewalld stop 
fn_log "stop firewall"
chkconfig firewalld off 
fn_log "chkconfig firewalld off"

ping -c 4 ${NAMEHOST} 
fn_log "ping -c 4 ${NAMEHOST} "





#install ntp 
function fn_install_ntp () {
yum clean all && yum install ntp -y 
fn_log "yum clean all && yum install ntp -y"
#modify /etc/ntp.conf 
if [ -f /etc/ntp.conf  ]
then 
	cp -a /etc/ntp.conf /etc/ntp.conf_bak && \
	sed -i "/^# Please\ consider\ joining\ the\ pool/i server\ 127.127.1.0" /etc/ntp.conf && \
	sed -i "/^# Please\ consider\ joining\ the\ pool/i fudge\ 127.127.1.0\ stratum\ 0" /etc/ntp.conf
	fn_log "modify /etc/ntp.conf"
fi 
#restart ntp 
systemctl enable ntpd.service &&  systemctl start ntpd.service 
fn_log "systemctl enable ntpd.service &&  systemctl start ntpd.service "
service chronyd stop
chkconfig chronyd off

sleep 10
ntpq -p
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/install_ntp.tag
}

if  [ -f /etc/openstack-mitaka_tag/install_ntp.tag ]
then
	log_info "ntp had installed."
else
	fn_install_ntp
fi
#disabile selinux
function fn_set_selinx () {
cp -a /etc/selinux/config /etc/selinux/config_bak
sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}
STATUS_SELINUX=`cat /etc/selinux/config | grep ^SELINUX= | awk -F "=" '{print$2}'`
if [  ${STATUS_SELINUX} = enforcing ]
then 
	fn_set_selinx
else 
	log_info "selinux is disabled."
fi


if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info "use local yum."
else 
	echo -e "\033[41;37m please configure /etc/yum.repos.d/repo.repo for local repo.  \033[0m"
	exit 1
fi

yum clean all && yum update -y 

fn_log "yum clean all && yum update -y " && cd /etc/yum.repos.d/ &&  rm -rf CentOS-*

if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	rm -rf /etc/yum.repos.d/CentOS-*
fi




echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-mitaka_tag/presystem.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##   Configure  System Sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
sleep 10 

reboot







