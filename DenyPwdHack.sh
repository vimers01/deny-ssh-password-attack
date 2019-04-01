ChainName=DenyPwdHack
SSH_PORT=50022
Luci_Port=443
LOG_DEST=/tmp/DenyPwdHack.log
INPUT_RULE="INPUT -p tcp -m multiport --dports $SSH_PORT,$Luci_Port -j $ChainName"
## 日志关键字,每个关键字可以用"|"号隔开,支持grep的正则表达式
LOG_KEY_WORD="auth\.info\s+sshd.*Failed password for|luci:\s+failed\s+login"
## 白名单IP可以用"|"号隔开,支持grep的正则表达式
exclude_ip="192.168.|127.0.0.1"
## 失败次数
Failed_times=10

## 判断链是否存在
iptables --list $ChainName > /dev/null 2>&1
if [[ $? == 1 ]] ; then
	iptables -N $ChainName
	echo '['`date +%Y%m%d_%H:%M:%S`'] '"iptables -N $ChainName" >> $LOG_DEST
fi

## 判断INPUT跳到链的规则是否存在
iptables -C $INPUT_RULE > /dev/null 2>&1
if [[ $? == 1 ]] ; then
	iptables -I $INPUT_RULE
	echo '['`date +%Y%m%d_%H:%M:%S`'] '"iptables -I $INPUT_RULE" >> $LOG_DEST
fi

DenyIPLIst=`logread \
	| awk '/'"$LOG_KEY_WORD"'/ {for(i=1;i<=NF;i++) if($i~/[0-9].[0-9].[0-9].[0-9]/) print $i}'\
       	| grep -v $exclude_ip \
	| sort |uniq -c \
	| awk '{if($1>'"$Failed_times"') print $2}'`
IPList_sum=`echo $DenyIPLIst | wc -l`
if [[ $IPList_sum -ne 0 ]];then
    for i in $DenyIPLIst
	do
	iptables -C $ChainName -s $i -j DROP > /dev/null 2>&1
	[[ $? -eq 1 ]] && iptables -A $ChainName -s $i -j DROP \
	&& echo '['`date +%Y%m%d_%H:%M:%S`'] '"iptables -A $ChainName -s $i -j DROP" >> $LOG_DEST
	done
fi

