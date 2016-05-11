#!/bin/bash
INSTALL_PATH=$PWD
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
0) Quit
EOF

read -p "please input one number for install :" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input is number."
else
	echo "please input one right number[0-3]"
	log_info "input is string."
	fn_install_openstack_controller
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-3]"
	fn_install_openstack_controller
elif [ ${install_number}  -eq 1 ]
then
	/bin/bash $PWD/etc/presystem.sh
	log_info "/bin/bash $PWD/etc/presystem.sh."
elif  [ ${install_number}  -eq 2 ]
then
	/bin/bash $PWD/etc/install_mariadb.sh
	log_info "/bin/bash $PWD/etc/install_mariadb.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 3 ]
then
	/bin/bash $PWD/etc/config-keystone.sh
	log_info "/bin/bash $PWD/etc/config-keystone.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 4 ]
then
	/bin/bash $PWD/etc/install_glance.sh
	log_info "/bin/bash $PWD/etc/install_glance.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 5 ]
then
	/bin/bash $PWD/etc/install_nova.sh  
	log_info "/bin/bash $PWD/etc/install_nova.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 6 ]
then
	/bin/bash $PWD/etc/install_cinder.sh
	log_info "/bin/bash $PWD/etc/install_cinder.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 7 ]
then
	/bin/bash $PWD/etc/install_neutron_two.sh
	log_info "/bin/bash $PWD/etc/install_neutron_one.sh"
	fn_install_openstack_controller
	elif  [ ${install_number}  -eq 8 ]
then
	/bin/bash ${INSTALL_PATH}/etc/install_dashboard.sh
	log_info "/bin/bash $PWD/etc/install_dashboard.sh."
	fn_install_openstack_controller
elif  [ ${install_number}  -eq 0 ]
then 
    log_info "exit intalll."
	fn_install_openstack
else 
     echo "please input one right number[0-3]"
	 fn_install_openstack_controller
fi
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
		/usr/bin/bash ./etc/liberty-computer_system.sh
		fn_log "/usr/bin/bash ./etc/liberty-computer_system.sh"
		fn_install_openstack_computer
	;;
	2)
		/usr/bin/bash ./etc/liberty-computer_install.sh
		fn_log "/usr/bin/bash ./etc/liberty-computer_install.sh"
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


function fn_install_openstack ()
{
cat << EOF
1) Install Controller Node Service.
2) Install Computer Node Service.
3) Install Block Node Service (Cinder).
4) Install Network Node Service.
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
		fn_install_openstack_network
		fn_log "fn_install_openstack_network"
		fn_install_openstack_network
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

function  fn_install_openstack_network () {

cat << EOF
1) Configure System Environment.
2) Install Neutron Service.
0) Quit
EOF
read -p "please input one number for install :" install_number
case ${install_number} in
	1)
		/usr/bin/bash ./etc/liberty-network_system.sh
		fn_log "/usr/bin/bash ./etc/liberty-network_system.sh"
		fn_install_openstack_network
	;;
	2)
		/usr/bin/bash ./etc/liberty-network-neutron.sh
		fn_log "/usr/bin/bash ./etc/liberty-network-neutron.sh"
		fn_install_openstack_network
	;;
	0)
		fn_install_openstack
	;;
	*)
		echo -e "\033[41;37m please input one number. \033[0m"
		fn_install_openstack_network
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
		/usr/bin/bash ./etc/liberty-block_storage_system.sh
		fn_log "/usr/bin/bash ./etc/liberty-block_storage_system.sh"
		fn_install_openstack_block
	;;
	2)
		/usr/bin/bash ./etc/liberty-block_install.sh
		fn_log "/usr/bin/bash ./etc/liberty-block_install.sh"
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

