# #!/bin/bash
# The script for config DB2HADR.
################################################
#
#参数
#数据库用户
USER_NAME=db2inst1
#数据库名
DB_NAME=CMNDB
#数据库用户密码
Using_Password=123456
#HADR服务端口
DB2_HADR_1=55001
DB2_HADR_2=55001
#database-alias：为 HADR 服务器的（别）名
database_alias=HADB
#hostname：可替换服务器所在的主机名
#hostname=172.16.71.103
#port_numbe：可替换服务器所在主机的端口号
prot_number=50000
#HADR 本地主机名配置参数
hadr_local_host=172.16.87.9
#HADR 本地服务名称配置参数
hadr_local_svc=DB2_HADR_1
#HADR 远程主机名配置参数
hadr_remote_host=172.16.87.10
#HADR 远程服务名称配置参数
hadr_remote_svc=DB2_HADR_2
#远程服务器的 HADR 实例名称配置参数
hadr_remote_inst=db2inst1
#处于对等状态时日志写操作的 HADR 同步方式配置参数
#NEARSYNC表示接近同步，
hadr_syncmode=NEARSYNC
#HADR 超时值配置参数
hadr_timeout=120
#共享文件系统目录，用作数据库备份文件
#Primary
share_path=/jsnode1bpm/data
#Standby
#share2_path=/jsnode1bpm/data


#NFS配置
#Primary
mkdir $share_path/db2bak
echo "$share_path/db2bak *(rw,no_root_squash)" >> /etc/exports
service nfs restart
service iptables stop
cd $share_path
GROUP_NAME=$(id $USER_NAME | awk '{print $2}' | sed -r 's/.+\((.+)\)/\1/')
chown -R $USER_NAME:$GROUP_NAME db2bak
#Standby
#ssh 需要配置公密/私密
ssh root@$hadr_remote_host "mkdir $share_path/db2bak
service iptables stop
mount -t nfs $hadr_local_host:$share_path/db2bak $share_path/db2bak
exit"

#修改存档方式
su - $USER_NAME -c "
db2 update db cfg for $DB_NAME using logretain on
#备份主服务器数据库
db2 deactivate db $DB_NAME
db2 backup database $DB_NAME  to $share_path/db2bak
exit"
#在备机上还原数据库
ssh root@$hadr_remote_host "su - $USER_NAME -c \"
db2stop force
db2start
db2 restore database $DB_NAME from  $share_path/db2bak
exit\""
#配置 HADR 服务
#primary
echo "DB2_HADR_1 $DB2_HADR_1/tcp
DB2_HADR_2 $DB2_HADR_2/tcp" >>/etc/services

#standby
ssh root@$hadr_remote_host "echo \"DB2_HADR_1 $DB2_HADR_1/tcp
DB2_HADR_2 $DB2_HADR_2/tcp\" >>/etc/services
exit"

#配置客户端重路由
#primary
su - $USER_NAME -c "
db2 UPDATE ALTERNATE SERVER FOR DATABASE $DB_NAME USING HOSTNAME $hadr_remote_host PORT $prot_number
exit"

echo "primary to "
#standby
ssh root@$hadr_remote_host "su - $USER_NAME -c \"
db2 UPDATE ALTERNATE SERVER FOR DATABASE $DB_NAME USING HOSTNAME $hadr_local_host PORT $prot_number
exit\""
echo "standby to"
#配置主数据库服务器
su - $USER_NAME -c "
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $hadr_local_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $hadr_local_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $hadr_remote_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $hadr_remote_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST $hadr_remote_inst
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE $hadr_syncmode
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT $hadr_timeout
exit"

hostname
#连接数据库
su - $USER_NAME -c "
db2 CONNECT TO $DB_NAME
db2 QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS
db2 UNQUIESCE DATABASE
db2 CONNECT RESET
exit"
#断开除管理员以外用户对数据库的连接
#db2 QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS

#配置备用数据库
ssh root@$hadr_remote_host "
su - $USER_NAME -c \"
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $hadr_remote_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $hadr_remote_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $hadr_local_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $hadr_local_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST $hadr_remote_inst
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE $hadr_syncmode
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT $hadr_timeout
exit\" "


