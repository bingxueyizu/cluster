#!/bin/bash

REDIS_PASSWORD="123"

# 定义节点
NODES=("redis-master" "redis-slave")

# 封装打印标题函数
function print_title() {
    local title=$1
    figlet -f standard "$title"
}

function showReplication() {
    print_title "Check Replication"
    for node in "${NODES[@]}"; do
        echo "🔍 检查从节点 $node 的集群状态："
        docker exec $node redis-cli -a ${REDIS_PASSWORD} -c info replication
    done
}

# 检查集群同步
function check_cluster() {

    print_title "Check Cluster"
    # 在主节点创建测试数据
    echo "📋 在主节点创建测试数据 name > james"
    docker exec redis-master redis-cli -a ${REDIS_PASSWORD} -c set name james
    # 等待节点同步完成，有概率出现同步缓慢导致检查失败的情况
    sleep 1
    # 检查从节点是否同步
    for node in "${NODES[@]:1}"; do
        echo "🔍 检查从节点 $node 的同步状态："
        docker exec $node redis-cli -a ${REDIS_PASSWORD} -c get name | grep james
        if [[ $? -eq 0 ]]; then
            echo "✅ 从节点 $node 同步成功！"
        else
            echo "❌ 从节点 $node 同步失败！"
        fi
    done
}

showReplication
check_cluster
