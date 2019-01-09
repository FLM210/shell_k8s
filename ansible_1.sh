#!/bin/bash
while :
do
	read -p "是否配置离线yum源(yes/no)：" yum
	if [ "$yum" != "yes" ]&&[ "$yum" != "no" ];then
		echo "please input yes or no"
	else
		break
	fi
done
if [ "$yum" == "yes" ];then
	tar -xf ./yum.tar.gz -C /opt/
	mkdir /etc/yum.repos.d/bak &>/dev/null
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak
	echo "原yum文件以备份至／etc/yum.repos.d/bak文件夹下"
	read -p "请输入　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　"
	cp ./k8s.repo /etc/yum.repos.d/
	yum makecache  &> /dev/null
	echo "yum源安装完成"
fi
while :
do
	read -p "是否安装ansible(yes/no)：" ansible：-yes
	if [ "$ansible" != "yes" ]&&[ "$ansible" != "no" ];then
		echo "please input yes or no"
	else
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
	read -p "请输入master节点地址：" master
	read -p "请输入时间服务器地址：" timeserver
	read -p "请输入etcd节点地址文件路径：" etcd
	read -p "请输入node节点地址文件路径：" node
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.s-master.example
	sed  -i "s/^master/$master/" /etc/ansible/example/hosts.s-master.example
	i=0
	for j in `cat $etcd`
	do
        	etcdadd["${i}"]=$j
        	let i++
	done
	l=$(($i))
	for n in ${etcdadd[@]}
	do
		sed -i "8a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.s-master.example 
		etcdnum=$((${etcdnum}+1))
	done
        m=0
        for n in `cat $node`
        do
                nodeadd["${m}"]=$n
                let m++
        done
        for n in ${nodeadd[@]}
        do
                sed -i "$((12+${l}))a $n" /etc/ansible/example/hosts.s-master.example 
        done

	sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.s-master.example
	\cp /etc/ansible/example/hosts.s-master.example /etc/ansible/hosts
	echo "参数设置完成，开始安装集群。"
	ansible-playbook /etc/ansible/90.setup.yml
	echo "安装完成，请刷新当前环境变量。" ;;
multi)
	read -p "请输入时间服务器地址：" timeserver
	read -p "请输入主master节点地址：" master_1
	read -p "请输入备master节点地址：" master_2 
	read -p "请输入etcd节点地址文件路径：" etcd
	read -p "请输入node节点地址文件路径：" node
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network
	read -p "请输入网卡名：" mac
	sed  -i "s/^backup/$master_2 LB_IF=\"$mac\" LB_ROLE=backup"/   /etc/ansible/example/hosts.m-masters.example
	sed  -i "s/^master/$master_1 LB_IF=\"$mac\" LB_ROLE=master"/   /etc/ansible/example/hosts.m-masters.example
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.m-masters.example
	sed  -i "10a $master_1" /etc/ansible/example/hosts.m-masters.example
	sed  -i "11a $master_2" /etc/ansible/example/hosts.m-masters.example
	i=0
	for j in `cat $node`
	do
        	nodeadd["${i}"]=$j
        	let i++
	done  
	for n in ${nodeadd[@]}
        do
                sed -i "17a $n" /etc/ansible/example/hosts.m-masters.example 
        done
	m=0
	for n in `cat $etcd`
	do
        	etcdadd["${m}"]=$n
        	let m++
	done
	for n in ${etcdadd[@]}
	do
		sed -i "8a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.m-masters.example 
		etcdnum=$((${etcdnum}+1))
	done
	sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.m-masters.example
	\cp /etc/ansible/example/hosts.m-masters.example /etc/ansible/hosts
	echo "参数设置完成，开始安装集群。"
	ansible-playbook /etc/ansible/90.setup.yml
	echo "安装完成，请刷新当前环境变量。" ;;
allinone)
    read -p "请输入集群地址：" master
    read -p "请输入时间服务器地址：" timeserver
    sed -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.allinone.example
    sed  -i "s/^master/$master/" /etc/ansible/example/hosts.allinone.example
    sed -i "8a $master "NODE_NAME=etcd1"" /etc/ansible/example/hosts.allinone.example
    sed -i "13a $master" /etc/ansible/example/hosts.allinone.example    
    read -p "请输入网络插件类型（calico, flannel, kube-router, cilium）：" network
    sed -i "s/CLUSTER_NETWORK=\"flannel\"/CLUSTER_NETWORK=\"$network\"/" /etc/ansible/example/hosts.s-master.example
	\cp /etc/ansible/example/hosts.allinone.example /etc/ansible/hosts  || echo "配置文件拷贝失败请退出程序" 
    echo "参数设置完成，开始安装集群(若配置文件拷贝失败请退出)。"
	ansible-playbook /etc/ansible/90.setup.yml
    echo "安装完成，请刷新当前环境变量。";;
esac
qeqweqwe