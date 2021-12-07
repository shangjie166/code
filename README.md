# code
在两台开发台dev1 dev2上验证半连接和全连接队列的长度 与 内核参数的关系

## dev2上运行
1. build.sh得到http_server 
2. 新建build用户，以build权限运行http_server
3. 新建一个窗口执行watch -n1 /bin/bash monitor.sh
查看队列状态
   
## dev1上运行
1. hping3 -c 1000  -d 120 -S -w 64 -p $dev2_port --flood  --rand-source $dev2ip
调整dev2中各参数观察半连队列的变化
2. 执行
```
for i in `seq 1 10`;do echo "curl http://$dev2ip:$dev2port/boss/a &"|bash; done
```
观察dev2中全连队列的变化
