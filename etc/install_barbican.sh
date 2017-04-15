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

if [ -f  /etc/openstack-ocata_tag/install_barbican.tag ]
then 
	echo -e "\033[41;37m you haved install barbican \033[0m"
	log_info "you haved install barbican."	
	exit
fi

#create barbican databases 

fn_create_database barbican ${ALL_PASSWORD}




unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/admin-openrc.sh 
fn_create_user barbican ${ALL_PASSWORD}
fn_log "fn_create_user barbican ${ALL_PASSWORD}"

openstack role add --project service --user barbican admin
fn_log "openstack role add --project service --user barbican admin"


fn_create_role creator
fn_log "fn_create_role creator"

openstack role add --project service --user barbican creator
fn_log "openstack role add --project service --user barbican creator"



fn_create_service barbican "Key Manager" key-manager
fn_log "fn_create_service barbican "Key Manager" key-manager"

fn_create_endpoint key-manager 9311
fn_log "fn_create_endpoint key-manager 9311"



yum clean all && yum install openstack-barbican-api *barbican* -y
fn_log "yum clean all && yum install openstack-barbican-api *barbican* -y"
unset http_proxy https_proxy ftp_proxy no_proxy 


cat <<END >/tmp/tmp
DEFAULT sql_connection   mysql+pymysql://barbican:${ALL_PASSWORD}@${MANAGER_IP}/barbican
DEFAULT transport_url   rabbit://openstack:${ALL_PASSWORD}@${MANAGER_IP}
keystone_authtoken auth_uri   http://${MANAGER_IP}:5000
keystone_authtoken auth_url   http://${MANAGER_IP}:35357
keystone_authtoken memcached_servers   ${MANAGER_IP}:11211
keystone_authtoken auth_type   password
keystone_authtoken project_domain_name   default
keystone_authtoken user_domain_name   default
keystone_authtoken project_name   service
keystone_authtoken username   barbican
keystone_authtoken password   ${ALL_PASSWORD}
DEFAULT host_href  http://${MANAGER_IP}:9311
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/barbican/barbican.conf
fn_log "fn_set_conf /etc/barbican/barbican.conf"


cat <<END >/tmp/tmp
pipeline:barbican_api pipeline  cors authtoken context apiapp
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/barbican/barbican-api-paste.ini
fn_log "fn_set_conf /etc/barbican/barbican-api-paste.ini"






su -s /bin/sh -c "barbican-manage db upgrade" barbican 
fn_log "su -s /bin/sh -c "barbican-manage db upgrade" barbican"

cat <<END >/etc/httpd/conf.d/wsgi-barbican.conf

<VirtualHost [::1]:9311>
    ServerName ${MANAGER_IP}

    ## Logging
    ErrorLog "/var/log/httpd/barbican_wsgi_main_error_ssl.log"
    LogLevel debug
    ServerSignature Off
    CustomLog "/var/log/httpd/barbican_wsgi_main_access_ssl.log" combined

    WSGIApplicationGroup %{GLOBAL}
    WSGIDaemonProcess barbican-api display-name=barbican-api group=barbican processes=2 threads=8 user=barbican
    WSGIProcessGroup barbican-api
    WSGIScriptAlias / "/usr/lib/python2.7/site-packages/barbican/api/app.wsgi"
    WSGIPassAuthorization On
</VirtualHost>
END
fn_log "set /etc/httpd/conf.d/wsgi-barbican.conf"
sleep 10

systemctl enable httpd.service && systemctl restart  httpd.service
fn_log "systemctl enable httpd.service && systemctl restart  httpd.service"

#openstack secret store --name mysecret --payload j4=]d21
#fn_log "openstack secret store --name mysecret --payload j4=]d21"




echo -e "\033[32m ################################################# \033[0m"
echo -e "\033[32m ###        Install barbican Sucessed         #### \033[0m"
echo -e "\033[32m ################################################# \033[0m"


if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_barbican.tag