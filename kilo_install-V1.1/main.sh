#!/bin/bash
INSTALL_PATH=$PWD
function log_info ()
{
if [  -d /var/log  ]
then
	mkdir -p /var/log
fi

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
USER_N=`whoami`

if  [ ${USER_N}  = root ]
then 
	log_info "execute by root. "
else
	log_error "execute by ${USER_N}"
	echo -e "\033[41;37m you must execute this scritp by root. \033[0m"
	exit
fi

function fn_install_openstack ()
{
cat << EOF
1) config Basic environment.
2) install mariadb and rabbitmq-server.
3) install keystone.
4) install glance.
5) install nova.
6) install cinder.
7) install neutron.
8) install dashboard.
0) quit
EOF

read -p "please input one number for install :" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input is number."
else
	echo "please input one right number[0-3]"
	log_info "input is string."
	fn_install_openstack
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-3]"
	fn_install_openstack
elif [ ${install_number}  -eq 1 ]
then
	/bin/bash $PWD/etc/presystem.sh
	log_info "/bin/bash $PWD/etc/presystem.sh."
elif  [ ${install_number}  -eq 2 ]
then
	/bin/bash $PWD/etc/install_mariadb.sh
	log_info "/bin/bash $PWD/etc/install_mariadb.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 3 ]
then
	/bin/bash $PWD/etc/config-keystone.sh
	log_info "/bin/bash $PWD/etc/config-keystone.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 4 ]
then
	/bin/bash $PWD/etc/install_glance.sh
	log_info "/bin/bash $PWD/etc/install_glance.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 5 ]
then
	/bin/bash $PWD/etc/install_nova.sh  
	log_info "/bin/bash $PWD/etc/install_nova.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 6 ]
then
	/bin/bash $PWD/etc/install_cinder.sh
	log_info "/bin/bash $PWD/etc/install_cinder.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 7 ]
then
	fn_install_neutron
	log_info "/bin/bash $PWD/etc/install_neutron.sh."
	fn_install_openstack
	elif  [ ${install_number}  -eq 8 ]
then
	/bin/bash ${INSTALL_PATH}/etc/install_dashboard.sh
	log_info "/bin/bash $PWD/etc/install_dashboard.sh."
	fn_install_openstack
elif  [ ${install_number}  -eq 0 ]
then 
     log_info "exit intalll."
	log_info "exit intalll."
	 exit 
else 
     echo "please input one right number[0-3]"
	 fn_install_openstack
fi
}

function fn_install_neutron () {
cat << EOF
1) install neutron for one net
2) install neutron for two net
0) quit
EOF
read -p "please input one number for install :" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input is number."
else
	echo "please input one right number[0-3]"
	log_info "input is string."
	fn_install_neutron
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-3]"
	fn_install_neutron
elif [ ${install_number}  -eq 1 ]
then
	/bin/bash $PWD/etc/install_neutron_one.sh
	log_info "/bin/bash $PWD/etc/install_neutron_one.sh"
	fn_install_neutron
elif [ ${install_number}  -eq 2 ]
then
	/bin/bash $PWD/etc/install_neutron_two.sh
	log_info "/bin/bash $PWD/etc/install_neutron_one.sh"
	fn_install_neutron
elif  [ ${install_number}  -eq 0 ]
then 
     log_info "exit intall."
	log_info "exit intall."
	fn_install_openstack
else 
     echo "please input one right number[0-3]"
	 fn_install_neutron
fi
}

fn_install_openstack