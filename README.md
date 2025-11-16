# Ubuntu-Command-Simplification-Tool
此工具的开发皆在于简化Ubuntu命令使用户在更便捷的环境下完成工作
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
