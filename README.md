# deny-ssh-password-attack

Openwrt 自身没有对抗ssh破解的工具,为了使我们暴露在互联网的路由器更加安全,基于iptables编写了一个小脚本, 脚本通过crontab定时执行.

Openwrt does not have its own tools to combat SSH cracking. To make our Internet-exposed routers more secure, a small script based on iptables is written. The script is executed by crontab timing.

脚本的功能是读取 logread 中 ssh(22端口) 和 luci (443端口) 的失败日志,对于失败次数超过10次的同一个IP,在Iptables 中增加一条封锁规则,并记录日志到 /tmp/DenyPwdHack.log .

操作步骤如下:

下载文件DenyPwdHack.sh , 以root登录，放在 /root/ 目录下, 然后执行 chmod u+x /root/DenyPwdHack.sh 在Openwrt增加以下 crontab 内容:

执行命令: crontab -e

然后贴入以下内容:   0 */3 * * * /root/DenyPwdHack.sh

每三个小时执行一次脚本.

脚本中的参数：

SSH_PORT=22
#是SSH的端口，请根据自己的实际情况填写，一般是22端口

Luci_Port=443
#是Luci的登录端口，请根据自己的实际情况填写，一般是80端口，如果采用https，一般是443端口

LOG_DEST=/tmp/DenyPwdHack.log
#日志的绝对路径，因为 /tmp文件系统从内存中开辟的，写到该文件系统速度快，对芯片也安全

LOG_KEY_WORD="auth\.info\s+sshd.*Failed password for|luci:\s+failed\s+login"
#日志关键字,每个关键字可以用"|"号隔开,支持awk的正则表达式

exclude_ip="192.168.|127.0.0.1"
#白名单IP可以用"|"号隔开,支持grep的正则表达式## 失败次数

Failed_times=10
#登录失败封锁IP的阈值
