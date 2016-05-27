#！/bin/bash
#log function
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
OS_VERSION=`cat /etc/centos-release | awk -F " " '{print$4}' | awk -F "." '{print$3}'`
if [  ${OS_VERSION} -eq 1503 ]
then
	echo -e "\033[41;37m you should install OS system by CentOS-7.0-1406-x86_64-DVD.iso. \033[0m"
	log_error "you should install OS system by CentOS-7.0-1406-x86_64-DVD.iso."
	exit 1
fi


FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`

if [  -z ${FIRST_ETH_IP} ]
then
	echo -e "\033[41;37m you should config the first network by the manager ip. \033[0m"
	log_error "you should config the first network by the manager ip."
	exit 1
fi

if [ -f  /etc/openstack-kilo_tag/presystem.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment \033[0m"
	log_info "you haved config Basic environment."	
	exit
fi

read -p "please hostname for system [default:controller] :" install_number
if  [ -z ${install_number}  ]
then 
    echo "controller" >$PWD/lib/hostname
    NAMEHOST=controller
else
	echo "${install_number}" >$PWD/lib/hostname
fi
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi


NAMEHOST=`cat $PWD/lib/hostname`

FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`




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


#set hostname
function fn_set_hostname () {
hostnamectl set-hostname ${NAMEHOST}
fn_log "set hostname"
echo "${FIRST_ETH_IP} ${NAMEHOST} " >>/etc/hosts
fn_log  "modify hosts"
}

HOSTS_STATUS=`cat /etc/hosts | grep $FIRST_ETH_IP`
if [  -z  "${HOSTS_STATUS}"  ]
then
	fn_set_hostname
else
	log_info "hostname had seted"
fi



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
	cp -a /etc/ntp.conf /etc/ntp.conf_bak
	sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
	fn_log "modify /etc/ntp.conf"
fi 
#restart ntp 
systemctl enable ntpd.service && systemctl start ntpd.service  
fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
sleep 10
ntpq -c peers 
ntpq -c assoc
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
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
function fn_yum_openstack () {
cd /etc/yum.repos.d && rm -rf CentOS-Base.repo.bk &&  mv CentOS-Base.repo CentOS-Base.repo.bk   && wget http://mirrors.163.com/.help/CentOS7-Base-163.repo  
fn_log "cd /etc/yum.repos.d &&  mv CentOS-Base.repo CentOS-Base.repo.bk   && wget http://mirrors.163.com/.help/CentOS7-Base-163.repo  "
yum clean all && yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y
fn_log "yum clean all && yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y"


yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y
fn_log "yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y"
}

if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info "use local yum."
else 
	fn_yum_openstack
fi

yum clean all && yum update -y 

fn_log "yum clean all && yum update -y " && cd /etc/yum.repos.d/ &&  rm -rf CentOS-*

if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	rm -rf /etc/yum.repos.d/CentOS-*
fi




echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/presystem.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##   preset  systen sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
sleep 10 

reboot







