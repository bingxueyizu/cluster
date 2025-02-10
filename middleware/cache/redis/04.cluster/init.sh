#!/bin/bash

docker-compose down

REDIS_PASSWORD="123"

# 定义节点
NODES=("master-0" "slave-0" "master-1" "slave-1" "master-2" "slave-2")

for node in ${NODES[@]}; do
  sudo rm -rf conf/$node/{appendonlydir,dump.rdb,redis-cluster.conf,nodes.conf}
  cat conf/redis.conf > conf/$node/redis.conf
done
tree conf

# docker-compose up -d

# sleep 3

# # 创建集群
# docker exec -ti redis-master-0 redis-cli -a ${REDIS_PASSWORD} --cluster create \
#   redis-master-0:6379 redis-slave-0:6379 \
#   redis-master-1:6379 redis-slave-1:6379 \
#   redis-master-2:6379 redis-slave-2:6379 --cluster-replicas 1

# for node in ${NODES[@]}; do
#   docker exec redis-$node redis-cli -a ${REDIS_PASSWORD} -c cluster info
# done

# docker exec -ti redis-master-0 redis-cli -a ${REDIS_PASSWORD} -c cluster nodes