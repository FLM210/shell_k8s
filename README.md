# ansible
傻瓜式搭建Ｋ８Ｓ集群

本人只是在大佬的基础上套了一个壳　
大佬地址：https://github.com/gjmzj/kubeasz/
侵删

安装步骤：
运行　install.sh 根据提示输入相关参数即可，无需对机器进行任何配置（为防止出错建议手动关闭ｓｅｌｉｎｕｘ与防火墙）

若第一次安装安装失败可进行重试　在终端输入　./install.sh  restry　即可

若想清除集群在终端输入 ./install.sh  clean即可

若存在节点过多可运行ansible_1.sh，须把各节点地址写入一个文件中（ansible_1.sh暂不支持读取上次配置参数）

文件格式为每个ＩＰ地址单独占一行即可。
