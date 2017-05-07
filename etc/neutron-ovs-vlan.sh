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



#vlan config
#controller node

function fn_config_controller () {
cat <<END >/tmp/tmp
ml2 type_drivers  flat,vlan,gre,vxlan
ml2 tenant_network_types  vlan
ml2_type_vlan network_vlan_ranges  physnet1:1000:2999
END
fn_log "create /tmp/tmp "


fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"

systemctl restart neutron-server 
fn_log "systemctl restart neutron-server"

}


#netwok and computer node 
function fn_config_computer_network () {
NET_INT=`ip add | grep br-vlan   | wc -l `
if [ ${NET_INT} -eq 0  ] 
then
	ovs-vsctl add-br br-vlan 
	fn_log "ovs-vsctl add-br br-int"
	ovs-vsctl add-port br-vlan $1 
	fn_log "ovs-vsctl add-port br-vlan $1 "
fi

cat <<END >/tmp/tmp
ml2 type_drivers  flat,vlan,gre,vxlan
ml2 tenant_network_types  vlan
ml2_type_vlan network_vlan_ranges  physnet1:1000:2999
END
fn_log "create /tmp/tmp "


fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"

cat <<END >/tmp/tmp
ml2 type_drivers  flat,vlan,gre,vxlan
ml2 tenant_network_types  vlan
ml2_type_vlan network_vlan_ranges  physnet1:1000:2999
END
fn_log "create /tmp/tmp "


fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/ml2_conf.ini"



cat <<END >/tmp/tmp
ovs bridge_mappings  physnet1:br-vlan
END
fn_log "create /tmp/tmp "
fn_set_conf /etc/neutron/plugins/ml2/openvswitch_agent.ini
fn_log "fn_set_conf /etc/neutron/plugins/ml2/openvswitch_agent.ini"

systemctl restart neutron-openvswitch-agent 
fn_log "systemctl restart neutron-openvswitch-agent "

}

#network node
function fn_config_network () {
NET_INT=`ip add | grep br-ext   | wc -l `
if [ ${NET_INT} -eq 0  ] 
then
	ovs-vsctl add-br br-ext 
	fn_log "ovs-vsctl add-br br-int"

fi

ovs-vsctl  show | grep Interface | grep ${NET_DEVICE_NAME}
if [ $? -eq 0   ]
then	
	log_info " ${NET_DEVICE_NAME} have been added."
else
	ovs-vsctl add-port br-ext ${NET_DEVICE_NAME} 
	fn_log "ovs-vsctl add-port br-ext ${NET_DEVICE_NAME} "
fi


cat <<END >/tmp/tmp
DEFAULT  external_network_bridge  br-ext
END
fn_log "create /tmp/tmp "
fn_set_conf /etc/neutron/l3_agent.ini
fn_log "fn_set_conf /etc/neutron/l3_agent.ini"



systemctl restart neutron-l3-agent 
fn_log "systemctl restart neutron-l3-agent "

}


function fn_config_vlan_main () {
if [ -e /etc/openstack-ocata_tag/controller_neutron.tag ]
then
	fn_config_controller
fi



if  [ -e /etc/openstack-ocata_tag/network_neutron.tag ] 
then 
	fn_config_computer_network ${EXT_NET_DEVICE}
	fn_log "fn_config_computer_network ${EXT_NET_DEVICE}"
	fn_config_network
	fn_log "fn_config_network"
fi 


if  [ -e /etc/openstack-ocata_tag/computer_neutron.tag ] 
then 
	fn_config_computer_network ${DEV_NETWORK}
	fn_log "fn_config_computer_network ${DEV_NETWORK} "
fi 
}



