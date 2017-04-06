
yum -y  install chrony ntp vim unzip wget  firewalld  createrepo
yum -y  install centos-release-openstack-ocata
yum -y  upgrade
yum install -y openstack-utils
yum -y  install python-openstackclient
yum -y  install openstack-selinux
yum -y  install mariadb mariadb-server python2-PyMySQL
yum -y  install rabbitmq-server
yum -y  install memcached python-memcached
yum -y  install openstack-keystone httpd mod_wsgi
yum -y  install openstack-glance
yum -y  install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler
yum -y  install openstack-nova-compute
yum -y install openstack-nova-placement-api
yum -y  install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables
  
yum -y  install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables  
  
yum -y  install openstack-dashboard
yum -y  install openstack-cinder
yum -y  install lvm2
yum -y  install openstack-cinder targetcli python-keystone
yum -y  install openstack-magnum-api openstack-magnum-conductor
yum -y  install openstack-trove python-troveclient

yum -y  install openstack-ceilometer-compute 

yum -y  install openstack-aodh-api \
  openstack-aodh-evaluator openstack-aodh-notifier \
  openstack-aodh-listener openstack-aodh-expirer \
  python-aodhclient
yum -y  install openstack-manila python-manilaclient

yum -y  install openstack-manila-share python2-PyMySQL
yum -y  install openstack-neutron openstack-neutron-linuxbridge ebtables
 yum -y  install lvm2 nfs-utils nfs4-acl-tools portmap  