#!/bin/bash
# ASCII 生成工具: https://tools.kalvinbg.cn/txt/ascii

# set -e

# 定义 MySQL 用户和密码
MYSQL_USER="root"
MYSQL_PASSWORD="123456"

# 定义节点
NODES=("mariadb-init" "mariadb-0" "mariadb-1" "mariadb-2")

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
        docker exec "$node" bash -c "mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SHOW DATABASES;' | grep mysql"
        if [[ $? -eq 0 ]]; then
            echo "✅ 节点 $node 准备完成！"
        else
            echo "❌ 节点 $node 准备失败！"
            exit 1
        fi
    done
}

function showClusterInfo(){
    docker exec ${NODES[0]} bash -c "mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SHOW STATUS LIKE \"wsrep_cluster%\";'"
}

# 检查集群同步
function check_cluster() {

    print_title "Check Cluster"
    # 在主节点创建测试数据库
    echo "📋 在${NODES[0]}创建测试数据库 test02"
    docker exec ${NODES[0]} bash -c "mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'CREATE DATABASE test02;'"
    # 等待节点同步完成，有概率出现同步缓慢导致检查失败的情况
    sleep 1
    # 检查节点是否同步
    for node in "${NODES[@]:1}"; do
        echo "🔍 检查节点 $node 的同步状态："
        docker exec "$node" bash -c "mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SHOW DATABASES;' | grep test02"
        if [[ $? -eq 0 ]]; then
            echo "✅ 节点 $node 同步成功！"
        else
            echo "❌ 节点 $node 同步失败！"
        fi
    done
}

# 主程序执行
prepared
showClusterInfo
check_cluster

# docker exec -ti mysql-master bash -c "mysql -uroot -p123456 -e 'HOW VARIABLES LIKE "binlog_format";'"
