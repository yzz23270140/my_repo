#!/bin/sh
set -e
# prepare-board.sh
# 一次性在目标板上运行：设置 root 密码、创建普通用户、安装 sudo（opkg 优先）、添加公钥、可选禁用密码登录
#
# 使用：
#   1) 把你的公钥替换到 SSH_PUB_KEY 变量
#   2) scp prepare-board.sh root@<IP>:/root/
#   3) ssh root@<IP> "chmod +x /root/prepare-board.sh && /root/prepare-board.sh"
#
SSH_PUB_KEY='ssh-rsa AAAA... your@host'   # <-- 请替换为你的公钥

echo "== 1) 请先为 root 设置密码 =="
passwd

# 创建普通用户 devuser（若已存在则跳过）
if ! id devuser >/dev/null 2>&1; then
  echo "创建用户 devuser..."
  if command -v useradd >/dev/null 2>&1; then
    useradd -m -s /bin/bash devuser || useradd -m -s /bin/sh devuser
  else
    adduser -D -h /home/devuser devuser || adduser devuser
  fi
  echo "请为 devuser 设置密码："
  passwd devuser
else
  echo "用户 devuser 已存在，跳过创建。"
fi

# 安装 sudo（优先 opkg）
if command -v opkg >/dev/null 2>&1; then
  echo "尝试使用 opkg 安装 sudo..."
  opkg update || true
  if opkg list | grep -q '^sudo'; then
    opkg install sudo || echo "opkg 安装 sudo 失败，请检查网络或手动安装包"
  else
    echo "opkg 源中未发现 sudo 包，请使用 rpm/deb 包或在构建时加入 sudo"
  fi
elif command -v rpm >/dev/null 2>&1; then
  echo "系统有 rpm，请拷贝 sudo.rpm 并用 rpm -Uvh /tmp/sudo.rpm 安装"
else
  echo "未找到合适的包管理器，请手动安装 sudo 包"
fi

# 配置 sudoers（无密码 sudo，仅在确认安全后使用）
if [ -d /etc/sudoers.d ]; then
  echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
  chmod 440 /etc/sudoers.d/devuser
  echo "已在 /etc/sudoers.d/devuser 配置无密码 sudo"
fi

# 设置 devuser SSH key
mkdir -p /home/devuser/.ssh
echo "$SSH_PUB_KEY" >> /home/devuser/.ssh/authorized_keys
chown -R devuser:devuser /home/devuser/.ssh
chmod 700 /home/devuser/.ssh
chmod 600 /home/devuser/.ssh/authorized_keys

# 设置 root SSH key（可选）
mkdir -p /root/.ssh
echo "$SSH_PUB_KEY" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 可选：禁用密码登录（确认公钥登录可用后执行）
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
  systemctl restart sshd || echo "重启 sshd 失败，请手动重启"
fi

echo "完成。请尝试使用 SSH key 登录： ssh devuser@<IP>"