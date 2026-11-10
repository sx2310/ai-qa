#!/usr/bin/env bash
set -e

echo "==> [1/5] 清理旧配置"
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-keyring.gpg
rm -f /usr/share/keyrings/jenkins-keyring.asc
rm -f /tmp/jenkins.key

echo "==> [2/5] 下载 Jenkins 公钥"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key -o /tmp/jenkins.key
echo "    密钥大小: $(wc -c < /tmp/jenkins.key) 字节"

echo "==> [3/5] 转换为 apt 可用的 keyring"
gpg --batch --yes --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg /tmp/jenkins.key
echo "    keyring 大小: $(wc -c < /usr/share/keyrings/jenkins-keyring.gpg) 字节"

echo "==> [4/5] 写入 Jenkins 源"
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list
cat /etc/apt/sources.list.d/jenkins.list

echo "==> [5/5] 更新源"
apt update -y

echo "==> 完成：接下来执行 apt install -y jenkins"
