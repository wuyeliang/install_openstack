yum -y install chrony ntp vim firewall net-tools  openstack-utils firewalld
yum -y install centos-release-openstack-newton
yum -y upgrade
yum -y update
yum -y install python-openstackclient
yum -y install openstack-selinux
yum -y install mariadb mariadb-server python2-PyMySQL
yum -y install rabbitmq-server
yum -y install memcached python-memcached
yum -y install openstack-keystone httpd mod_wsgi
yum -y install openstack-glance
yum -y install openstack-nova-api openstack-nova-conductor   openstack-nova-console openstack-nova-novncproxy   openstack-nova-scheduler
yum -y install openstack-nova-compute
yum -y install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables
yum -y install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables
yum -y install openstack-neutron-linuxbridge ebtables ipset
yum -y install openstack-dashboard
yum -y install openstack-cinder
yum -y install lvm2
yum -y install openstack-cinder targetcli python-keystone

 