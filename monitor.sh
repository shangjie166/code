#!bin/bash
#usage: watch -n 1 /bin/bash monitor.sh
#查看服务端半连全连队列状态

listenport=$1
pid=$(lsof -i:$listenport|awk '{print $2}'|tail -n1);

#修改max_open_file 设置httpserver可用文件数
sed  -i '/build/d'  /etc/security/limits.conf
echo 'build - nofile 8' >>  /etc/security/limits.conf

#修改backlog
echo 16 > /proc/sys/net/core/somaxconn
echo 16 > /proc/sys/net/ipv4/tcp_max_syn_backlog
echo 0  > /proc/sys/net/ipv4/tcp_syncookies

##查看内核配置
echo cat /proc/sys/net/core/somaxconn
cat /proc/sys/net/core/somaxconn
echo cat /proc/sys/net/ipv4/tcp_max_syn_backlog
cat /proc/sys/net/ipv4/tcp_max_syn_backlog
echo cat /proc/sys/net/ipv4/tcp_syncookies
cat /proc/sys/net/ipv4/tcp_syncookies
echo cat /proc/sys/net/ipv4/tcp_synack_retries
cat /proc/sys/net/ipv4/tcp_synack_retries
echo cat /proc/sys/net/ipv4/tcp_abort_on_overflow
cat /proc/sys/net/ipv4/tcp_abort_on_overflow
echo

#全连接队列理论最大值: min(stomaxconn,listen backlog)
#全连接队列实际最大值: 理论最大值+1
max_full_conns=$(ss -lnt | grep $listenport | tail -n1 | awk '{print $3}')
now_full_conns=$(ss -lnt | grep $listenport | tail -n1 | awk '{print $2}')
act_full_conns=$(($max_full_conns+1)) #全连接实际生效值比设置值大1

#半连接队列最大值规则如下:
#1. 当 max_syn_backlog > min(somaxconn, backlog) 时， 半连接队列最大值 = roundup_pow_of_two(max(8, min(tcp_max_syn_backlog, min(backlog, somaxconn))) + 1)
#2. 当 max_syn_backlog < min(somaxconn, backlog) 时， 半连接队列最大值 = max_syn_backlog * 2;
somaxconn=$(cat /proc/sys/net/core/somaxconn)
tcp_max_syn_backlog=$(cat /proc/sys/net/ipv4/tcp_max_syn_backlog)
tcp_syncookies=$(cat /proc/sys/net/ipv4/tcp_syncookies)
n=0
if [ $somaxconn -gt $tcp_max_syn_backlog ];then
    n=$tcp_max_syn_backlog
else
    n=$somaxconn
fi
if [ $n -lt 8 ];then
    n=8
fi

roundup_pow_of_two() {
    num=$1
    target=16
    while ( [ $num -gt $target ] )
    do
        target=$(($target*2))
    done
    echo $target
}
if [ $tcp_max_syn_backlog -gt $somaxconn ];then
    max_half_conns=$(roundup_pow_of_two $((n+1)))
else
    max_half_conns=$(($tcp_max_syn_backlog*2))
fi
now_half_conns=$(netstat -ntpa | grep -i syn_recv | wc -l)
#半连队列实际最大值 为min(半连队列理论最大值, max_syn_backlog - (max_syn_backlog >> 2) + 1）
act_half_conns=$max_half_conns
if [ $tcp_syncookies -eq 0 ];then
    act_half_conns=$(($tcp_max_syn_backlog-$tcp_max_syn_backlog/4+1))
fi
if [ $act_half_conns -gt $max_half_conns ];then
    act_half_conns=$max_half_conns
fi

echo "当前半连接数 理论最大数 实际最大数"
echo "$now_half_conns           $max_half_conns        $act_half_conns"
echo "当前全连接数 理论最大数 实际最大数"
echo "$now_full_conns           $max_full_conns        $act_full_conns"

echo
netstat -s | grep -i "syns to listen" | awk '{print "半连接队列溢出累计丢弃包数:"$1}'
netstat -s | grep overflowed | awk '{print "全连接队列溢出累计丢弃包数:"$1}'

echo
echo "当前进程打开文件数"
echo "ls /proc/$pid/fd |wc -l"
ls /proc/$pid/fd  | wc -l
echo

echo "当前进程最大打开文件数"
echo "cat /proc/$pid/limits |grep open"
cat /proc/$pid/limits |grep open

echo
netstat -naot |head -n2
netstat -naot|grep $listenport