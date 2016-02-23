# #!/bin/bash
# The script for config DB2HADR.

#参数
#HADR 本地主机名配置参数
hadr_local_host=172.16.82.10

#共享文件系统目录，用作数据库备份文件
share_path=/jsnode1bpm/data

mkdir $share_path/db2bak
service iptables stop
mount -t nfs $hadr_local_host:$share_path/db2bak $share_path/db2bak
