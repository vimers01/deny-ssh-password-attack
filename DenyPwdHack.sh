#!/bin/ash

## OpenWRT 版本判断
Vfile=/etc/banner
OWTV=`awk 'BEGIN{IGNORECASE=1}/openwrt/ {split($2,v,"."); print v[1]}' $Vfile`
[[ $OWTV -lt 18 ]] && echo "OpenWRT version must be >= 18" && exit 1

## 黑名单所在iptables链表
ChainName=DenyPwdHack

## 日志路径
LOG_DEST=/tmp/DenyPwdHack.log

## 检测到攻击时需要针对攻击IP封禁的端口,可以将ssh/luci/ftp等端口加上
Deny_Port="22,443"
INPUT_RULE="INPUT -p tcp -m multiport --dports $Deny_Port -j $ChainName"

## 日志关键字,每个关键字可以用"|"号隔开,支持grep的正则表达式
## 注: SSH 攻击可以大量出现四种关键字：Invalid user/Failed password for/Received disconnect from/Disconnected from authenticating
##     Luci 攻击可以出现"luci: failed login on / for root from xx.xx.xx.xx"
LOG_KEY_WORD="auth\.info\s+sshd.*Failed password for|luci:\s+failed\s+login|auth\.info.*sshd.*Connection closed by.*port.*preauth"

## 白名单IP可以用"|"号隔开,支持grep的正则表达式
exclude_ip="192.168.|127.0.0.1"

## 失败次数
Failed_times=5

## 黑名单过期时间,单位小时,3个月2160小时
BlackList_exp=2160

## 日志时间
LOG_DT=`date "+%Y-%m-%d %H:%M:%S"`

## 判断链是否存在
iptables -n --list $ChainName > /dev/null 2>&1
if [[ $? -ne 0 ]] ; then
  iptables -N $ChainName
  echo "[$LOG_DT] iptables -N $ChainName" >> $LOG_DEST
fi

## 判断INPUT跳到链的规则是否存在
iptables -C $INPUT_RULE > /dev/null 2>&1
if [[ $? -ne 0 ]] ; then
  iptables -I $INPUT_RULE
  echo "[$LOG_DT] iptables -I $INPUT_RULE" >> $LOG_DEST
fi

DenyIPLIst=`logread \
  | awk '/'"$LOG_KEY_WORD"'/ {for(i=1;i<=NF;i++) \
  if($i~/^(([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/) \
  print $i}' \
  | grep -v "${exclude_ip}" \
  | sort | uniq -c \
  | awk '{if($1>'"$Failed_times"') print $2}'`
IPList_sum=`echo "${DenyIPLIst}" | wc -l`
if [[ $IPList_sum -ne 0 ]];then
  for i in ${DenyIPLIst}
    do
    iptables -vnL $ChainName | grep -q $i
    [[ $? -ne 0 ]] && iptables -A $ChainName -s $i -m comment --comment "Added at $LOG_DT by DenyPwdHack" -j DROP \
     && echo "[$LOG_DT] iptables -A $ChainName -s $i -j DROP" >> $LOG_DEST
    done
fi

## 黑名单过期删除
ChainList=`iptables --line-numbers -nL $ChainName |\
  awk '/Added at/ {for(i=1;i<=NF;i++) if($i~/[0-9]{4}(-[0-9]{2}){2}/) print $1","$i" "$(i+1)}' |\
  sort -rn`

## 链表必须从后端删除,如果从前端删除,后端的实际rulenum会变
ChainList_num=`echo "${ChainList}" | grep -v "^$" | wc -l`
if [[ ${#ChainList} -ne 0 ]] && [[ $ChainList_num -gt 0 ]] ; then
for tl in `seq 1 $ChainList_num`
do
  Dtime=`echo "${ChainList}" | sed -n ''"$tl"'p' | awk -F, '{print $2}'`
  Stime=`date -d "$Dtime" +%s`
  Ntime=`date +%s`
  if [[ $(($Ntime - $Stime)) -ge $(($BlackList_exp * 3600)) ]] ; then
    RuleNum=`echo "${ChainList}" | sed -n ''"$tl"'p' | awk -F, '{print $1}'`
    iptables -D $ChainName $RuleNum
    if [[ $? -eq 0 ]] ; then
      echo "[$LOG_DT] iptables -D $ChainName $RuleNum" >> $LOG_DEST
    else
      echo "[$LOG_DT] execute delete failed: iptables -D $ChainName $RuleNum" >> $LOG_DEST
    fi
  fi
done
fi
