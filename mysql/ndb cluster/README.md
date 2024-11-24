# NDB集群概述
NDB Cluster是一种能够在无共享系统中对内存数据库进行集群的技术。无共享架构使系统能够使用非常便宜的硬件，并且对硬件或软件的特定要求最低。

NDB Cluster 的设计目的是不存在任何单点故障。在无共享系统中，每个组件都应该有自己的内存和磁盘，并且不建议或不支持使用网络共享、网络文件系统和 SAN 等共享存储机制。

NDB Cluster 将标准 MySQL 服务器与称为（NDB 代表“网络数据库 ”）的 内存集群存储引擎集成。在我们的文档中，该术语NDB指的是特定于存储引擎的设置部分，而“ MySQL NDB Cluster ”指的是一个或多个 MySQL 服务器与存储引擎的组合 NDB。

NDB Cluster 由一组称为 “主机”的计算机组成，每个计算机运行一个或多个进程。这些进程称为 节点，可能包括 MySQL 服务器（用于访问 NDB 数据）、数据节点（用于存储数据）、一个或多个管理服务器，以及可能的其他专用数据访问程序。 NDB Cluster 中这些组件的关系如下所示：
![ndb_cluster](https://liuqiang.dduner.com:8443/upload/2024/04/ndb_cluster.png)
所有这些程序一起工作形成一个 NDB Cluster 。当存储引擎存储数据时，表（和表数据）存储在数据节点 NDB中。在集群中存储数据的工资单应用程序中，如果一个应用程序更新了一名员工的工资，则查询该数据的所有其他 MySQL 服务器都可以立即看到这一变化。
# NDB集群核心概念
- 管理节点：此类节点的作用是管理NDB Cluster内的其他节点，执行提供配置数据、启动和停止节点以及运行备份等功能。由于此节点类型管理其他节点的配置，因此应先启动此类型的节点，然后再启动任何其他节点。管理节点使用命令`ndb_mgmd`启动。
- 数据节点：此类节点存储集群数据。数据节点的数量与片段副本的数量乘以片段的数量相同。例如，对于两个片段副本，每个副本有两个片段，您需要四个数据节点。一个分片副本足以存储数据，但不提供冗余；因此，建议有两个（或更多）片段副本以提供冗余，从而提供高可用性。数据节点使用命令`ndbd`或` ndbmtd`
- SQL节点：这是访问集群数据的节点。对于 NDB Cluster，SQL 节点是使用 NDBCLUSTER存储引擎的传统 MySQL 服务器。 SQL 节点是一个以 和 选项启动的mysqld进程，本章其他地方对此进行了解释，可能还带有其他 MySQL 服务器选项。 --ndbcluster--ndb-connectstring

# 环境部署
本实例配置，在一台机器使用docker启动不同端口来实现ndb cluster配置
## 创建文件
```bash
tree .
.
├── docker-compose.yml
├── ndb_data1
│   └── my.cnf
├── ndb_data2
│   └── my.cnf
├── ndb_management
│   ├── config.cnf
│   └── my.cnf
├── ndb_mysqld1
│   └── my.cnf
├── ndb_mysqld2
│   └── my.cnf
└── README.md
```
1. docker-compose.yml内容如下：
```yaml
# 集群验证
# docker exec -it ndb_management ndb_mgm -e show
# 数据验证
# docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "CREATE DATABASE test01;"
# docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "SHOW DATABASES;"
# docker exec -it ndb_mysqld2 mysql -uroot -p123456 -e "SHOW DATABASES;"
version: '3'
networks:
  my_cluster:
    driver: bridge
services:
  # 服务名，在同一个网络下的docker容器之间可以通过服务名访问，
  # 所以我在创建容器以及后面的配置文件中没有指定IP
  ndb_management:
    image: mysql/mysql-cluster:8.0
    # 容器名，docker exec等命令用的
    container_name: ndb_management
    # 容器启动命令
    # command会传给entrypoint.sh并启动不同的服务
    # 这个就只是启动的 ~ $ ndb_mgmd --ndb-nodeid=1 ...
    command: [
      'ndb_mgmd',
      '--reload',
      '--initial'
    ]
    # 容器卷，用来配置集群
    # 集群配置文件为config.cnf
    # 对应到容器里面的/etc/mysql-cluster.cnf，至于为什么，大家可以去看下镜像的源码
    # 配置/etc/my.cnf，可以在当前容器执行ndb_mgm -e show查看集群状态，不添加配置，会查询失败，只能去其他节点查询
    volumes:
      - ./ndb_management/config.cnf:/etc/mysql-cluster.cnf
      - ./ndb_management/my.cnf:/etc/my.cnf
      - ./ndb_management/data:/var/lib/mysql
    ports:
      - "1186:1186"
    # 指定网络
    networks:
      - my_cluster
  
  ndb_data1:
    image: mysql/mysql-cluster:8.0
    container_name: ndb_data1
    command: [
      'ndbd'
    ]
    volumes:
      - ./ndb_data1/my.cnf:/etc/my.cnf
      - ./ndb_data1/data:/var/lib/mysql
    networks:
      - my_cluster
  ndb_data2:
    image: mysql/mysql-cluster:8.0
    container_name: ndb_data2
    command: [
      'ndbd'
    ]
    volumes:
      - ./ndb_data2/my.cnf:/etc/my.cnf
      - ./ndb_data2/data:/var/lib/mysql
    networks:
      - my_cluster
  
  ndb_mysqld1:
    image: mysql/mysql-cluster:8.0
    container_name: ndb_mysqld1
    command: [
      'mysqld',
      '--default-authentication-plugin=mysql_native_password'
    ]
    environment:
      MYSQL_ROOT_PASSWORD: 123456
      MYSQL_DATABASE: mycluster
    volumes:
      - ./ndb_mysqld1/my.cnf:/etc/my.cnf
      - ./ndb_mysqld1/data:/var/lib/mysql
    networks:
      - my_cluster
    ports:
      - "3326:3306"
    depends_on:
      - ndb_management
      - ndb_data1
      - ndb_data2

  ndb_mysqld2:
    image: mysql/mysql-cluster:8.0
    container_name: ndb_mysqld2
    command: [
      'mysqld',
      '--default-authentication-plugin=mysql_native_password'
    ]
    environment:
      MYSQL_ROOT_PASSWORD: 123456
    volumes:
      - ./ndb_mysqld2/my.cnf:/etc/my.cnf
      - ./ndb_mysqld2/data:/var/lib/mysql
    networks:
      - my_cluster
    ports:
      - "3327:3306"
    depends_on:
      - ndb_management
      - ndb_data1
      - ndb_data2
```
2. my.cnf内容如下：
```cnf
# 配置mysqld的初始化和启动参数，像这里我指定ndb_mgmd的地址为docker中的服务名
[mysqld]
ndbcluster
default_storage_engine=ndbcluster
ndb-connectstring=ndb_management
user=mysql

[mysql_cluster]
ndb-connectstring=ndb_management

[ndbd]
connect-string=ndb_management

[ndb_mgm]
connect-string=ndb_management
```
3. config.cnf内容如下：
```cnf
# 配置ndb_mgmd启动时的集群相关信息
[ndbd default]
NoOfReplicas= 2

[mysqld  default]
[ndb_mgmd default]
[tcp default]

[ndb_mgmd]
NodeId=1
hostname=ndb_management
DataDir=/var/lib/mysql

[ndbd]
NodeId=2
hostname=ndb_data1
DataDir=/var/lib/mysql

[ndbd]
NodeId=3
hostname=ndb_data2
DataDir=/var/lib/mysql
# MySQL API 节点不用特意指定hostname
[mysqld]
NodeId=4
hostname=ndb_mysqld1
[mysqld]
NodeId=5
hostname=ndb_mysqld2
```
## 集群创建
```bash
# 创建集群
kuba@bug:~/work/cluster/mysql/cluster$ docker-compose up -d
[+] Running 6/6
 ⠿ Network cluster_my_cluster  Created                                                                                                                                                       0.1s
 ⠿ Container ndb_data2         Started                                                                                                                                                       0.4s
 ⠿ Container ndb_management    Started                                                                                                                                                       0.4s
 ⠿ Container ndb_data1         Started                                                                                                                                                       0.4s
 ⠿ Container ndb_mysqld1       Started                                                                                                                                                       1.2s
 ⠿ Container ndb_mysqld2       Started
 
# 查看集群状态
kuba@bug:~/work/cluster/mysql/cluster$ docker exec -it ndb_data2 ndb_mgm -e show
Connected to Management Server at: ndb_management:1186
Cluster Configuration
---------------------
[ndbd(NDB)]     2 node(s)
id=2    @192.168.48.4  (mysql-8.0.22 ndb-8.0.22, Nodegroup: 0, *)
id=3    @192.168.48.2  (mysql-8.0.22 ndb-8.0.22, Nodegroup: 0)

[ndb_mgmd(MGM)] 1 node(s)
id=1    @192.168.48.3  (mysql-8.0.22 ndb-8.0.22)

[mysqld(API)]   2 node(s)
id=4    @192.168.48.5  (mysql-8.0.22 ndb-8.0.22)
id=5    @192.168.48.6  (mysql-8.0.22 ndb-8.0.22)
```
## 集群验证
由于配置文件默认配置了ndbcluster引擎，所以建表的时候，不需要指定engine=ndbcluster，否则需要指定
```bash
# 创建数据库
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "CREATE DATABASE test01;"

# 查询数据库（ndb_mysqld1：有数据，ndb_mysqld2：有数据）
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "SHOW DATABASES;"
docker exec -it ndb_mysqld2 mysql -uroot -p123456 -e "SHOW DATABASES;"

# 创建数据库表，默认使用ndbcluster
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "use test01; CREATE TABLE t01 (id INT);"

# 查询数据库（ndb_mysqld1：有数据，ndb_mysqld2：有数据）
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "use test01; SHOW tables;"
docker exec -it ndb_mysqld2 mysql -uroot -p123456 -e "use test01; SHOW tables;"

# 创建数据库表，指定使用innodb引擎
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "use test01; CREATE TABLE t02 (id INT) engine=innodb;"

# 查询数据库（ndb_mysqld1：有数据，ndb_mysqld2：无数据）
docker exec -it ndb_mysqld1 mysql -uroot -p123456 -e "use test01; SHOW tables;"
docker exec -it ndb_mysqld2 mysql -uroot -p123456 -e "use test01; SHOW tables;"
```
## 数据清理
```bash
for item in ndb_management ndb_mysqld1 ndb_mysqld2 ndb_data1 ndb_data2;do 
sudo rm -rf $item/data
done
tree .
```