# 配置主库
CHANGE MASTER TO MASTER_HOST = 'mysql-master',
MASTER_PORT = 3306,
MASTER_USER = 'copy',
MASTER_PASSWORD = '123456',
MASTER_LOG_FILE = 'mysql-bin.000001',
MASTER_LOG_POS = 154;

# 启动从库
start slave;

# 查看从库状态
show slave status \G;

# 查询从节点只读配置
SHOW VARIABLES WHERE Variable_name IN ('read_only', 'super_read_only');