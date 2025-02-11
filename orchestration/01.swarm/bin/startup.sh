#!/bin/bash
set -e # 遇到错误立即退出
# set -x  # 取消注释可开启调试模式，查看命令执行详情

# 进入脚本所在目录，保证相对路径正确
cd "$(dirname "$0")"

# ===================== 配置参数 =====================

# Ansible 配置文件路径
export ANSIBLE_CONFIG=../ansible/ansible.cfg
# Ansible inventory 主机文件
HOSTS_FILE="../ansible/hosts"
# 配置文件路径 (JSON 格式)
CONFIG_FILE="./config.json"

# 定义用于存储主机名和 IP 地址的字符串变量
HOST_LIST=""
IP_LIST=""

# ===================== 函数定义 =====================

# 获取所有节点的 IP 地址和主机名，并存入 HOST_LIST 和 IP_LIST
get_node_ips_and_hosts() {
  echo "获取 Ansible inventory 中的节点信息..."

  # 使用 Ansible 查询所有主机的 inventory_hostname 和 ansible_host，并写入临时文件
  ansible all -i "$HOSTS_FILE" -c local -m debug -a "var=inventory_hostname,ansible_host" |
    grep -oP "'([^']+)',\s*'([^']+)'" >/tmp/ansible_output.txt

  # 读取临时文件并解析
  while IFS= read -r line; do
    # 提取主机名
    hostname=$(echo "$line" | awk -F"'," '{print $1}' | tr -d "'" | sed 's/^ *//;s/ *$//')
    # 提取 IP 地址
    ip=$(echo "$line" | awk -F"'," '{print $2}' | tr -d "'" | sed 's/^ *//;s/ *$//')

    # 拼接到字符串列表，使用逗号分隔
    HOST_LIST="$HOST_LIST$hostname,"
    IP_LIST="$IP_LIST$ip,"
  done </tmp/ansible_output.txt

  # 清理临时文件
  rm -f /tmp/ansible_output.txt

  # 去掉最后一个逗号，避免格式错误
  HOST_LIST="${HOST_LIST%,}"
  IP_LIST="${IP_LIST%,}"

  # 输出获取到的主机信息
  echo "获取到的主机名列表: $HOST_LIST"
  echo "获取到的 IP 地址列表: $IP_LIST"
}

# 启动虚拟机
start_vms() {
  echo "启动虚拟机..."

  # 进入 Vagrant 目录
  cd ../vagrant
  vagrant up
  vagrant snapshot save system-init

  # 清理已存储的 SSH 主机密钥，防止因密钥变更导致 SSH 连接失败
  echo "清理旧的 SSH known_hosts 记录..."
  IFS=',' read -r -a IP_ARRAY <<<"$IP_LIST"
  for IP in "${IP_ARRAY[@]}"; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$IP"
  done
}

# 销毁虚拟机
destroy_vms() {
  echo "销毁虚拟机..."

  # 进入 Vagrant 目录
  cd ../vagrant
  vagrant destroy -f

  # 删除相关数据目录
  rm -rf "${VM_DIR}${VM_GROUP_NAME}"
}

restore_vms() {
  echo "恢复虚拟机..."
  cd ../vagrant
  vagrant snapshot restore $1
  vagrant status
}

# ===================== 主逻辑 =====================

# 调用函数获取主机 IP 和主机名
get_node_ips_and_hosts

# 从 JSON 配置文件读取参数，并存入环境变量
VM_DIR=$(jq -r '.VM.VM_DIR' "$CONFIG_FILE")
export VM_IP_LIST=$IP_LIST
export VM_HOST_LIST=$HOST_LIST
export VM_GROUP_NAME=$(jq -r '.VM.VM_GROUP' "$CONFIG_FILE")
export VM_BRIDGE=$(jq -r '.network.bridge' "$CONFIG_FILE")
export VM_GATEWAY=$(jq -r '.network.gateway' "$CONFIG_FILE")
export VM_DNS=$(jq -r '.network.dns' "$CONFIG_FILE")
export VM_PASS=$(awk -F= '/ansible_password/ {print $2}' "$HOSTS_FILE" | tr -d ' ')
export VM_MEMORY=$(jq -r '.system.memory_m' "$CONFIG_FILE")
export VM_CPUS=$(jq -r '.system.cpus' "$CONFIG_FILE")
export VM_DISKS=$(jq -r '.disks_m.volumes' "$CONFIG_FILE")

# ===================== 执行操作 =====================

case "$1" in
"start")
  start_vms
  ;;
"destroy")
  destroy_vms
  ;;
"restore")
  restore_vms $2
  ;;
*)
  echo "Usage: $0 {start|destroy|restore}"
  if [ $# -gt 0 ]; then
    echo "执行 Vagrant 相关命令: vagrant $*"
    cd ../vagrant
    vagrant "$@"
  fi
  exit 1
  ;;
esac
