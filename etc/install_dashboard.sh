#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
if [  -e $PWD/lib/liberty-log.sh ]
then	
	source $PWD/lib/liberty-log.sh
else
	echo -e "\033[41;37m $PWD/liberty-log.sh is not exist. \033[0m"
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

if [  -e /etc/openstack-liberty_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-liberty_tag/install_neutron.tag ]
then 
	log_info "neutron have installed ."
else
	echo -e "\033[41;37m you should install neutron first. \033[0m"
	exit
fi
if [ -f  /etc/openstack-liberty_tag/install_dashboard.tag ]
then 
	echo -e "\033[41;37m you haved install dashboard \033[0m"
	log_info "you haved install dashboard."	
	exit
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

yum clean all &&  yum install openstack-dashboard httpd mod_wsgi memcached pythonmemcached -y
rm -rf /etc/openstack-dashboard/local_settings 
cp -a    $PWD/lib/local_settings /etc/openstack-dashboard/local_settings 
fn_log "cp -a $PWD/lib/local_settings /etc/openstack-dashboard/local_settings"
unset http_proxy https_proxy ftp_proxy no_proxy  



chown -R apache:apache /usr/share/openstack-dashboard/static
fn_log "chown -R apache:apache /usr/share/openstack-dashboard/static"
systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service 
fn_log "systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service "

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service "

sed -i  "s/controller/$HOSTNAME/g"  /etc/openstack-dashboard/local_settings
echo -e "\033[32m ############################################################################# \033[0m"
echo -e "\033[32m ###                     Install Openstack Dashboard                     ##### \033[0m"
echo -e "\033[32m ###       You can login openstack by http://${MANAGER_IP}/dashboard/    ##### \033[0m"
echo -e "\033[32m ############################################################################# \033[0m"
if  [ ! -d /etc/openstack-liberty_tag ]
then 
	mkdir -p /etc/openstack-liberty_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-liberty_tag/install_dashboard.tag




	