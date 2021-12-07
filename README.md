# code
在两台开发台dev1 dev2上验证半连接和全连接队列的长度 与 内核参数的关系

## dev2上运行
1. build.sh得到http_server 
2. 新建build用户，以build权限运行http_server
3. 新建一个窗口执行watch -n1 /bin/bash monitor.sh
查看队列状态
   
## dev1上运行
1. 调整dev2中各参数观察半连队列的变化
```
hping3 -c 1000  -d 120 -S -w 64 -p $dev2_port --flood  --rand-source $dev2ip
```
2. 观察dev2中全连队列的变化
```
for i in `seq 1 10`;do echo "curl http://$dev2ip:$dev2port/boss/a &"|bash; done
```

## 说明
linux3.10下

### 全连队列最大值
应用层设置backlog和内核参数somaxconn 二者中最小值
```
min(somaxconn, backlog)
```

上述为理论值，实际值比理论值大1

### 半连接队列最大值
计算规则为
```
#1. 当 max_syn_backlog > min(somaxconn, backlog) 时， 半连接队列最大值 = roundup_pow_of_two(max(8, min(tcp_max_syn_backlog, min(backlog, somaxconn))) +1)
#2. 当 max_syn_backlog < min(somaxconn, backlog) 时， 半连接队列最大值 = max_syn_backlog * 2;
```
实际情况相关系统内核值都比8大，max_syn_backlog一般比somaxconn大

上述规则可简化为只考虑case1
```
半连接队列最大值=roundup_pow_of_two(min(tcp_max_syn_backlog, somaxconn, backlog)+1) 
```
即最接近 (tcp_max_syn_backlog，somaxconn最小值+1)  的2的N次方 

最接近的意思是 大于等于

上面得到的是半连队列理论最大值，实际最大值为
```
min(半连队列理论最大值, max_syn_backlog - (max_syn_backlog >> 2) + 1）
```