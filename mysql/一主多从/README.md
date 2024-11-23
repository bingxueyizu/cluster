# 一主多从实例配置
## 集群启动步骤
1. 启动集群

```bash
 docker-compose up -d
 ```
2. 初始化集群
```bash
 bash init.sh
```
## 关注的指标
`binlog_format`：指定binglog的格式为mixed（混合模式），还支持STATEMENT (基于语句的复制)、ROW (基于行的复制--默认)  

`read-only`: 配置普通用户的节点只读   

`super_read_only`: 配置超级用户的节点只读（不可以默认开启，开启后从节点会启动失败），建议应用不要使用超级用户连接数据库操作
