#!/bin/bash
# ASCII 生成工具: https://tools.kalvinbg.cn/txt/ascii

# set -e

# 定义 MySQL 用户和密码
MYSQL_USER="root"
MYSQL_PASSWORD="123456"

# 定义节点
NODES=("mysql-master01" "mysql-master02" "mysql-slave01" "mysql-slave02")

# 封装打印标题函数
function print_title() {
    local title=$1
    figlet -f standard "$title"
}

# 检查节点准备情况
function prepared() {
    print_title "Prepared"
    for node in "${NODES[@]}"; do
        echo ">>>>>> 检查节点：$node <<<<<<"
        docker exec "$node" bash -c "mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SHOW DATABASES;' | grep mysql"
        if [[ $? -eq 0 ]]; then
            echo "✅ 节点 $node 准备完成！"
        else
            echo "❌ 节点 $node 准备失败！"
            exit 1
        fi
    done
}

# 初始化主节点
function init_master() {
    print_title "Master"
    for node in "${NODES[@]:0:2}"; do
        cat sql/cluster-master.sql | docker exec -i $node mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD}
    done
    echo "✅ 主节点初始化完成！"
}

# 初始化从节点
function init_slave() {
    print_title "Slave"

    for node in mysql-master02 mysql-slave01; do
        cat sql/cluster-slave01.sql | docker exec -i "$node" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD}
        echo "✅ 从节点 $node 初始化完成！"
    done
    for node in mysql-master01 mysql-slave02; do
        cat sql/cluster-slave02.sql | docker exec -i "$node" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD}
        echo "✅ 从节点 $node 初始化完成！"
    done
}

# 检查集群同步
function check_cluster() {

    print_title "Check Cluster"
    # 在主节点创建测试数据库
    for node in "${NODES[@]:0:2}"; do
        echo "📋 在 $node 节点创建测试数据库 $node"
        docker exec $node bash -c "mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'CREATE DATABASE ${node#mysql-};'"
    done
    # 等待节点同步完成，有概率出现同步缓慢导致检查失败的情况
    sleep 1
    # 检查从节点是否同步
    for node in "${NODES[@]}"; do
        echo "🔍 检查节点 $node 的同步状态："
        docker exec "$node" bash -c "mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SHOW DATABASES;' | grep master"
        if [[ $? -eq 0 ]]; then
            echo "✅ 节点 $node 同步成功！"
        else
            echo "❌ 节点 $node 同步失败！"
        fi
    done
}

# 主程序执行
prepared
init_master
init_slave
check_cluster

# docker exec -ti mysql-master01 bash -c "mysql -uroot -p123456 -e 'show databases;'"
