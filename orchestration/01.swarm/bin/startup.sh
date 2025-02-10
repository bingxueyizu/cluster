#! /bin/bash
set -e
# set -x

# 进入脚本所在目录
cd $(dirname "$0")

# Ansible 配置文件路径
export ANSIBLE_CONFIG=../ansible/ansible.cfg
# Ansible inventory 文件路径
HOSTS_FILE="../ansible/hosts"
# 配置文件路径
CONFIG_FILE="./config.json"

# 定义字符串
HOST_LIST=""
IP_LIST=""

# 获取节点的 IP 地址和主机名，并确保它们一一对应
get_node_ips_and_hosts() {
  # 使用 ansible 查询所有节点的 inventory_hostname 和 ansible_host，并将结果存入临时文件
  ansible all -i "$HOSTS_FILE" -c local -m debug -a "var=inventory_hostname,ansible_host" |
    grep -oP "'([^']+)',\s*'([^']+)'" >/tmp/ansible_output.txt
  # 读取临时文件，处理每一行
  while IFS= read -r line; do
    # 使用正则表达式提取主机名和 IP 地址
    hostname=$(echo "$line" | awk -F"'," '{print $1}' | tr -d "'" | sed 's/^ *//;s/ *$//')
    ip=$(echo "$line" | awk -F"'," '{print $2}' | tr -d "'" | sed 's/^ *//;s/ *$//')

    # 将主机名和 IP 地址直接拼接到字符串中，使用逗号分隔，不加空格
    HOST_LIST="$HOST_LIST$hostname,"
    IP_LIST="$IP_LIST$ip,"
  done </tmp/ansible_output.txt

  # 删除临时文件
  rm /tmp/ansible_output.txt

  # 去掉字符串末尾的逗号
  HOST_LIST="${HOST_LIST%,}"
  IP_LIST="${IP_LIST%,}"
}

# 调用函数获取 IP 和主机名
get_node_ips_and_hosts

# 输出获取到的主机名和 IP 地址
echo "Hostnames: $HOST_LIST"
echo "IPs: $IP_LIST"

# 虚拟机目录，删除虚拟机后会同步删除分组目录
VM_DIR=$(jq -r '.VM.VM_DIR' "$CONFIG_FILE")

# vagrant脚本中需要传递的参数
export VM_IP_LIST=$IP_LIST
export VM_HOST_LIST=$HOST_LIST
export VM_GROUP_NAME=$(jq -r '.VM.VM_GROUP' "$CONFIG_FILE")
export VM_BRIDGE=$(jq -r '.network.bridge' "$CONFIG_FILE")
export VM_GATEWAY=$(jq -r '.network.gateway' "$CONFIG_FILE")
export VM_DNS=$(jq -r '.network.dns' "$CONFIG_FILE")
export VM_PASS=$(jq -r '.system.password' "$CONFIG_FILE")
export VM_MEMORY=$(jq -r '.system.memory_m' "$CONFIG_FILE")
export VM_CPUS=$(jq -r '.system.cpus' "$CONFIG_FILE")
export VM_DISKS=$(jq -r '.disks_m.volumes' "$CONFIG_FILE")

# 启动虚拟机
start_vms() {
  cd ../vagrant
  vagrant up
}

# 销毁虚拟机
destroy_vms() {
  cd ../vagrant
  vagrant destroy -f
  rm -rf "${VM_DIR}${VM_GROUP_NAME}"
}

# 根据传入的参数执行相应操作
case "$1" in
"start")
  start_vms
  ;;
"destroy")
  destroy_vms
  ;;
*)
  echo "Usage: $0 {start|destroy}"
  # 执行任何其他命令，传递所有参数给 vagrant 命令
  if [ $# -gt 0 ]; then
    # 执行 vagrant 命令并传递所有参数
    cd ../vagrant
    vagrant "$@"
  fi
  exit 1
  ;;
esac
