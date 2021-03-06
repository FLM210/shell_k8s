#!/bin/bash
echo `date +%Y_%m_%d:%k:%M` >> ./.var
check_ip() {
	n1=`echo $1|awk -F. '{print $1}'`
	n2=`echo $1|awk -F. '{print $2}'`
	n3=`echo $1|awk -F. '{print $3}'`
	n4=`echo $1|awk -F. '{print $4}'`
	if [ $n1 -ge 1 ]&&[ $n1 -lt 255 ]&&[ $n2 -ge 1 ]&&[ $n2 -lt 255 ]&&[ $n3 -ge 1 ]&&[ $n3 -lt 255 ]&&[ $n4 -ge 1 ]&&[ $n4 -lt 255 ];then
		export code=0
	else
		echo "请输入正确的IP地址"
		export code=1
	fi 2>/dev/null
}

var(){
	echo $1=$2 >> ./.var
}
if [ "$1" == "--retry" ];then
	ansible-playbook  /etc/ansible/90.setup.yml
	echo "集群重装完成"
	exit 0
elif [ "$1" == "--clean" ];then
	ansible-playbook  /etc/ansible/99.clean.yml
	echo "集群清除完成"
	exit 0
elif [ "$1" == "--addnew" ];then
	\cp /etc/ansible/hosts /etc/ansible/hosts.bak
	echo "当前集群配置备份完毕。"
	echo "检测当前运行模式中........." 
	for i in allinone masters smaster
	do
		cat /etc/ansible/hosts | grep $i &>/dev/null
        if [ $? -eq 0 ];then
            echo “mode is $i”
            break
        fi
	done

	if [ "$i" == "allinone" ];then	
		while : 
		do   
    		read -p "请输入需要增加节点的IP地址(如有多个请用空格分开)：" addnode   
    		check_ip $addnode
    		[ ${code} -eq 0 ] && break   
		done	
		for i in $addnode
		do
			sed -i "2a $i" /etc/ansible/hosts
		done
	elif  [ "$i" == "smaster" ];then
		while : 
		do   
    		read -p "请输入需要增加节点的IP地址(如有多个请用空格分开)：" addnode   
    		check_ip $addnode   
    		[ $code -eq 0 ] && break   
		done
		for i in $addnode
		do
			sed -i "2a $i" /etc/ansible/hosts
		done
	elif [ "$i" == "masters"];then
		while : 
		do   
    		read -p "请输入需要增加的Ｍaster节点地址(如有多个请用空格分开，若不增添请直接跳过)：" addmaster  
    		check_ip $addmaster
    		[ $code -eq 0 ] && break   
		done	

		while : 
		do   
    		rread -p "请输入需要增加节点的IP地址(如有多个请用空格分开，若不增添请直接跳过)：" addnode 
    		check_ip $addnode
    		[ $code -eq 0 ] && break   
		done		
		
		if [ -z $addmaster ];then
			echo "未更改Master信息"
		else
			for i in $addmaster
			do
				sed -i "2a $i" /etc/ansible/hosts
			done
		fi
		if [ -z $addnode ];then
			echo "未更改node信息"
		else
			for i in $addnode
			do
				sed -i "4a $i" /etc/ansible/hosts
			done
		fi
	fi



	while :
	do
		read -p "节点添加完成，是否进行安装(yes/no)：" complete
		if [ "$complete" != "yes" ]&&[ "$complete" != "no" ];then
		echo "please input yes or no"
		else
			break
		fi
	done
	if [ "$complete" == "yes" ];then 
		if [ -z $addmaster ];then
			echo
		else
			scp /etc/yum.repos.d/*.repo  root@$addmaster:/etc/yum.repos.d/ 
			echo "开始添加Master节点"
			ansible-playbook /etc/ansible/21.addmaster.yml
		fi
		if [ -z $addnode ];then
			echo
		else
			echo "开始添加node节点"
			scp /etc/yum.repos.d/*.repo  root@$addmaster:/etc/yum.repos.d/
			ansible-playbook /etc/ansible/20.addnode.yml
			exit 0
		fi
	else
		echo "集群信息已保存"
		exit 88
	fi 
fi

echo "解压资源中请稍等。"
mkdir /etc/ansible &>/dev/null
tar -xf ./k8s.tar.gz -C /etc/ansible
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
	while true;
	do
		read -p "请输入集群yum源主机地址：" httpd
		check_ip $httpd
		[ $code -eq 0 ] && break
	done
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
	yum -y install ansible	&&  echo "ansible安装完成"  ||  echo "ansible安装失败请尝试手动安装"
fi

etcdnum=1 
read -p "请输入集群安装方式（single/multi,allinone）:" type
case $type in 
single)
	var type $type
        while true;
        do
            read -p "请输入master节点地址：" master
            n=0
            for ip in $master;do
                check_ip $ip
                n=$(( ${code} + $n ))
            done
            [ $n -eq 0 ] && break || continue
        done
	
	    while true;
        do
            read -p "请输入时间服务器地址：" timeserver  
			check_ip $timeserver
        	[ ${code} -eq 0 ] && break || continue
        done
	  
        while true;
        do
            read -p "请输入etcd节点地址(如有多个请用空格分开)：" etcd
            n=0
            for ip in $etcd;do
                check_ip $ip
                n=$(( ${code} + $n ))
            done
            [ $n -eq 0 ] && break || continue
        done 
	 
	    while true;
        do
            read -p "请输入node节点地址(如有多个请用空格分开)：" node 
            n=0
            for ip in $node;do
                check_ip $ip
                n=$(( ${code} + $n ))
            done
            [ $n -eq 0 ] && break || continue
        done 
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network   
	var master $master
	var timeserver $timeserver
	var etcd $etcd
	var node $node
	var network $network
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.s-master.example
	sed  -i "s/^master/$master/" /etc/ansible/example/hosts.s-master.example
	for n in $node
    do
        sed -i "15a $n" /etc/ansible/example/hosts.s-master.example 
    done
	for n in $etcd
	do
		sed -i "12a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.s-master.example 
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
		while true;
		do
			read -p "请输入时间服务器地址：" timeserver  
			check_ip $timeserver
			[ ${code} -eq 0 ] && break || continue
		done

		while true;
		do
			read -p "请输入master节点地址(主节点写第一位，用空格隔开)：" master
			n=0
			for ip in $master;do
				check_ip $ip
				n=$(( ${code} + $n ))
			done
			[ $n -eq 0 ] && break || continue
		done 

		while true;
		do
			read -p "请输入etcd节点地址(如有多个请用空格分开)：" etcd
			n=0
			for ip in $etcd;do
				check_ip $ip
				n=$(( ${code} + $n ))
			done
			[ $n -eq 0 ] && break || continue
		done 
	
	    while true;
        do
            read -p "请输入node节点地址(如有多个请用空格分开)：" node 
            n=0
            for ip in $node;do
                check_ip $ip
                n=$(( ${code} + $n ))
            done
            [ $n -eq 0 ] && break || continue
        done 
	read -p "请输入网络插件（calico, flannel, kube-router, cilium）：" network
	read -p "请输入网卡名：" mac
	var master $master
	var timeserver $timeserver
	var etcd $etcd
	var node $node
	var network $network
	var mac $mac
	master_num=1
	sed  -i "s/192.168.1.1 NTP_ENABLED=no/$timeserver NTP_ENABLED=no/" /etc/ansible/example/hosts.m-masters.example
	for n in $node
    do
        sed -i "23a $n" /etc/ansible/example/hosts.m-masters.example 
    done
	for n in $master
	do
		if [ $master_num -eq 1 ];then
			sed -i "19a $n LB_IF=$mac LB_ROLE=master" /etc/ansible/example/hosts.m-masters.example
			master_num=$(($master_num+1))
		else
			sed -i "19a $n LB_IF=$mac LB_ROLE=backup" /etc/ansible/example/hosts.m-masters.example
			master_num=$(($master_num+1))
		fi
	done
	for n in $master
	do
		sed -i "16a $n" /etc/ansible/example/hosts.m-masters.example
	done
	for n in $etcd
	do
		sed -i "14a $n "NODE_NAME=etcd${etcdnum}"" /etc/ansible/example/hosts.m-masters.example 
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
	while true;
	do
		read -p "请输入时间服务器地址：" timeserver  
		check_ip $timeserver
		[ ${code} -eq 0 ] && break || continue
	done
	while true;
	do
		read -p "请输入集群地址：" master
		check_ip $master
		[ ${code} -eq 0 ] && break || continue
	done
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
