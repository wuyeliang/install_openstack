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
if [ -f  /etc/openstack-ocata_tag/install_nova.tag ]
then 
	log_info "nova have installed ."
else
	echo -e "\033[41;37m you should install nova first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-ocata_tag/install_designate.tag ]
then 
	echo -e "\033[41;37m you had install designate \033[0m"
	log_info "you had install designate."	
	exit
fi

#create designate databases 
fn_create_database designate ${ALL_PASSWORD}
source /root/admin-openrc.sh
fn_create_user designate ${ALL_PASSWORD}
fn_log "fn_create_user designate ${ALL_PASSWORD}"



openstack role add --project service --user designate admin
fn_log "openstack role add --project service --user designate admin"

fn_create_service designate "DNS" dns
fn_log "fn_create_service designate "OpenStack Block Storage" volume"

fn_create_endpoint volume 9001 
fn_log "fn_create_endpoint volume 9001 "

yum clean all && yum install openstack-designate\* bind  -y
fn_log "yum clean all && yum install openstack-designate\* -y"

FIRST_ETH_IP=${MANAGER_IP}

cat <<END >>/etc/named.conf
options {
    ...
    allow-new-zones yes;
    request-ixfr no;
    recursion no;
};
key "designate" {
  algorithm hmac-md5;
  secret "OAkHNQy0m6UPcv55fiVAPw==";
};
controls {
  inet 127.0.0.1 port 953
    allow { 127.0.0.1; } keys { "designate"; };
};
END
fn_log "set /etc/named.conf "
rndc-confgen -a -k designate -c /etc/designate/rndc.key -r /dev/urandom
fn_log "rndc-confgen -a -k designate -c /etc/designate/rndc.key -r /dev/urandom"

systemctl enable named && systemctl restart named
fn_log "systemctl enable named && systemctl restart named"

cat <<END >/tmp/tmp
service:api api_host   0.0.0.0
service:api api_port   9001
service:api auth_strategy   keystone
service:api enable_api_v1   True
service:api enabled_extensions_v1   quotas, reports
service:api enable_api_v2   True
keystone_authtoken auth_host   ${MANAGER_IP}
keystone_authtoken auth_port   35357
keystone_authtoken auth_protocol   http
keystone_authtoken admin_tenant_name   service
keystone_authtoken admin_user   designate
keystone_authtoken admin_password   ${ALL_PASSWORD}
service:worker enabled   True
service:worker notify   True
storage:sqlalchemy connection   mysql+pymysql://designate:${ALL_PASSWORD}@${MANAGER_IP}/designate
END
fn_log "create /tmp/tmp "

fn_set_conf /etc/designate/designate.conf
fn_log "fn_set_conf /etc/designate/designate.conf" 

su -s /bin/sh -c "designate-manage database sync" designate 
fn_log "su -s /bin/sh -c "designate-manage database sync" designatee"

systemctl enable designate-central designate-api && systemctl start designate-central designate-api
fn_log "systemctl enable designate-central designate-api && systemctl start designate-central designate-api"


cat <<END >/etc/designate/pools.yaml
- name: default
  description: Default Pool

  attributes: {}
  ns_records:
    - hostname: ns1-1.example.org.
      priority: 1
  nameservers:
    - host: 127.0.0.1
      port: 53
  targets:
    - type: bind
      description: BIND9 Server 1
      masters:
        - host: 127.0.0.1
          port: 5354

      options:
        host: 127.0.0.1
        port: 53
        rndc_host: 127.0.0.1
        rndc_port: 953
        rndc_key_file: /etc/designate/rndc.key
END
fn_log "set /etc/designate/pools.yaml"

su -s /bin/sh -c "designate-manage pool update" designate
fn_log "su -s /bin/sh -c "designate-manage pool update" designate"

systemctl enable designate-worker designate-producer designate-mdns
fn_log "systemctl enable designate-worker designate-producer designate-mdns"

systemctl restart designate-worker designate-producer designate-mdns
fn_log "systemctl restart designate-worker designate-producer designate-mdns"

sleep 15


source /root/admin-openrc.sh && openstack dns service list
fn_log "source /root/admin-openrc.sh && openstack dns service list"
#source /root/demo-openrc && openstack zone create --email dnsmaster@example.com. example.com.
#fn_log "source /root/demo-openrc && openstack zone create --email dnsmaster@example.com. example.com."


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###       Install designate Sucessed        #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-ocata_tag ]
then 
	mkdir -p /etc/openstack-ocata_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-ocata_tag/install_designate.tag





