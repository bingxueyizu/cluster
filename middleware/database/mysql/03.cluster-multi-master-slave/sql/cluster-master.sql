# 创建主从拷贝账号
GRANT REPLICATION SLAVE ON *.* TO 'copy' @'%' IDENTIFIED BY '123456';

# 检查主节点状态 
show master status;

# 由于主库创建了copy账号，所以主库的file并不是mysql-bin.000001，Position也不是154
# 可以通过resetmaster进行重置
reset master;

# 检查主节点状态 
show master status;

# 检查binlog的格式
SHOW VARIABLES LIKE 'binlog_format';