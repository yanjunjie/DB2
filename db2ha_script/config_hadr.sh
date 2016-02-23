# #!/bin/bash
# The script for config DB2HADR.
#参数
#数据库用户
USER_NAME=db2inst1

#配置 HADR 服务
echo "DB2_HADR_1 $DB2_HADR_1/tcp
DB2_HADR_2 $DB2_HADR_2/tcp" >>/etc/services

#配置备用数据库
su - $USER_NAME -c "
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $hadr_remote_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $hadr_remote_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $hadr_local_host
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $hadr_local_svc
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST $hadr_remote_inst
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE $hadr_syncmode
db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT $hadr_timeout
exit"
exit
