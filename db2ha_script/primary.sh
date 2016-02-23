# #!/bin/bash
# The script for config DB2HADR.
#参数
#数据库用户
USER_NAME=db2inst2
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
hadr_local_host=172.16.82.10
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
share1_path=/jsnode1bpm/data
#Standby
share2_path=/jsnode1bpm/data


#NFS配置
#Primary
mkdir $share1_path/db2bak
echo "$share1_path/db2bak *(rw,no_root_squash)" >> /etc/exports
service nfs restart
service iptables stop
#Standby
#ssh 需要配置公密/私密
ssh root@$hadr_remote_host /root/config_nfs.sh
#关闭防火墙
#if nfs mounted
#成功提示信息 nfs config successful!
#if [ "" ];then
#	echo "nfs config successful."
#	else
#	echo "nfs config failed."
#fi
#断开ssh
#修改备份文件夹的属组
cd $share1_path
chown -R db2inst1:db2iadm1 db2bak
#修改存档方式
su - $USER_NAME -c "
db2 update db cfg for $DB_NAME using logretain on
#备份主服务器数据库
db2 deactivate db $DB_NAME
db2 backup database $DB_NAME  to $share1_path/db2bak
exit"
#在备机上还原数据库

ssh root@$hadr_remote_host "/root/config_db.sh"


#配置客户端重路由
#配置主数据库服务器
su - $USER_NAME -c "
db2 UPDATE ALTERNATE SERVER FOR DATABASE $DB_NAME USING HOSTNAME $hadr_remote_host PORT $prot_number

db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $hadr_local_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $hadr_local_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $hadr_remote_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $hadr_remote_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST $hadr_remote_inst
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE $hadr_syncmode
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT $hadr_timeout
exit"

#配置 HADR 服务
echo "DB2_HADR_1 $DB2_HADR_1/tcp
DB2_HADR_2 $DB2_HADR_2/tcp" >>/etc/services

#连接数据库
su - $USER_NAME -c "
db2 CONNECT TO $DB_NAME
db2 QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS
db2 UNQUIESCE DATABASE
db2 CONNECT RESET
exit"

#配置备用服务器
ssh root@$hadr_remote_host /root/config_hadr.sh

