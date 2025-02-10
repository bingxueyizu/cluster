# 多主多从实例配置
## 配置文件配置
按照项目配置文件配置即可
## 集群创建
1. 主库创建拷贝账号
```bash
docker exec mysql-master01 mysql -uroot -p123456 -e "GRANT REPLICATION SLAVE ON *.* TO 'copy'@'%' IDENTIFIED BY '123456';"
docker exec mysql-master02 mysql -uroot -p123456 -e "GRANT REPLICATION SLAVE ON *.* TO 'copy'@'%' IDENTIFIED BY '123456';"
```
2. 查看主服务器状态
```bash
docker exec mysql-master01 mysql -uroot -p123456 -e "show master status\G;"
docker exec mysql-master01 mysql -uroot -p123456 -e "reset master;"

docker exec mysql-master02 mysql -uroot -p123456 -e "show master status\G;"
docker exec mysql-master02 mysql -uroot -p123456 -e "reset master;"
```
3. 配置从库
```bash
# master02-master01 #
# 配置主库
docker exec mysql-master02 mysql -uroot -p123456 -e "CHANGE MASTER TO  MASTER_HOST='192.168.1.50',MASTER_PORT=3306,MASTER_USER='copy',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=154;"

# 启动从库
docker exec mysql-master02 mysql -uroot -p123456 -e "start slave;"

# 查看从库状态
docker exec mysql-master02 mysql -uroot -p123456 -e "show slave status\G;"

# slave01-master01 #
# 配置主库
docker exec mysql-slave01 mysql -uroot -p123456 -e "CHANGE MASTER TO  MASTER_HOST='192.168.1.50',MASTER_PORT=3306,MASTER_USER='copy',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=154;"

# 启动从库
docker exec mysql-slave01 mysql -uroot -p123456 -e "start slave;"

# 查看从库状态
docker exec mysql-slave01 mysql -uroot -p123456 -e "show slave status\G;"

# master01-master02 #
docker exec mysql-master01 mysql -uroot -p123456 -e "CHANGE MASTER TO  MASTER_HOST='192.168.1.50',MASTER_PORT=3307,MASTER_USER='copy',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=154;"

# 启动从库
docker exec mysql-master01 mysql -uroot -p123456 -e "start slave;"

# 查看从库状态
docker exec mysql-master01 mysql -uroot -p123456 -e "show slave status\G;"

# slave02-master02 #
docker exec mysql-slave02 mysql -uroot -p123456 -e "CHANGE MASTER TO  MASTER_HOST='192.168.1.50',MASTER_PORT=3307,MASTER_USER='copy',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=154;"

# 启动从库
docker exec mysql-slave02 mysql -uroot -p123456 -e "start slave;"

# 查看从库状态
docker exec mysql-slave02 mysql -uroot -p123456 -e "show slave status\G;"
```
## 集群验证
```bash
docker exec mysql-master01 mysql -uroot -p123456 -e "create database db01;"

docker exec mysql-master01 mysql -uroot -p123456 -e "show databases;"
docker exec mysql-master02 mysql -uroot -p123456 -e "show databases;"
docker exec mysql-slave01 mysql -uroot -p123456 -e "show databases;"
docker exec mysql-slave02 mysql -uroot -p123456 -e "show databases;"
```