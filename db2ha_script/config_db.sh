# #!/bin/bash
# The script for config DB2HADR.

#参数
#数据库用户
USER_NAME=db2inst1

su - $USER_NAME -c "
db2stop force
db2start
db2 restore database $DB_NAME from  $share2_path/db2bak
exit"
exit
