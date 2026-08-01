# Ubuntu-Command-Simplification-Tool
通过大量集合封装简化命令、减少操作步骤，显著提升工作效率和便捷度
# 下载与使用
使用此命令将主命令文件下载到您的设备
```bash
wget -qO UCST-English https://raw.githubusercontent.com/HXLG-F/Ubuntu-Command-Simplification-Tool/main/UCST-English
```
下载完成后，将主命令文件移动至这个目录
```bash
sudo mv UCST-English /usr/local/bin/
```
赋予权限
```bash
sudo chmod +x /usr/local/bin/UCST-English
```
# 安装完成后，需重启系统以保证符号链接生效
# 卸载工具
```bash
sudo rm -f /usr/local/bin/UCST-English
```
# 有关此工具的详细内容请查看使用说明

# 当前版本：Beta0.75
该版本针对SAI交互进行了大规模改版，同时根据ColudAI官方要求更新了Token配置方法。
新增命令：fix、sshre（ssh紧急救援服务）、update、translate、service
您可在装载了此命令工具的终端中使用“helpUCST”命令查看各个命令概述功能

# 声明
开发者支持并鼓励广大用户和爱好者进行二次开发，但开发者保留对该工具一切最终解释权
AI功能（SAI）暂不成熟，仍处于实验开发阶段，请谨慎使用
