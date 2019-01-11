#!/bin/bash

var(){
	echo $1=$2 >> ./.var
}
if [ "$1" == "--retry" ];then
	ansible-playbook  /etc/ansible/90.setup.yml
elif [ "$1" == "--clean" ];then
	ansible-playbook  /etc/ansible/99.clean.yml
fi

if [ -f ./.var ];then
	while :
	do
		read -p "是否加载上次配置：" reload
		if [ "$reload" != "yes" ]&&[ "$reload" != "no" ];then
			echo "please input yes or no"
		fi
			break
	done

	if [ "$reload" == "yes" ];then
		source  ./.var 　&& echo "配置文件加载成功，大国喝瓶阔落，一路回车is ok" 
	fi
else
	echo "配置文件不存在，无法重新加载上次配置，请手动输入参数"
fi

echo "解压资源中请稍等。"
mkdir /etc/ansible &>/dev/null
tar -xf ./sh_install.tar.gz -C /etc/ansible
while :
do
	read -p "是否配置离线yum源(yes/no)：" yum
	if [ "$yum" != "yes" ]&&[ "$yum" != "no" ];then
		echo "please input yes or no"
	else
		var yum $yum
		break
	fi
done
if [ "$yum" == "yes" ];then
	tar -xf ./yum.tar.gz -C /opt/
	mkdir /etc/yum.repos.d/bak &>/dev/null
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak
	echo "原yum文件备份至／etc/yum.repos.d/bak文件夹下"
	\cp /etc/ansible/example/k8s.repo /etc/yum.repos.d/
	read -p "请输入集群yum源主机地址："　httpd
	var httpd $httpd
	yum -y install httpd &> /dev/null
	systemctl start httpd
	ln -s /opt/yum /var/www/html/
	sed -i "3c baseurl=http://$httpd/yum" /etc/ansible/example/k8s.repo	
	yum clean all  &> /dev/null
	echo "yum源安装完成"
fi

while :
do
	read -p "是否安装ansible(yes/no)：" ansible
	if [ "$ansible" != "yes" ]&&[ "$ansible" != "no" ];then
		echo "please input yes or no"
	else
		var ansible $ansible
		break
	fi
done
if [ "$ansible" == "yes" ];then
	yum -y install ansible	&&  echo "ansible安装完成" 　||  echo "ansible安装失败请尝试手动安装"
fi

etcdnum=1 
read -p "请输入集群安装方式（single/multi,allinone）:" type
case $type in 
single)
	var type $type
	read -p "请输入master节点地址：" master  
	read -p "请输入时间服务器地址：" timeserver  
	read -p "请输入etcd节点地址(如有多个请用空格分开)：" etcd   
	read -p "请输入node节点地址(如有多个请用空格分开)：" node  
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network   
	var master $master
	var timeserver $timeserver
	var etcd $etcd
	var node $node
	var network $network
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.s-master.example
	sed  -i "s/^master/$master/" /etc/ansible/example/hosts.s-master.example
	for n in $nodeadd
    do
        sed -i "$12a $n" /etc/ansible/example/hosts.s-master.example 
    done
　　 for n in $etcdadd
	do
		sed -i "8a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.s-master.example 
		etcdnum=$((${etcdnum}+1))
	done
	sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.s-master.example
	\cp /etc/ansible/example/hosts.s-master.example /etc/ansible/hosts
	echo "参数设置完成，开始安装集群。"
	ansible all -m shell -a 'rm -rf /etc/yum.repos.d/*.repo' &>/dev/null
	ansible all -m copy -a  'src=/etc/ansible/example/k8s.repo dest=/etc/yum.repos.d/' &>/dev/null 
	ansible-playbook /etc/ansible/90.setup.yml
	echo "安装完成，请刷新当前环境变量。" ;;


multi)
	var type $type
	read -p "请输入时间服务器地址：" timeserver
	read -p "请输入主master节点地址：" master_1
	read -p "请输入备master节点地址：" master_2 
	read -p "请输入etcd节点地址文件路径：" etcd
	read -p "请输入node节点地址文件路径：" node
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network
	read -p "请输入网卡名：" mac
	var master_1 $master_1
	var master_2 $master_2
	var timeserver $timeserver
	var etcd $etcd
	var node $node
	var network $network
	var mac $mac
	sed  -i "s/^backup/$master_2 LB_IF=\"$mac\" LB_ROLE=backup"/   /etc/ansible/example/hosts.m-masters.example
	sed  -i "s/^master/$master_1 LB_IF=\"$mac\" LB_ROLE=master"/   /etc/ansible/example/hosts.m-masters.example
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.m-masters.example
	sed  -i "10a $master_1" /etc/ansible/example/hosts.m-masters.example
	sed  -i "11a $master_2" /etc/ansible/example/hosts.m-masters.example 
	for n in $nodeadd
    do
        sed -i "17a $n" /etc/ansible/example/hosts.m-masters.example 
    done
	for n in $etcdadd
	do
		sed -i "8a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.m-masters.example 
		etcdnum=$((${etcdnum}+1))
	done
	sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.m-masters.example
	\cp /etc/ansible/example/hosts.m-masters.example /etc/ansible/hosts
	echo "参数设置完成，开始安装集群。"
	ansible all -m shell -a 'rm -rf /etc/yum.repos.d/*.repo' &>/dev/null
	ansible all -m copy -a  'src=/etc/ansible/example/k8s.repo dest=/etc/yum.repos.d/' &>/dev/null 
	ansible-playbook /etc/ansible/90.setup.yml
	echo "安装完成，请刷新当前环境变量。" ;;


allinone)
	var type $type
    read -p "请输入集群地址：" master
    read -p "请输入时间服务器地址：" timeserver
	read -p "请输入网络插件类型（calico, flannel, kube-router, cilium）：" network
	var master $master
	var timeserver $timeserver
	var network $network
    sed -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.allinone.example
    sed  -i "s/^master/$master/" /etc/ansible/example/hosts.allinone.example
    sed -i "8a $master "NODE_NAME=etcd1"" /etc/ansible/example/hosts.allinone.example
    sed -i "13a $master" /etc/ansible/example/hosts.allinone.example       
    sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.s-master.example
	\cp /etc/ansible/example/hosts.allinone.example /etc/ansible/hosts  || echo "配置文件拷贝失败请退出程序" 
    echo "参数设置完成，开始安装集群(若配置文件拷贝失败请退出)。"
	ansible all -m shell -a 'rm -rf /etc/yum.repos.d/*.repo' &>/dev/null
	ansible all -m copy -a  'src=/etc/ansible/example/k8s.repo dest=/etc/yum.repos.d/' &>/dev/null 
	ansible-playbook /etc/ansible/90.setup.yml
    echo "安装完成，请刷新当前环境变量。";;
esac
