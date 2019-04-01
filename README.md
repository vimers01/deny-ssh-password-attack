# deny-ssh-password-attack

Openwrt 自身没有对抗ssh破解的工具,为了使我们暴露在互联网的路由器更加安全,基于iptables编写了一个小脚本, 脚本通过crontab定时执行.

Openwrt does not have its own tools to combat SSH cracking. To make our Internet-exposed routers more secure, a small script based on iptables is written. The script is executed by crontab timing.

脚本的功能是读取 logread 中 ssh(50022端口) 和 luci (443端口) 的失败日志,对于失败次数超过10次的同一个IP,在Iptables 中增加一条封锁规则,并记录日志到 /tmp/DenyPwdHack.log .

操作步骤如下:

下载文件DenyPwdHack.sh , 以root登录，放在 /root/ 目录下, 然后执行 chmod u+x /root/DenyPwdHack.sh 在Openwrt增加以下 crontab 内容:

执行命令: crontab -e

然后贴入以下内容:   0 */3 * * * /root/DenyPwdHack.sh

每三个小时执行一次脚本.


