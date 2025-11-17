# Yocto / Renesas 开发板常用操作速查（Poky Dunfell）

说明
- 目标场景：已把 Yocto（Poky dunfell）镜像刷到瑞萨（Renesas）开发板并进入系统（systemd 244+，root 无密码，系统含 opkg/rpm/dpkg）。
- 本文档给出可直接复制粘贴到设备上的常用命令、注意事项与示例脚本（prepare-board.sh）。

重要确认命令（在设备上执行一次）
- 查看系统与内核：
  - cat /etc/os-release
  - uname -a
- 确认 package manager：
  - which opkg && echo "opkg 可用"
  - which rpm && echo "rpm 可用"
  - which dpkg && echo "dpkg 可用"
- 确认 systemd：
  - systemctl --version
  - ps -p 1 -o comm=

常用包管理（不要混用）
- opkg（.ipk）
  - opkg update
  - opkg list | grep <name>
  - opkg install <pkg>
  - opkg install /tmp/foo.ipk
  - opkg remove <pkg>
- rpm（.rpm）
  - rpm -Uvh /tmp/foo.rpm
  - rpm -qa | grep <name>
- dpkg（.deb）
  - dpkg -i /tmp/foo.deb
  - apt-get -f install  (如果存在 apt)

systemd（服务管理）
- systemctl start|stop|restart <service>
- systemctl enable <service>
- systemctl status <service>
- journalctl -u <service> -f
- journalctl -b

用户与认证
- 立即设置 root 密码（强烈建议）：
  - passwd
- 创建普通用户：
  - useradd -m -s /bin/bash devuser
  - passwd devuser
- 安装 sudo（优先 opkg）并赋权：
  - opkg update && opkg install sudo
  - echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
  - chmod 440 /etc/sudoers.d/devuser

SSH / 密钥
- 添加公钥到 root：
  - mkdir -p /root/.ssh && chmod 700 /root/.ssh
  - echo "ssh-rsa AAAA... user@host" >> /root/.ssh/authorized_keys
  - chmod 600 /root/.ssh/authorized_keys
- 禁用密码登录（在确认 key 可用后）：
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd

文件传输
- scp 从主机传文件到板子：
  - scp ./mybin root@<ip>:/usr/bin/
  - ssh root@<ip> "chmod +x /usr/bin/mybin"
- rsync（若可用）：
  - rsync -avz ./dir/ root@<ip>:/opt/myapp/

根文件系统与持久化
- 临时将根分区设为可写：
  - mount -o remount,rw /
- 永久修改请在 Yocto 层做 overlay 或把配置打包进镜像（recipe），不要仅在设备运行时改。

调试与常用命令
- dmesg | less
- journalctl -xe
- ps aux | grep <proc>
- top / free -h / df -h / lsblk
- ss -tuln

常见陷阱
- 混用 opkg/rpm/dpkg 管理同一套软件会冲突
- 在设备上直接编译或做临时改动会破坏可重现性
- 刷写磁盘（dd/mkfs）时务必确认设备名，避免误操作

脚本/自动化建议
- 在主机用 Yocto SDK 或交叉工具链构建并打包（ipk/rpm/deb），通过 scp 到设备再安装
- 将常用配置（authorized_keys、systemd unit）做成 recipe 加入 image

准备好的示例脚本：prepare-board.sh（见仓库）
- 用途：一次性设置 root 密码/创建 devuser/安装 sudo（opkg）/添加公钥/禁用密码登录（可选）
- 使用方法（示例）：
  - scp prepare-board.sh root@<ip>:/root/
  - ssh root@<ip> "chmod +x /root/prepare-board.sh && /root/prepare-board.sh"

许可证与安全
- 请勿把私钥或明文密码提交到仓库
- 生产设备请使用 key-based authentication 并关闭密码登录

如需我把更多内容（比如把 ipk/rpm 搜索与替代包示例、或 image-level 的 recipe 示例）也加入到 README，请告诉我需要哪些包或你的 Yocto 层信息.