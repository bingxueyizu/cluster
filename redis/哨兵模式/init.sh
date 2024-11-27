#!/bin/bash

REDIS_PASSWORD="123"

# 定义节点
NODES=("redis-master" "redis-slave" "redis-sentinel-0" "redis-sentinel-1" "redis-sentinel-2")

# 封装打印标题函数
function print_title() {
    local title=$1
    figlet -f standard "$title"
}

function showReplication() {
    print_title "Check Replication"
    for node in "${NODES[@]:0:2}"; do
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
    for node in "${NODES[@]:1:1}"; do
        echo "🔍 检查从节点 $node 的同步状态："
        docker exec $node redis-cli -a ${REDIS_PASSWORD} -c get name | grep james
        if [[ $? -eq 0 ]]; then
            echo "✅ 从节点 $node 同步成功！"
        else
            echo "❌ 从节点 $node 同步失败！"
        fi
    done
}

function check_sentinel_info() {
    print_title "Check Sentinel"
    for node in "${NODES[@]:2}"; do
        echo "🔍 检查哨兵节点 $node 的sentinel状态："
        docker exec $node redis-cli -a ${REDIS_PASSWORD} -p 16379 -c info sentinel
        if [[ $? -eq 0 ]]; then
            echo "✅ 哨兵节点 $node 检查成功！"
        else
            echo "❌ 哨兵节点 $node 检查失败！"
        fi
    done
}

function slaveToMaster() {
    node="redis-master"
    echo "🔍 停止主节点 $node ："
    docker stop $node
    if [[ $? -eq 0 ]]; then
        echo "✅ 主节点 $node 停止成功！"
    else
        echo "❌ 主节点 $node 停止失败！"
    fi

    sleep 10

    node="redis-slave"
    echo "🔍 从节点 $node 写入数据："
    docker exec $node redis-cli -a ${REDIS_PASSWORD} -c set slave 123
    # docker exec redis-slave redis-cli -a 123 -c set slave 123
    docker exec $node redis-cli -a ${REDIS_PASSWORD} -c get slave
    if [[ $? -eq 0 ]]; then
        echo "✅ 从节点 $node 升级成功！"
    else
        echo "❌ 哨兵节点 $node 升级失败！"
    fi

}
showReplication
check_cluster
check_sentinel_info
slaveToMaster
