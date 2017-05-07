#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
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

if [ -f  /etc/openstack-ocata_tag/install_neutron.tag ]
then 
	log_info "neutron have installed ."
else
	echo -e "\033[41;37m you should install neutron first. \033[0m"
	exit
fi
if [ -f  /etc/openstack-ocata_tag/install_dashboard.tag ]
then 
	echo -e "\033[41;37m you haved install dashboard \033[0m"
	log_info "you haved install dashboard."	
	exit
fi

#test network
function fn_test_network () {
if [ -f ${TOPDIR}/lib/proxy.sh ]
then 
	source  ${TOPDIR}/lib/proxy.sh
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

yum clean all &&  yum install openstack-dashboard  mod_ssl -y
fn_log "yum clean all &&  yum install openstack-dashboard  mod_ssl  -y"
KEY_DASHBOARD=`cat /etc/openstack-dashboard/local_settings | grep SECRET_KEY | grep "=" |awk -F "'" '{print$2}'`
[ -f /etc/openstack-dashboard/local_settings_bak ]  || cp -a /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings_bak
fn_log "[ -f /etc/openstack-dashboard/local_settings_bak ]  || cp -a /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings_bak"
rm -rf /etc/openstack-dashboard/local_settings 
cp -a    ${TOPDIR}/lib/local_settings /etc/openstack-dashboard/local_settings 
fn_log "cp -a ${TOPDIR}/lib/local_settings /etc/openstack-dashboard/local_settings"
unset http_proxy https_proxy ftp_proxy no_proxy  

sed -i "s/b33834f55a75361e80ef/${KEY_DASHBOARD}/g" /etc/openstack-dashboard/local_settings 
fn_log "sed -i "s/1772ea2eee780ff9a634/${KEY_DASHBOARD}/g" /etc/openstack-dashboard/local_settings"
sed -i  "s/controller/$HOSTNAME/g"  /etc/openstack-dashboard/local_settings
fn_log "sed -i  "s/controller/$HOSTNAME/g"  /etc/openstack-dashboard/local_settings"

systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service 
fn_log "systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service "

if [ -e /usr/lib/systemd/system/openstack-nova-compute.service  ]
then
	systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
	fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service "
fi

systemctl | grep nova | grep running | grep -v  mount | awk -F " " '{print$1}' | xargs systemctl restart
fn_log "systemctl | grep nova | grep running | grep -v  mount | awk -F " " '{print$1}' | xargs systemctl restart"

systemctl | grep neutron| grep running  | awk -F " " '{print$1}' | xargs systemctl restart
fn_log " systemctl | grep neutron| grep running  | awk -F " " '{print$1}' | xargs systemctl restart"


systemctl | grep cinder | grep running  | awk -F " " '{print$1}' | xargs systemctl restart
fn_log "systemctl | grep cinder | grep running  | awk -F " " '{print$1}' | xargs systemctl restart"
echo -e "\033[32m ############################################################################# \033[0m"
echo -e "\033[32m ###                     Install Openstack Dashboard                     ##### \033[0m"
echo -e "\033[32m ###       You can login openstack by http://${MANAGER_IP}/dashboard/    ##### \033[0m"
echo -e "\033[32m ############################################################################# \033[0m"
if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_dashboard.tag




	