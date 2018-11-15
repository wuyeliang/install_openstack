#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
if [  -e ${TOPDIR}/lib/openstack-log.sh ]
then	
	source ${TOPDIR}/lib/openstack-log.sh
else
	echo -e "\033[41;37m ${TOPDIR}/openstack-log.sh is not exist. \033[0m"
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
if [  -e /etc/openstack_tag/presystem-computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi



if [   ${HOST_NAME}x = x  -o ${MANAGER_IP}x = x -o ${ALL_PASSWORD}x  = x  -o ${NET_DEVICE_NAME}x = x ]
then
	echo -e "\033[41;37m please check ${TOPDIR}/lib/installr . \033[0m"
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
	echo -e "\033[41;37m please run script on rhel7.3 or CentOS7.3 \033[0m"
	log_error "please run script on rhel7.3 or CentOS7.3"
	exit 1
fi
	
if [  ${OS_VERSION}x  = 7.4x  ] 
then
	echo "system is rhel7.4"
	fn_log "echo "system is rhel7.4""
elif [ ${OS_VERSION}x = 7.4.1708x   ]
then
	echo "system is CentOS7.4"
	fn_log "echo "system is CentOS7.4""	
else
	echo "please install system by CentOS-7-x86_64-Minimal-1708.iso"
	log_error "echo "please install system by CentOS-7-x86_64-Minimal-1708.iso""
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

if [ -f  /etc/openstack_tag/presystem.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment \033[0m"
	log_info "you haved config Basic environment."	
	exit
fi


if  [ ! -d /etc/openstack_tag ]
then 
	mkdir -p /etc/openstack_tag  
fi







#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
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
cat ${TOPDIR}/lib/hosts >/etc/hosts
fn_log "cat ${TOPDIR}/lib/hosts >/etc/hosts"






#stop firewall
yum -y install ntp vim  net-tools 
fn_log "yum -y install ntp vim  net-tools "
yum install firewalld -y
fn_log "yum install firewalld -y"
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
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/install_ntp.tag
}

if  [ -f /etc/openstack_tag/install_ntp.tag ]
then
	log_info "ntp have  been  installed."
else
	fn_install_ntp
fi
#disabile selinux
function fn_set_selinux () {
cp -a /etc/selinux/config /etc/selinux/config_bak
sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}
STATUS_SELINUX=`cat /etc/selinux/config | grep ^SELINUX= | awk -F "=" '{print$2}'`
if [  ${STATUS_SELINUX} = enforcing ]
then 
	fn_set_selinux
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
fn_log "yum clean all && yum update -y " 


yum clean all && yum install openstack-selinux -y
fn_log "yum clean all && yum install openstack-selinux -y"

rm -rf /etc/yum.repos.d/CentOS-*
fn_log "rm -rf /etc/yum.repos.d/CentOS-*"

if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	rm -rf /etc/yum.repos.d/CentOS-*
fi


yum install openstack-selinux python-openstackclient -y
fn_log "yum install openstack-selinux python-openstackclient -y"

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack_tag/presystem.tag
echo -e "\033[32m ##################################### \033[0m"
echo -e "\033[32m ##   Configure System Sucessed. ##### \033[0m"
echo -e "\033[32m ##################################### \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
sleep 10 

reboot







