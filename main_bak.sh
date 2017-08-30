#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
TOPDIR=$(cd $(dirname "$0") && pwd)
export TOPDIR
INSTALL_PATH=${TOPDIR}
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
USER_N=`whoami`

if  [ ${USER_N}  = root ]
then 
	log_info "execute by root. "
else
	log_error "execute by ${USER_N}"
	echo -e "\033[41;37m you must execute this scritp by root. \033[0m"
	exit
fi

function fn_install_openstack_controller ()
{
cat << EOF
1) Configure System Environment.
2) Install Mariadb and Rabbitmq-server.
3) Install Keystone.
4) Install Glance.
5) Install Nova.
6) Install Cinder.
7) Install Neutron.
8) Install Dashboard.
9) Install Manila.
10) Install Heat.
11) Install Key Manager service.
12) Install Trove.
13) Install Magnum.
14) Install Swift.
0) Quit
EOF



read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		/bin/bash ${TOPDIR}/etc/presystem.sh
		log_info "/bin/bash ${TOPDIR}/etc/presystem.sh."
		fn_install_openstack_controller
	;;
	2)
		/bin/bash ${TOPDIR}/etc/install_mariadb.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_mariadb.sh."
		fn_install_openstack_controller
	;;
	3)
		/bin/bash ${TOPDIR}/etc/config-keystone.sh
		log_info "/bin/bash ${TOPDIR}/etc/config-keystone.sh."
		fn_install_openstack_controller
	;;
	4)
		/bin/bash ${TOPDIR}/etc/install_glance.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_glance.sh."
		fn_install_openstack_controller
	;;
	5)
		/bin/bash ${TOPDIR}/etc/install_nova.sh  
		log_info "/bin/bash ${TOPDIR}/etc/install_nova.sh."
		fn_install_openstack_controller
	;;
	6)
		/bin/bash ${TOPDIR}/etc/install_cinder.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_cinder.sh."
		fn_install_openstack_controller
	;;
	7)
		/bin/bash $PWD/etc/install_neutron.sh
		log_info "/bin/bash $PWD/etc/install_neutron.sh"
		fn_install_openstack_controller
	;;
	8)
		/bin/bash ${INSTALL_PATH}/etc/install_dashboard.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_dashboard.sh."
		fn_install_openstack_controller
	;;
	9)
		/bin/bash ${INSTALL_PATH}/etc/install_manila.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_manila.sh."
		fn_install_openstack_controller	
	;;
	10)
		/bin/bash ${INSTALL_PATH}/etc/install_heat.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_heat.sh."
		fn_install_openstack_controller
	;;
	11)
		/bin/bash ${INSTALL_PATH}/etc/install_barbican.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_barbican.sh."
		fn_install_openstack_controller
	;;
	12)
		/bin/bash ${INSTALL_PATH}/etc/install_trove.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_trove.sh."
		fn_install_openstack_controller
	;;
	13)
		/bin/bash ${INSTALL_PATH}/etc/install_magnum.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_magnum.sh."
		fn_install_openstack_controller
	;;
	14)
		/bin/bash ${INSTALL_PATH}/etc/install_swift.sh
		log_info "/bin/bash ${TOPDIR}/etc/install_swift.sh."
		fn_install_openstack_controller
	;;
	0)
		exit 1
	;;
	*)
		echo -e "\033[41;37m please input one right number. \033[0m"
		fn_install_openstack_controller
	;;
esac 
}



function fn_install_openstack_computer ()
{
cat << EOF
1) Configure System Environment.
2) Install Computer Service.
0) Quit
EOF
read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		/usr/bin/bash ./etc/openstack-computer_system.sh
		fn_log "/usr/bin/bash ./etc/openstack-computer_system.sh"
		fn_install_openstack_computer
	;;
	2)
		/usr/bin/bash ./etc/openstack-computer_install.sh
		fn_log "/usr/bin/bash ./etc/openstack-computer_install.sh"
		fn_install_openstack_computer
	;;
	0)
		fn_install_openstack
	;;
	*)
		echo -e "\033[41;37m please input one number. \033[0m"
		fn_install_openstack_computer
	;;
esac 

}




function fn_install_openstack_swift () {
cat << EOF
1) Configure System Environment.(swift node)
2) Install siwft Service.(swift node)
3) Initial rings(controller node)
0) Quit
EOF
read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		/usr/bin/bash ./etc/openstack-block_storage_system.sh
		fn_log "/usr/bin/bash ./etc/openstack-block_storage_system.sh"
		fn_install_openstack_swift
	;;
	2)
		/usr/bin/bash ./etc/node-swift.sh
		fn_log "/usr/bin/bash ./etc/node-swift.sh"
		fn_install_openstack_swift
	;;
	3)
		/usr/bin/bash ./etc/create-initial-rings.sh
		fn_log "/usr/bin/bash ./etc/create-initial-rings.sh"
		fn_install_openstack_swift
	;;
	0)
		fn_install_openstack
	;;
	*)
		echo -e "\033[41;37m please input one number. \033[0m"
		fn_install_openstack_swift
	;;
esac 

}


function fn_install_openstack ()
{
cat << EOF
1) Install Controller Node Service.
2) Install Computer Node Service.
3) Install Block Node Service (Cinder).
4) Install Storage Node Service.
0) Quit
EOF
read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		fn_install_openstack_controller
		fn_log "fn_install_openstack_controller"
		fn_install_openstack_controller
	;;
	2)
		fn_install_openstack_computer
		fn_log "fn_install_openstack_computer"
		fn_install_openstack_computer
	;;
	3)
		fn_install_openstack_block
		fn_log "fn_install_openstack_block"
		fn_install_openstack_block
	;;

	4)
		fn_install_openstack_swift
		fn_log "fn_install_openstack_swift"
		fn_install_openstack_swift
	;;
	0)
		exit 1
	;;
	*)
		echo -e "\033[41;37m please input one number. \033[0m"
		fn_install_openstack
	;;
esac 

}



function fn_install_openstack_block () {
cat << EOF
1) Configure System Environment.
2) Install Block Service.
0) Quit
EOF
read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		/usr/bin/bash ./etc/openstack-block_storage_system.sh
		fn_log "/usr/bin/bash ./etc/openstack-block_storage_system.sh"
		fn_install_openstack_block
	;;
	2)
		/usr/bin/bash ./etc/openstack-block_install.sh
		fn_log "/usr/bin/bash ./etc/openstack-block_install.sh"
		fn_install_openstack_block
	;;
	0)
		fn_install_openstack
	;;
	*)
		echo -e "\033[41;37m please input one number. \033[0m"
		fn_install_openstack_block
	;;
esac 

}





fn_install_openstack

