一、网络拓扑及网卡配置

二、建议硬件配置：

```
controller
vcpu： 2+
内存：4G+
硬盘：10G+
computer
vcpu： 2+
内存：4G+
硬盘：10G+
block
vcpu： 1+
内存：2G+
硬盘：10G+ （多块）
```

否则在安装过程中会报一些服务起不来错误

三、安装各个节点的操作系统
1、使用CentOS-7-x86_64-Minimal-1708.iso（本地源为CentOS7.4的）
下载路径：

```
https://mirrors.tuna.tsinghua.edu.cn/centos/7.4.1708/isos/x86_64/CentOS-7-x86_64-Minimal-1708.iso
```



四、使用本地源方法
1、用ftp工具（如：filezilla）通过root用户将软件包CentOS7.4-Mini-queens上传到服务器/mnt下
软件包获取路径：

```
https://github.com/wuyeliang/CentOS7.4-Mini-queens
```

3、配置本地源配置文件
删除网络源

```
# cd /etc/yum.repos.d/ && mkdir bak_repo_bak && mv *.repo  bak_repo_bak
```

4、新建/etc/yum.repos.d/repo.repo并写入（必须命名为repo.repo，脚本判断本地源的依据）

```
# cat <<END >/etc/yum.repos.d/repo.repo
[repo]
name=repo
baseurl=file:///mnt/CentOS7.4-Mini-queens
gpgcheck=0
enabled=1
proxy=_none_
END
```

5、执行下列命令测试，有正常回显，如报错返回检查配置文件及文件路径是否正确。

```
# yum repolist
```

五、配置安装信息
1、用ftp工具（如：filezilla）通过root用户将本项目上传上传到服务器/root下
获取路径（注意切换到到queens分支）：

```
https://github.com/wuyeliang/install_openstack
```



2、修改./install_openstack/lib/installrc
解释：

```
Controller节点信息
HOST_NAME对应controller的主机名
MANAGER_IP第一块网卡IP，作为管理网
ALL_PASSWORD各个组件、数据库及dashboard用户密码
NET_DEVICE_NAME第二块网卡名称，虚拟机网卡绑定到该网卡上

NEUTRON_PUBLIC_NET为浮动IP网络的网段 ，即外出网络网段
PUBLIC_NET_GW为浮动IP网络的网关
PUBLIC_NET_START为浮动IP网络地址池的起始IP
PUBLIC_NET_END为浮动IP网络地址池的结束IP

SECOND_NET为系统第二块网卡的IP，用于绑定网桥，走虚拟机流量
NEUTRON_DNS为浮动IP网络的DNS
NEUTRON_PRIVATE_NET为demo租户的网络
PRIVATE_NET_GW为demo租户的网络网关
PRIVATE_NET_DNS为demo租户的网络DNS

BLOCK_CINDER_DISK新增一个空白的分区或磁盘用于配置cinder云硬盘（block节点）
可选：
CINDER_DISK新增一个空白的分区或磁盘用于配置cinder云硬盘（controller节点）
```


3、配置hosts文件,此处配个节点的信息。

```
# cat ./install_openstack/lib/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.130.70.72 queens
10.130.70.83 computer1
10.130.70.87 computer2
```


六、执行安装

```
# cd ./install_openstack
# bash main.sh
```

输入数字进入需要安装的节点，1表示安装controller，2表示安装computer节点，3表示安装block节点

1、安装controller节点
选择1，进入安装controller节点模式
输入数字1 ，Configure System Environment.
当出现下列回显表示安装配置成功

注意：安装Configure System Environment后会自动重启一次
重启后用root重新登录

```
# cd ~/install_openstack
# bash main.sh
```

输入数字2 Install Mariadb and Rabbitmq-server


输入数字 3  Install Keystone.


输入数字4  Install Glance..


输入数字5 Install Nova


输入数字6 Install Cinder


输入数字7 进入Install Neutron，


输入数字8 Install Dashboard


输入0退出脚本

2、安装computer节点服务
进入computer节点安装模式输入1，配置系统
：

输入2安装nova和neutron-agent服务，需要手动输入computer节点的第二块网卡名称用于走虚拟机流量

：

注意：如有多个computer节点请重复此章节操作即可
3、安装block节点服务
输入1进入配置系统
：

输入2进入安装cinder服务
：

注意：如有多个block节点请重复此章节操作即可

七、登录openstack及创建虚拟机
1、Dashboard安装成功后在浏览器中输入

```
http://eth0-IP/dashboard
```


登录用户名及密码
管理员用户：admin
普通用户：demo
密码：参见

```
/root/install_openstack/lib/lib/installrc
```




