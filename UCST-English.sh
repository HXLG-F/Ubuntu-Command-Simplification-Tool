#!/bin/bash
#项目创建于2025年10月25日 
#QmV0YTAuNzAgMjAyNi0wNi0zMA==                                            
#Ubuntu Command Simplification Tool——————Ubuntu命令简化工具      使用Deepseek辅助研发/设计
#2026.6.30 Beta0.66测试版本：针对SAI交互界面进行了重制，同时依据coludai官方文档要求修正了token生成规则。新增service命令，用于统一查看/解决服务问题。
#请注意：UCST目前仅对Ubuntu系统命令进行简化，功能性工具组件（如ssh等）、第三方工具组件及驱动程序组件命令不予简化处理
#请适时适况使用该工具
#基础设置
export LC_ALL=C.UTF-8 2>/dev/null
export LANG=C.UTF-8 2>/dev/null
#UCST-全局系统
export UCST_SILENT_INSTALL=1
#全局依赖映射表（命令 -> 包名）
declare -A UCST_DEP_MAP=(
    #account与SAI
    ["base64"]="coreutils"
    ["tr"]="coreutils"
    ["cut"]="coreutils"
    #？
    ["jq"]="jq"                     
    ["md5sum"]="coreutils"          
    #基础系统命令
    ["lsb_release"]="lsb-release"
    ["lscpu"]="util-linux"
    ["lspci"]="pciutils"
    ["lshw"]="lshw"
    ["dmidecode"]="dmidecode"
    ["lsblk"]="util-linux"
    ["blkid"]="util-linux"
    ["parted"]="parted"
    ["smartctl"]="smartmontools"
    #网络工具
    ["curl"]="curl"
    ["wget"]="wget"
    ["aria2c"]="aria2"
    ["axel"]="axel"
    ["ftp"]="ftp"
    ["ethtool"]="ethtool"
    ["ss"]="iproute2"
    ["hostname"]="hostname"
    ["ip"]="iproute2"
    #进程/系统监控
    ["ps"]="procps"
    ["top"]="procps"
    ["htop"]="htop"
    ["kill"]="procps"
    ["uptime"]="procps"
    ["free"]="procps"
    ["df"]="coreutils"
    ["du"]="coreutils"
    #文件/文本处理
    ["grep"]="grep"
    ["sed"]="sed"
    ["awk"]="gawk"
    ["cut"]="coreutils"
    ["tr"]="coreutils"
    ["sort"]="coreutils"
    ["uniq"]="coreutils"
    ["head"]="coreutils"
    ["tail"]="coreutils"
    ["find"]="findutils"
    ["stat"]="coreutils"
    ["file"]="file"
    ["tar"]="tar"
    ["gzip"]="gzip"
    ["zip"]="zip"
    ["unzip"]="unzip"
    ["rsync"]="rsync"
    ["tree"]="tree"
    #代码/开发工具
    ["python3"]="python3"
    ["node"]="nodejs"
    ["npm"]="npm"
    ["shellcheck"]="shellcheck"
    ["jq"]="jq"
    ["yq"]="yq"
    ["xmllint"]="libxml2-utils"
    ["tidy"]="tidy"
    ["csslint"]="csslint"
    #硬件/驱动工具
    ["nvidia-smi"]="nvidia-utils"
    ["radeontop"]="radeontop"
    ["sensors"]="lm-sensors"
    ["acpi"]="acpi"
    #其他工具
    ["bc"]="bc"
    ["pandoc"]="pandoc"
    ["neofetch"]="neofetch"
    ["dialog"]="dialog"
    ["whiptail"]="whiptail"
)
_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}
_silent_install() {
    local pkg="$1"
    if _cmd_exists "apt-get"; then
        local pkg_manager="apt-get"
    elif _cmd_exists "apt"; then
        pkg_manager="apt"
    else
        return 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        $pkg_manager update >/dev/null 2>&1
        $pkg_manager install -y "$pkg" >/dev/null 2>&1
        return $?
    else
        if _cmd_exists "sudo"; then
            sudo $pkg_manager update >/dev/null 2>&1
            sudo $pkg_manager install -y "$pkg" >/dev/null 2>&1
            return $?
        else
            $pkg_manager update >/dev/null 2>&1
            $pkg_manager install -y "$pkg" >/dev/null 2>&1 2>/dev/null
            return $?
        fi
    fi
}
if ! declare -f _generate_token_for_api >/dev/null; then
    _generate_token_for_api() {
        local prompt="$1"
        local current_date=$(date +"%Y-%m-%d")
        local date_md5=$(echo -n "$current_date" | md5sum | awk '{print $1}')
        local date_md5_six="${date_md5:0:6}"
        local combined_str="${prompt}${date_md5_six}"
        local token=$(echo -n "$combined_str" | md5sum | awk '{print $1}')
        echo "$token"
    }
fi
_translate_enable() {
    # 先验证 CA
    echo "正在验证 coludai 账户与 CA..."
    if ! _translate_validate_ca; then
        echo "验证失败，无法启用报错翻译功能"
        echo "请确保已正确执行 'account -s' 并确认 CA 有效"
        return 1
    fi

    # 如果已经启用，则跳过
    if [ -n "$UCST_TRANSLATE_ACTIVE" ] && [ "$UCST_TRANSLATE_ACTIVE" = "1" ]; then
        echo "报错翻译已处于启用状态"
        return 0
    fi

    # 创建命名管道
    local fifo="/tmp/.ucst_translate_fifo_$$"
    mkfifo "$fifo"
    # 启动守护进程（后台）
    _translate_daemon "$fifo" &
    local daemon_pid=$!
    # 保存 PID 以便后续清理
    echo "$daemon_pid" > "/tmp/.ucst_translate_daemon_pid_$$"

    # 保存原始 stderr 并重定向到 FIFO
    exec 3>&2
    exec 2> "$fifo"

    # 设置 PROMPT_COMMAND 钩子
    _UCST_ORIG_PROMPT_COMMAND="$PROMPT_COMMAND"
    PROMPT_COMMAND="_translate_check_and_translate"

    # 设置环境变量标记已启用
    export UCST_TRANSLATE_ACTIVE=1
    export UCST_TRANSLATE_FIFO="$fifo"
    echo "报错翻译已启用（原始错误实时显示，翻译结果将在命令结束后追加）"
    return 0
}
_translate_disable() {
    if [ -z "$UCST_TRANSLATE_ACTIVE" ] || [ "$UCST_TRANSLATE_ACTIVE" != "1" ]; then
        echo "报错翻译未启用"
        return 0
    fi

    # 恢复 stderr
    exec 2>&3
    exec 3>&-

    # 恢复 PROMPT_COMMAND
    PROMPT_COMMAND="$_UCST_ORIG_PROMPT_COMMAND"

    # 清理 FIFO 和守护进程
    local fifo="$UCST_TRANSLATE_FIFO"
    local pid_file="/tmp/.ucst_translate_daemon_pid_$$"
    if [ -f "$pid_file" ]; then
        local daemon_pid=$(cat "$pid_file")
        kill "$daemon_pid" 2>/dev/null
        rm -f "$pid_file"
    fi
    rm -f "$fifo" 2>/dev/null

    unset UCST_TRANSLATE_ACTIVE
    unset UCST_TRANSLATE_FIFO
    echo "报错翻译已禁用"
}
_translate_check_and_translate() {
    local exit_code=$?
    # 如果退出码为 0，不做任何事
    if [ $exit_code -eq 0 ]; then
        return 0
    fi

    # 获取错误缓存
    local error_cache="/tmp/.ucst_last_error_$$"
    if [ ! -f "$error_cache" ]; then
        return 0
    fi
    local error_text=$(cat "$error_cache")
    > "$error_cache"   # 清空缓存

    # 如果错误为空，跳过
    if [ -z "$error_text" ]; then
        return 0
    fi

    # 获取完整命令
    local full_cmd="$BASH_COMMAND"

    # 如果命令是 translate 本身，跳过（防止死循环）
    if [[ "$full_cmd" == "translate"* ]] || [[ "$full_cmd" == *"command_translate"* ]]; then
        return 0
    fi

    # 检查危险命令
    local is_dangerous=0
    if _is_dangerous_cmd "$full_cmd"; then
        is_dangerous=1
    fi

    # 判断错误长度
    local err_len=${#error_text}
    if [ $err_len -gt 2000 ]; then
        # 长错误：保存到文件，立即返回（不阻塞）
        local timestamp=$(date +%Y%m%d_%H%M%S_%N)
        local err_file="$UCST_TRANSLATE_CACHE_DIR/error_${timestamp}.log"
        echo "$error_text" > "$err_file"
        echo "错误内容过长，已保存到文件: $err_file"
        if [ $is_dangerous -eq 1 ]; then
            echo -e "${COLOR_RED}此命令高度危险，请谨慎操作${COLOR_RESET}"
        fi
        return 0
    fi

    # 正常长度：同步调用 SAI 翻译，等待最多 2 秒
    echo "正在翻译错误信息..."
    local translation_result=""
    local translate_success=0

    # 构造提示词
    local prompt="翻译以下错误信息，直接提供翻译结果，不要产生任何多余回答内容：\n错误信息: $error_text\n由用户输入的产生上述错误信息的完整命令: $full_cmd"

    # 调用 SAI-Coder API（同步，2秒超时）
    local config_file="$HOME/.ucst_sai_config"
    if [ -f "$config_file" ]; then
        local ca=$(grep '^ca=' "$config_file" | cut -d"'" -f2 2>/dev/null)
        local api_url=$(grep '^api_url=' "$config_file" | cut -d"'" -f2 2>/dev/null)
        [ -z "$api_url" ] && api_url="https://ai.coludai.cn"
        if [ -n "$ca" ]; then
            local token=$(_generate_token_for_api "$prompt")
            local json_data="{\"prompt\":\"$prompt\",\"token\":\"$token\",\"stream\":false,\"sysprompt\":\"\"}"
            local response
            response=$(timeout 2 curl -s -X POST "${api_url}/api/chat/coder" \
                -H "Content-Type: application/json" \
                -H "ca: $ca" \
                -d "$json_data" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$response" ]; then
                translation_result=$(echo "$response" | jq -r '.output // ""' 2>/dev/null)
                if [ -n "$translation_result" ] && [ "$translation_result" != "null" ]; then
                    translate_success=1
                fi
            fi
        fi
    fi

    if [ $translate_success -eq 1 ]; then
        echo ""
        echo "--- 翻译结果 ---"
        echo "$translation_result"
    else
        echo ""
        echo "翻译失败: 无法获取翻译结果（可能超时或 API 错误）"
    fi

    if [ $is_dangerous -eq 1 ]; then
        echo -e "${COLOR_RED}此命令高度危险，请谨慎操作${COLOR_RESET}"
    fi
    echo "----------------"
}
# 验证 CA 是否有效（调用聊天 API 快速测试）
_translate_validate_ca() {
    local config_file="$HOME/.ucst_sai_config"
    if [ ! -f "$config_file" ]; then
        echo "错误: 未找到 coludai 配置文件，请先运行 'account -s' 设置账户和 CA"
        return 1
    fi
    local ca=$(grep '^ca=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    local api_url=$(grep '^api_url=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    [ -z "$api_url" ] && api_url="https://ai.coludai.cn"
    if [ -z "$ca" ]; then
        echo "错误: 配置文件中未找到 CA，请重新运行 'account -s'"
        return 1
    fi
    # 发送测试请求
    local test_prompt="test"
    local test_token=$(_generate_token_for_api "$test_prompt")
    local response=$(timeout 3 curl -s -X POST "${api_url}/api/chat" \
        -H "Content-Type: application/json" \
        -H "ca: $ca" \
        -d "{\"prompt\":\"$test_prompt\",\"token\":\"$test_token\",\"stream\":false}")
    if echo "$response" | jq -e '.output' >/dev/null 2>&1; then
        return 0
    else
        echo "错误: CA 验证失败，请检查 CA 是否有效或网络连接"
        echo "详细信息: $response"
        return 1
    fi
}
_translate_daemon() {
    local fifo="$1"
    local error_cache="/tmp/.ucst_last_error_$$"
    > "$error_cache"   # 清空缓存
    while read -r line; do
        # 实时输出到终端（stderr）
        echo "$line" >&2
        # 缓存到文件（保留最近一次命令的错误）
        echo "$line" >> "$error_cache"
    done < "$fifo"
}
# 检测是否为危险命令
_is_dangerous_cmd() {
    local cmd_line="$1"
    for pattern in "${UCST_DANGEROUS_PATTERNS[@]}"; do
        if [[ "$cmd_line" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}
UCST_TRANSLATE_STATE_FILE="$HOME/.ucst_translate_state"
UCST_TRANSLATE_CACHE_DIR="$HOME/.ucst_translate_cache"
mkdir -p "$UCST_TRANSLATE_CACHE_DIR" 2>/dev/null

# 危险命令模式（与之前一致）
declare -a UCST_DANGEROUS_PATTERNS=(
    "^rm -rf /"
    "^rm -rf /\*"
    "^rm -rf \*"
    "^mkfs\."
    "^dd if=/dev/zero of=/dev/sd"
    "^> /dev/sd"
    "^mv .* /dev/null"
    "^chmod -R 000 /"
    "^chown -R nobody /"
    ":\(\){ :\|:& };:"
    "sudo rm -rf"
    "dd if=/dev/urandom of=/dev/sd"
)

# 颜色定义
COLOR_RED='\033[31m'
COLOR_RESET='\033[0m'

# 保存原始 stderr 的文件描述符（用于恢复）
_UCST_ORIG_STDERR=0
_analyze_script_deps() {
    local script_path="$0"
    local deps=()
    local function_cmds=$(grep -oE 'command_[a-zA-Z_]+' "$script_path" | sed 's/command_//')
    local all_cmds=$(grep -oE '\b[a-zA-Z_][a-zA-Z0-9_-]*\b' "$script_path" | 
                     grep -vE '^[A-Z_]+$' |  # 排除全大写变量
                     grep -vE '^(echo|if|then|else|fi|case|esac|while|do|done|for|in|function|local|export|return|shift|set|unset|read|test|\[|\]|exit|break|continue)$' |  # 排除bash关键词
                     sort -u)
    deps=($(echo "$function_cmds $all_cmds" | tr ' ' '\n' | sort -u))
    local filtered_deps=()
    for dep in "${deps[@]}"; do
        if [ -n "${UCST_DEP_MAP[$dep]}" ]; then
            filtered_deps+=("$dep")
        fi
    done
    
    echo "${filtered_deps[@]}"
}
_check_and_install_all_deps() {
    if [ -f "/tmp/ucst_deps_installed.$(stat -c %i "$0" 2>/dev/null || echo "0")" ]; then
        return 0
    fi
    (
        #分析脚本依赖
        local all_deps=($(_analyze_script_deps))
        if [ ${#all_deps[@]} -eq 0 ]; then
            exit 0
        fi
        #收集缺失的依赖
        local missing_deps=()
        for dep in "${all_deps[@]}"; do
            if ! _cmd_exists "$dep"; then
                missing_deps+=("$dep")
            fi
        done
        if [ ${#missing_deps[@]} -eq 0 ]; then
            #标记为已安装
            touch "/tmp/ucst_deps_installed.$(stat -c %i "$0" 2>/dev/null || echo "0")" 2>/dev/null
            exit 0
        fi
        #并行安装缺失的依赖
        for dep in "${missing_deps[@]}"; do
            local pkg="${UCST_DEP_MAP[$dep]}"
            if [ -n "$pkg" ]; then
                _silent_install "$pkg" &
            fi
        done
        wait
        touch "/tmp/ucst_deps_installed.$(stat -c %i "$0" 2>/dev/null || echo "0")" 2>/dev/null
    ) &
    return 0
}
_quick_dep_check() {
    local critical_cmds=("lsb_release" "curl" "wget" "aria2c" "axel" "ftp" 
                        "lspci" "lscpu" "lsblk" "blkid" "ethtool" "ss")
    
    for cmd in "${critical_cmds[@]}"; do
        if ! _cmd_exists "$cmd"; then
            local pkg="${UCST_DEP_MAP[$cmd]}"
            if [ -n "$pkg" ]; then
                _silent_install "$pkg" &
            fi
        fi
    done
    wait
}
_init_ucst_deps() { #主初始化函数
    local timeout_pid
    (
        sleep 10
        echo "依赖检查超时，继续运行..." >/dev/null
    ) &
    timeout_pid=$!
    _quick_dep_check
    _check_and_install_all_deps &
    kill $timeout_pid 2>/dev/null
}
#立即执行依赖初始化（后台运行）
_init_ucst_deps & 
#下面是真正的UCST工具内容
CALLED_NAME=$(basename "$0") #获取调用
if [ "$CALLED_NAME" = "UCST-English" ]; then # 如果直接通过该命令包调用，使用第一个参数作为命令
    CMD="$1"
    shift #shift
else
    CMD="$CALLED_NAME" #如果通过符号链接调用，使用链接名作为命令
fi
ARGS="$@" #原有的命令函数定义保持不变
silent_link_verify() {
    local today=$(date +%Y%m%d) #每天第一次运行时检查
    local last_check_file="/tmp/.command_links_last_check"
    if [ -f "$last_check_file" ] && [ "$(cat "$last_check_file")" = "$today" ]; then #每天第一次运行时检查
        return 0
    fi
    local commands=("about" "list" "network" "disk" "ctime" "process" "helpUCST" "nkill" "open" "delete" "new" "mod" "driver" "backup" "check" "UCST" "download" "search" "account" "sai" "amend" "language" "restart" "service" "update" "translate" "sshre" "fix") #验证命令列表
    local main_command="/usr/local/bin/UCST-English"
    if [ ! -f "$main_command" ]; then #检查主命令文件
        return 1
    fi
    local current_perm=$(stat -c "%a" "$main_command" 2>/dev/null) #检查文件权限
    local expected_perm="755"
    if [ "$current_perm" != "$expected_perm" ]; then #若权限有问题，修复文件权限
        sudo chmod "$expected_perm" "$main_command" >/dev/null 2>&1
    fi
    for cmd in "${commands[@]}"; do #检查并修复所有命令链接的权限
        local link_path="/usr/local/bin/$cmd"
        if [ ! -L "$link_path" ] || [ "$(readlink "$link_path")" != "$main_command" ]; then #检查链接是否存在且正确
            sudo ln -sf "$main_command" "$link_path" >/dev/null 2>&1 #静默修复链接（不输出任何信息）
        fi
        if [ -L "$link_path" ]; then #修复链接文件的权限（如果需要，得看前段代码的判断结果）
            local link_perm=$(stat -c "%a" "$link_path" 2>/dev/null)
            if [ "$link_perm" != "$expected_perm" ]; then
                sudo chmod "$expected_perm" "$link_path" >/dev/null 2>&1
            fi
        fi
    done
    echo "$today" > "$last_check_file" #记录今天检查
    return 0
}
silent_link_verify >/dev/null 2>&1 & #静默运行链接验证（始终且持续静默）
command_about() {
    case "$ARGS" in
        "-a")
            echo "=== 详细信息 ==="
            echo "主机名: $(hostname)"
            echo "操作系统: $(lsb_release -ds 2>/dev/null || echo 'Ubuntu 24.04')"
            echo "内核版本: $(uname -r)"
            echo "系统架构: $(uname -m)"
            echo "处理器: $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//' || echo 'N/A')"
            echo "处理器核心数: $(nproc)"
            echo "系统运行时间: $(uptime -p | sed 's/up //')"
            echo "最后启动时间: $(who -b | awk '{print $3 " " $4}')"
            echo "当前用户: $(whoami)"
            echo "用户权限: $(id -un) ($(id -u))"
            echo "内存总量: $(free -h | awk 'NR==2{print $2}')"
            echo "已用内存: $(free -h | awk 'NR==2{print $3}')"
            echo "可用内存: $(free -h | awk 'NR==2{print $7}')"
            echo "内存使用率: $(free | awk 'NR==2{printf "%.1f%%", $3/$2*100}')"
            echo "交换空间: $(free -h | awk 'NR==3{print $2}')"
            echo "磁盘总量: $(df -h / | awk 'NR==2{print $2}')"
            echo "已用磁盘: $(df -h / | awk 'NR==2{print $3}')"
            echo "可用磁盘: $(df -h / | awk 'NR==2{print $4}')"
            echo "磁盘使用率: $(df -h / | awk 'NR==2{print $5}')"
            echo "IP地址: $(hostname -I)"
            echo "MAC地址: $(ip link show | grep -E '^[0-9]+:' | grep -v lo | head -1 | awk '{print $2}')"
            echo "时区: $(timedatectl show --value -p Timezone 2>/dev/null || echo 'UTC')"
            echo "区域设置: $(locale | grep LANG= | cut -d= -f2)"
            if grep -q microsoft /proc/version 2>/dev/null; then
                echo "环境: WSL (Windows Subsystem for Linux)"
                echo "Windows 主机名: $(grep nameserver /etc/resolv.conf | awk '{print $2}')"
                echo "WSL 版本: $(uname -r | grep -o 'WSL2' || echo 'WSL1')"
            else
                echo "环境: 原生 Linux"
            fi
            ;;
        "-c")
            echo "=== 处理器信息 ==="
            if command -v lscpu >/dev/null 2>&1; then
                echo "品牌: $(lscpu | grep "Vendor ID" | cut -d: -f2 | sed 's/^ *//')"
                echo "型号: $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')"
                echo "架构: $(lscpu | grep "Architecture" | cut -d: -f2 | sed 's/^ *//')"
                echo "核心数: $(nproc)"
                echo "状态: 驱动已安装，设备正在正常运行"
            else
                echo "状态: 无法获取处理器信息，请检查处理器是否正常工作或安装lscpu工具以获取信息"
            fi
            ;;
        "-g")
            echo "=== 显卡信息 ==="
            local gpu_detected=false #尝试多种方法获取多种显卡的信息
            if command -v lspci >/dev/null 2>&1; then #使用lspci显卡并提取型号
                local gpu_info=$(lspci | grep -iE "vga|3d|display" | head -1)
                if [ -n "$gpu_info" ]; then
                    local gpu_model=$(echo "$gpu_info" | sed 's/.*: //') #从lspci提取显卡型号
                    echo "设备: $gpu_model"
                    gpu_detected=true
                    if echo "$gpu_model" | grep -i "nvidia" >/dev/null; then #根据关键词判断品牌
                        echo "显卡品牌: NVIDIA"
                    elif echo "$gpu_model" | grep -i "amd" >/dev/null || echo "$gpu_model" | grep -i "ati" >/dev/null; then
                        echo "显卡品牌: AMD"
                    elif echo "$gpu_model" | grep -i "intel" >/dev/null; then
                        echo "显卡品牌: Intel"
                    else
                        local brand=$(echo "$gpu_info" | grep -o -iE "nvidia|amd|ati|intel" | head -1) #从设备描述中提取品牌信息
                        if [ -n "$brand" ]; then
                            echo "显卡品牌: $(echo "$brand" | tr '[:lower:]' '[:upper:]')"
                        fi
                    fi
                fi
            fi
            if command -v nvidia-smi >/dev/null 2>&1; then #检查英伟达显卡驱动状态
                local nvidia_info=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
                if [ -n "$nvidia_info" ]; then
                    echo "型号: $nvidia_info"
                    echo "状态: 驱动已安装，设备正在正常运行"
                    gpu_detected=true
                fi
            else
                if lspci | grep -i nvidia >/dev/null 2>&1; then #检查是否存在英伟达显卡但无状态
                    echo "品牌: NVIDIA"
                    echo "状态: 检测到有英伟达显卡存在，但无法获取设备状态，请检查驱动是否正确"
                    gpu_detected=true
                fi
            fi
            
            
            if command -v lshw >/dev/null 2>&1; then #使用lshw获取更详细的显卡信息（如果可用）
                local lshw_gpu=$(lshw -C display 2>/dev/null | head -10)
                if [ -n "$lshw_gpu" ] && [ "$gpu_detected" = false ]; then
                    echo "检测到的显卡:"
                    echo "$lshw_gpu" | grep -E "(product|vendor|description):" | head -5
                    gpu_detected=true
                fi
            fi
            if [ -d "/sys/class/drm" ] && [ "$gpu_detected" = false ]; then #检查/sys/class/drm目录
                local drm_cards=$(find /sys/class/drm -name "card*" -type l | grep -v "control" | sort)
                for card in $drm_cards; do
                    if [ -f "$card/device/uevent" ]; then
                        local drm_vendor=$(grep "DRIVER" "$card/device/uevent" | head -1 | cut -d= -f2)
                        local drm_product=$(grep "MODALIAS" "$card/device/uevent" | head -1 | cut -d= -f2)
                        if [ -n "$drm_vendor" ]; then
                            echo "DRM设备: $drm_vendor"
                            if [ -n "$drm_product" ]; then
                                echo "型号标识: $drm_product"
                            fi
                            gpu_detected=true
                            break
                        fi
                    fi
                done
            fi
            if [ "$gpu_detected" = false ]; then #如果未检测到任何显卡设备
                echo "状态: 未检测到显卡设备，请检查设备和驱动是否正常工作"
            else
                # 如果已经检测到 GPU 但没有显示具体状态，显示默认状态
                if ! echo "$(about -g)" | grep -q "状态:"; then
                    echo "状态: 设备已识别，但未能检测到设备状态"
                fi
            fi
            ;;
        "-o")
            echo "=== 操作系统信息 ==="
            echo "系统类型: $(uname -s)"
            echo "系统架构: $(uname -m)"
            echo "内核版本: $(uname -r)"
            echo "内核版本详细信息: $(uname -v)"
            echo "发行版: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
            echo "发行版 ID: $(lsb_release -is 2>/dev/null || cat /etc/os-release | grep ^ID= | cut -d= -f2)"
            echo "版本号: $(lsb_release -rs 2>/dev/null || cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | tr -d '\"')"
            echo "代码名称: $(lsb_release -cs 2>/dev/null || echo 'N/A')"
            
            if grep -q microsoft /proc/version 2>/dev/null; then
                echo "环境: WSL (Windows Subsystem for Linux)"
                echo "WSL 版本: $(uname -r | grep -o 'WSL2' || echo 'WSL1')"
            else
                echo "环境: 原生 Linux"
            fi
            
            echo "启动方式: $(ps -p 1 -o comm=)"
            echo "初始化系统: $(ps -p 1 -o comm=)"
            ;;
        "-s")
            echo "=== 用户信息 ==="
            echo "当前用户: $(whoami)"
            echo "用户 ID: $(id -u)"
            echo "组 ID: $(id -g)"
            echo "所属组: $(id -Gn)"
            echo "主目录: $HOME"
            echo "Shell: $SHELL"
            echo "登录终端: $(tty)"
            echo "登录时间: $(who | grep $(whoami) | awk '{print $3 " " $4}')"
            echo "sudo 权限: $(sudo -n true 2>/dev/null && echo "可用" || echo "不可用/需要密码")"
            echo "最近登录:"
            last -n 3 | head -4
            ;;
        "")
            echo "=== 基本信息 ==="
            echo "主机: $(hostname)"
            echo "用户: $(whoami)"
            echo "发行版: $(lsb_release -ds 2>/dev/null || echo 'Ubuntu 24.04')"
            echo "内核: $(uname -r)"
            echo "架构: $(uname -m)"
            echo "运行时间: $(uptime -p | sed 's/up //')"
            echo "内存总量: $(free -h | awk 'NR==2{print $2}')"
            echo "已用内存: $(free -h | awk 'NR==2{print $3}')"
            echo "可用内存: $(free -h | awk 'NR==2{print $7}')"
            echo "内存使用率: $(free | awk 'NR==2{printf "%.1f%%", $3/$2*100}')"
            echo "存储总量: $(df -h / | awk 'NR==2{print $2}')"
            echo "已用存储: $(df -h / | awk 'NR==2{print $3}')"
            echo "可用存储: $(df -h / | awk 'NR==2{print $4}')"
            echo "存储使用率: $(df -h / | awk 'NR==2{print $5}')"
            
            if grep -q microsoft /proc/version 2>/dev/null; then
                echo "环境: WSL"
                echo "Windows 主机: $(grep nameserver /etc/resolv.conf | awk '{print $2}')"
            else
                echo "环境: 原生 Linux"
            fi
            ;;
        *)
            echo "about 命令用法:"
            echo "  about       - 显示基本信息"
            echo "  about -a    - 显示详细信息"
            echo "  about -c    - 显示处理器信息"
            echo "  about -g    - 显示显卡信息"
            echo "  about -o    - 显示操作系统信息"
            echo "  about -s    - 显示用户信息"
            ;;
    esac
}
command_list() {  #文件列表
    ls -la "$ARGS"
}
command_network() { #查看网络
    case "$ARGS" in
        "-c")
            echo "=== 网卡及连接情况 ==="
            echo "网络接口列表:"
            ip link show
            echo ""
            echo "IP地址信息:"
            ip addr show
            echo ""
            echo "路由表:"
            ip route show
            echo ""
            echo "网络连接:"
            ss -tuln
            ;;
        "-i")
            echo "=== 网络信息 ==="
            echo "WSL IP: $(hostname -I)"
            echo "Windows 主机: $(grep nameserver /etc/resolv.conf | awk '{print $2}')"
            echo "网络接口:"
            ip addr show | grep -E "^\s*[0-9]+:" | awk '{print $2}' | tr -d :
            ;;
        *)
            echo "=== network 命令用法 ==="
            echo "network -c : 显示所有网卡及连接情况（包括虚拟网卡）"
            echo "network -i : 显示基本网络信息"
            ;;
    esac
}
# 检查是否为 WSL 环境
_is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}
# WSL 环境下获取 Windows 磁盘列表（驱动器号 + 卷标 + 文件系统 + 是否已挂载）
_wsl_get_disks() {
    # 使用 powershell.exe 获取所有可用驱动器（物理磁盘和网络驱动器）
    local ps_script='
        Get-WmiObject -Class Win32_LogicalDisk | 
        ForEach-Object {
            $drive = $_.DeviceID
            $label = $_.VolumeName
            $fs = $_.FileSystem
            $size = [math]::Round($_.Size/1GB, 1)
            $free = [math]::Round($_.FreeSpace/1GB, 1)
            Write-Output "$drive|$label|$fs|$size|$free"
        }
    '
    local disk_info
    disk_info=$(powershell.exe -Command "$ps_script" 2>/dev/null | tr -d '\r')
    if [ -z "$disk_info" ]; then
        # 如果 powershell 不可用，尝试 wmic
        disk_info=$(wmic logicaldisk get deviceid,volumename,filesystem,size,freespace 2>/dev/null | awk 'NR>1 {print $1"|"$2"|"$3"|"$4"|"$5}')
    fi
    echo "$disk_info"
}
# 检查某个驱动器是否已挂载（在 /mnt/ 下）
_is_mounted_in_wsl() {
    local drive_letter="$1"
    local mount_point="/mnt/$(echo "$drive_letter" | tr -d ':')"
    if mount | grep -q " $mount_point "; then
        return 0
    else
        return 1
    fi
}
# WSL 环境下挂载 Windows 驱动器
_mount_wsl_disk() {
    local drive_letter="$1"
    local mount_point="/mnt/$(echo "$drive_letter" | tr -d ':')"
    # 确保目录存在
    if [ ! -d "$mount_point" ]; then
        sudo mkdir -p "$mount_point"
    fi
    # 挂载（需要 root 权限）
    sudo mount -t drvfs "$drive_letter" "$mount_point"
    return $?
}
command_disk() { #查看磁盘
    echo "=== 磁盘使用情况 ==="
    df -h | grep -v tmpfs
    case "$ARGS" in
        "-m")
            # 硬盘挂载管理功能
            # 检查root权限
            if [ "$(id -u)" -ne 0 ]; then
                echo "错误: 挂载操作需要 root 权限"
                echo "请使用: sudo disk -m"
                return 1
            fi

            echo "=== 硬盘挂载管理 ==="
            if _is_wsl; then
                local disk_list=$(_wsl_get_disks)
                if [ -z "$disk_list" ]; then
                    echo "无法获取磁盘列表，请检查服务状态。若环境为WSL，请确保Windows中 powershell.exe 或 wmic 可用"
                    return 1
                fi

                local i=1
                declare -a disk_items=()
                echo ""
                echo "可用磁盘分区:"
                while IFS='|' read -r drive label fs size free; do
                    [ -z "$drive" ] && continue
                    drive_clean=$(echo "$drive" | tr -d ':')
                    mount_point="/mnt/${drive_clean}"
                    status="$(_is_mounted_in_wsl "$drive" && echo "已挂载" || echo "未挂载")"
                    printf "  %2d) %-3s  %-20s  %-8s  %6.1fGB (剩余 %5.1fGB)  [%s]\n" \
                        "$i" "$drive" "${label:-无卷标}" "$fs" "$size" "$free" "$status"
                    disk_items[$i]="$drive"
                    ((i++))
                done <<< "$disk_list"

                if [ $i -eq 1 ]; then
                    echo "未找到任何可用的磁盘分区"
                    return 1
                fi

                echo ""
                echo -n "请选择要操作的分区 (1-$((i-1))), 或输入 'q' 退出: "
                read -r choice
                if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
                    echo "操作已取消"
                    return 0
                fi
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
                    echo "无效的选择"
                    return 1
                fi

                local selected_drive="${disk_items[$choice]}"
                local mount_point="/mnt/$(echo "$selected_drive" | tr -d ':')"

                # 检查当前挂载状态
                if _is_mounted_in_wsl "$selected_drive"; then
                    echo "分区 $selected_drive 已挂载到 $mount_point"
                    echo "请选择操作:"
                    echo "  1) 卸载"
                    echo "  2) 取消"
                    echo -n "请选择 (1-2): "
                    read -r op
                    case "$op" in
                        1)
                            sudo umount "$mount_point"
                            echo "已卸载 $mount_point"
                            ;;
                        *)
                            echo "操作已取消"
                            ;;
                    esac
                else
                    echo "分区 $selected_drive 未挂载，准备挂载到 $mount_point"
                    echo -n "确认挂载? (y/N): "
                    read -r confirm
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        _mount_wsl_disk "$selected_drive"
                        if [ $? -eq 0 ]; then
                            echo "挂载成功！现在可以通过 $mount_point 访问"
                        else
                            echo "挂载失败，请检查是否已安装 drvfs 支持"
                        fi
                    else
                        echo "操作已取消"
                    fi
                fi
                return 0
            fi
            # 扫描所有块设备
            echo "正在扫描存储设备..."
            echo ""
            
            # 获取所有块设备信息（包括已挂载和未挂载的）
            local devices=()
            local device_info_list=()
            local i=1
            
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    local device_name=$(echo "$line" | awk '{print $1}')
                    local device_path="/dev/$device_name"
                    
                    # 获取详细设备信息
                    local size=$(echo "$line" | awk '{print $2}')
                    local fstype=$(echo "$line" | awk '{print $3}')
                    local mountpoint=$(echo "$line" | awk '{print $4}')
                    local label=$(echo "$line" | awk '{print $5}')
                    local model=$(echo "$line" | awk '{print $6}')
                    
                    devices[$i]="$device_path"
                    device_info_list[$i]="$size|$fstype|$mountpoint|$label|$model"
                    
                    if [ -z "$mountpoint" ] || [ "$mountpoint" = "" ]; then
                        echo "  $i) $device_path - ${size} - $fstype - $label - $model - [未挂载]"
                    else
                        echo "  $i) $device_path - ${size} - $fstype - $label - $model - [已挂载: $mountpoint]"
                    fi
                    i=$((i + 1))
                fi
            done < <(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,MODEL -r | grep -E "^(sd|nvme|vd)" | grep -v "├\|└")
            
            if [ $i -eq 1 ]; then
                echo "未找到可用的存储设备"
                return 1
            fi
            
            echo ""
            echo -n "请选择要操作的设备 (1-$((i-1))), 或输入 'q' 退出: "
            read -r device_choice
            
            if [ "$device_choice" = "q" ] || [ "$device_choice" = "Q" ]; then
                echo "操作已取消"
                return 0
            fi
            
            if [ "$device_choice" -lt 1 ] || [ "$device_choice" -ge $i ]; then
                echo "错误: 无效的选择"
                return 1
            fi
            
            local selected_device="${devices[$device_choice]}"
            local device_info="${device_info_list[$device_choice]}"
            local size=$(echo "$device_info" | cut -d'|' -f1)
            local fstype=$(echo "$device_info" | cut -d'|' -f2)
            local mountpoint=$(echo "$device_info" | cut -d'|' -f3)
            local label=$(echo "$device_info" | cut -d'|' -f4)
            local model=$(echo "$device_info" | cut -d'|' -f5)
            
            # 检查设备是否已挂载
            if [ -n "$mountpoint" ] && [ "$mountpoint" != "" ]; then
                echo ""
                echo "设备 $selected_device 已挂载到: $mountpoint"
                echo "请选择操作:"
                echo "  1) 卸载设备"
                echo "  2) 重新挂载到其他位置"
                echo "  3) 取消"
                echo -n "请选择 (1-3): "
                read -r operation_choice
                
                case "$operation_choice" in
                    1)
                        echo "正在卸载 $selected_device ..."
                        if umount "$selected_device"; then
                            echo "设备已成功卸载"
                            
                            # 检查是否为fstab中的永久挂载，如果是则询问是否删除
                            if grep -q "$selected_device" /etc/fstab 2>/dev/null; then
                                echo -n "检测到该设备在 /etc/fstab 中有永久挂载配置，是否删除? (y/N): "
                                read -r remove_fstab
                                if [ "$remove_fstab" = "y" ] || [ "$remove_fstab" = "Y" ]; then
                                    sudo sed -i "\|$selected_device|d" /etc/fstab
                                    echo "已从 /etc/fstab 中删除挂载配置"
                                fi
                            fi
                        else
                            echo "卸载失败，设备可能正在使用中"
                        fi
                        ;;
                    2)
                        # 先卸载设备
                        echo "正在卸载 $selected_device ..."
                        if ! umount "$selected_device"; then
                            echo "卸载失败，无法重新挂载"
                            return 1
                        fi
                        echo "设备已成功卸载"
                        # 然后继续挂载流程
                        ;;
                    3)
                        echo "操作已取消"
                        return 0
                        ;;
                    *)
                        echo "无效选择，操作已取消"
                        return 1
                        ;;
                esac
                
                # 如果用户选择了取消或卸载，直接返回
                if [ "$operation_choice" = "1" ] || [ "$operation_choice" = "3" ]; then
                    return 0
                fi
                # 如果用户选择了重新挂载，继续执行下面的挂载流程
            fi
            
            # 挂载流程 - 先询问挂载点
            echo ""
            echo "选择的设备: $selected_device"
            echo ""
            
            # 询问挂载点
            local default_mountpoint="/mnt/$(basename "$selected_device")"
            echo -n "请输入挂载点路径 [默认: $default_mountpoint]: "
            read -r mount_point
            
            if [ -z "$mount_point" ]; then
                mount_point="$default_mountpoint"
            fi
            
            # 显示设备信息
            echo ""
            echo "设备信息:"
            echo "  文件系统: $fstype"
            echo "  大小: $size"
            echo "  标签: $label"
            echo "  型号: $model"
            echo "  挂载点: $mount_point"
            echo ""
            
            # 创建挂载点目录
            if [ ! -d "$mount_point" ]; then
                echo -n "挂载点目录不存在，是否创建? (Y/n): "
                read -r create_dir
                if [ "$create_dir" != "n" ] && [ "$create_dir" != "N" ]; then
                    mkdir -p "$mount_point"
                    if [ $? -ne 0 ]; then
                        echo "错误: 无法创建挂载点目录"
                        return 1
                    fi
                    echo "已创建挂载点目录: $mount_point"
                else
                    echo "操作已取消"
                    return 1
                fi
            fi
            
            # 检查挂载点是否为空
            if [ "$(ls -A "$mount_point" 2>/dev/null)" ]; then
                echo "警告: 挂载点目录 $mount_point 不为空"
                echo -n "是否继续? (y/N): "
                read -r continue_mount
                if [ "$continue_mount" != "y" ] && [ "$continue_mount" != "Y" ]; then
                    echo "操作已取消"
                    return 1
                fi
            fi
            
            # 执行挂载
            echo "正在挂载 $selected_device 到 $mount_point ..."
            if mount "$selected_device" "$mount_point"; then
                echo "设备已成功挂载"
                
                # 询问是否永久挂载
                echo ""
                echo -n "是否设置为永久挂载 (写入 /etc/fstab)? (y/N): "
                read -r permanent_mount
                
                if [ "$permanent_mount" = "y" ] || [ "$permanent_mount" = "Y" ]; then
                    local uuid=$(blkid -s UUID -o value "$selected_device")
                    if [ -n "$uuid" ]; then
                        local fstab_entry="UUID=$uuid $mount_point $fstype defaults 0 2"
                        if ! grep -q "$uuid" /etc/fstab 2>/dev/null; then
                            echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
                            echo "已添加到 /etc/fstab (使用UUID: $uuid)"
                        else
                            echo "该设备已在 /etc/fstab 中存在"
                        fi
                    else
                        echo "无法获取设备UUID，使用设备路径代替"
                        local fstab_entry="$selected_device $mount_point $fstype defaults 0 2"
                        if ! grep -q "$selected_device" /etc/fstab 2>/dev/null; then
                            echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
                            echo "已添加到 /etc/fstab (使用设备路径)"
                        else
                            echo "该设备已在 /etc/fstab 中存在"
                        fi
                    fi
                else
                    echo "此为临时挂载，重启后需要重新挂载"
                fi
                
                # 显示挂载结果
                echo ""
                echo "挂载信息:"
                df -h | grep "$mount_point"
            else
                echo "挂载失败，请检查设备状态和文件系统"
            fi
            ;;
        *)
            echo "=== 磁盘使用情况 ==="
            df -h | grep -v tmpfs
            echo ""
            echo "使用 'disk -m' 管理硬盘挂载"
            ;;
    esac
}
command_ctime() {
    echo "本地时间: $(date +"%Y-%m-%d %H:%M:%S.%N" | cut -c1-23)"
    echo "标准格式: $(date)"
    echo "UNIX时间戳: $(date +%s)"
    local timezone_info=""
    if command -v timedatectl >/dev/null 2>&1; then
        timezone_info=$(timedatectl show --property=Timezone --value 2>/dev/null)
    fi
    
    if [ -n "$timezone_info" ]; then
        echo "系统时区: $timezone_info"
    else
        if [ -f /etc/timezone ]; then
            timezone_info=$(cat /etc/timezone)
            echo "系统时区: $timezone_info"
        elif [ -h /etc/localtime ]; then
            timezone_info=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
            echo "系统时区: $timezone_info"
        else
            echo "系统时区: 未知"
        fi
    fi
    local offset=$(date +%z) #显示时区
    if [ -n "$offset" ]; then
        echo "时区: UTC${offset:0:3}:${offset:3:2}"
    fi
    echo "年-月-日: $(date +"%Y-%m-%d")" #显示详细的日期信息
    echo "星期: $(date +"%A")"
    echo "系统运行: $(uptime -p | sed 's/up //')"
    if command -v timedatectl >/dev/null 2>&1; then
        local ntp_sync=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)
        if [ "$ntp_sync" = "yes" ]; then
            echo "时间同步已启用(WSL环境下与Windows同步)"
        else
            echo "时间同步未启用"
        fi
    fi
    if command -v hwclock >/dev/null 2>&1; then
        echo "硬件时钟: $(hwclock --show 2>/dev/null | cut -d' ' -f1-7 || echo "无法读取")"
    fi
}
command_process() { #查看当前正在运行的所有进程
    case "$ARGS" in
        "list")
            echo "=== 进程列表 (前10个) ==="
            ps aux --sort=-%cpu | head -11
            ;;
        "all")
            ps aux
            ;;
        *)
            echo "用法: process list|all"
            ;;
    esac
}
command_nkill() {
    if [ "$(id -u)" -ne 0 ]; then #检查用户
        echo "错误: nkill 命令必须在 root 用户下使用"
        echo "请使用: sudo nkill [选项] <进程ID>"
        return 1
    fi
    local option="" #解析参数
    local pid=""
    case "$ARGS" in #处理不同参数格式
        -p\ *)
            option="-p" #格式: nkill -p 114514
            pid=$(echo "$ARGS" | awk '{print $2}')
            ;;
        -c\ *)
            option="-c" #格式:nkill -c 114514
            pid=$(echo "$ARGS" | awk '{print $2}')
            ;;
        -p*)
            option="-p" #格式: nkill -p114514
            pid="${ARGS#-p}"
            ;;
        -c*)
            option="-c" #格式: nkill -c114514
            pid="${ARGS#-c}"
            ;;
        *)
            if [[ "$ARGS" =~ ^[0-9]+$ ]]; then #格式: nkill 114514 或 nkill -p 114514（已经处理过）
                pid="$ARGS" #若为数字，直接作为PID
            else
                option="" #其他情况显示用法
                pid=""
            fi
            ;;
    esac
    pid=$(echo "$pid" | tr -d '[:space:]') #去除PID中的空格，规避提取错误
    if [ -z "$pid" ]; then #展示用法
        echo "nkill 命令用法:"
        echo "nkill <进程ID>     - 强制杀死进程"
        echo "nkill -p <进程ID>  - 暂停进程工作"
        echo "nkill -c <进程ID>  - 继续被暂停的进程"
        echo "注意: 所有 nkill 命令必须在 root 用户下使用"
        echo "示例:"
        echo "nkill 114514"
        echo "nkill -p 114514"
        echo "nkill -p114514"
        echo "nkill -c 114514"
        return 1
    fi
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then #检查PID是否为数字
        echo "错误: 进程ID必须是数字，当前输入: '$pid'"
        return 1
    fi
    if ! ps -p "$pid" > /dev/null 2>&1; then #检查进程是否存在
        echo "错误: 进程 $pid 不存在"
        return 1
    fi
    case "$option" in #判定命令后缀，根据选项要求执行操作
        "-p")
            echo "警告: 您将要暂停进程 $pid" #暂停指定的进程
            echo -n "确定要暂停此进程吗？(y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if kill -STOP "$pid"; then
                    echo "已暂停进程: $pid"
                else
                    echo "暂停进程失败: $pid"
                fi
            else
                echo "操作已取消"
            fi
            ;;
        "-c")
            echo "警告: 您将要继续进程 $pid" #继续被暂停的进程
            echo -n "确定要继续此进程吗？(y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if kill -CONT "$pid"; then
                    echo "继续进程: $pid"
                else
                    echo "继续进程失败: $pid"
                fi
            else
                echo "操作已取消"
            fi
            ;;
        *)
            local process_info=$(ps -p "$pid" -o pid,user,comm,cmd --no-headers 2>/dev/null) #强制杀死进程
            echo "警告: 您将要强制杀死进程 $pid"
            echo "进程信息: $process_info"
            echo -n "确定要强制杀死此进程吗？(y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if kill -9 "$pid"; then
                    echo "已杀死进程: $pid"
                else
                    echo "杀死进程失败: $pid"
                fi
            else
                echo "操作已取消"
            fi
            ;;
    esac
}
command_open() {
    if [ -z "$ARGS" ]; then
        echo "open 命令用法:"
        echo "  open <文件路径> - 在命令行环境中打开指定文件"
        echo ""
        echo "支持的文件类型:"
        echo "  文本文件 (.txt, .log, .conf, .sh, .py, .js, .html, .css, .json, .xml 等)"
        echo "  代码文件 (.c, .cpp, .java, .php, .rb, .go, .rs 等)"
        echo "  配置文件 (.ini, .cfg, .yml, .yaml, .toml 等)"
        echo "  文档文件 (.md, .rst, .tex 等)"
        echo ""
        echo "示例:"
        echo "  open document.txt"
        echo "  open script.sh"
        echo "  open /etc/hosts"
        return 1
    fi
    local file_path="$ARGS"
    if [ ! -e "$file_path" ]; then
        echo "文件 '$file_path' 不存在"
        return 1
    fi
    if [ ! -f "$file_path" ]; then
        echo "'$file_path' 不是文件，这可能是一个目录或不可用的位置"
        return 1
    fi
    if [ ! -r "$file_path" ]; then
        echo "您没有访问 '$file_path' 的权限"
        return 1
    fi
    echo "正在打开: $file_path"
    local file_type=$(file -b "$file_path" 2>/dev/null)
    if [ $? -ne 0 ]; then
        file_type="未知文件类型"
    fi
    if file "$file_path" | grep -q "text"; then
        if command -v less >/dev/null 2>&1; then
            less "$file_path"
        elif command -v more >/dev/null 2>&1; then
            more "$file_path"
        elif command -v nano >/dev/null 2>&1; then
            nano "$file_path"
        elif command -v vim >/dev/null 2>&1; then
            vim "$file_path"
        elif command -v vi >/dev/null 2>&1; then
            vi "$file_path"
        else
            cat "$file_path"
        fi
        return 0
    else
        echo "该文件类型不受支持"
        echo "检测到的文件类型: $file_type"
        return 1
    fi
}
command_delete() {
    if [ -z "$ARGS" ]; then
        echo "delete 命令用法:"
        echo "  delete <路径> - 删除指定的文件或目录"
        echo ""
        echo "注意: 删除操作不可逆，请谨慎使用"
        echo ""
        echo "示例:"
        echo "  delete file.txt"
        echo "  delete /path/to/directory"
        echo "  delete /path/to/file"
        return 1
    fi
    local target_path="$ARGS"
        if [ ! -e "$target_path" ]; then
        echo "错误: 路径 '$target_path' 不存在"
        return 1
    fi
    local item_type=""
    local item_info=""
    
    if [ -f "$target_path" ]; then
        item_type="文件"
        item_info="大小: $(du -h "$target_path" | cut -f1)"
    elif [ -d "$target_path" ]; then
        item_type="目录"
        local file_count=$(find "$target_path" -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$target_path" -type d 2>/dev/null | wc -l)
        item_info="包含: $file_count 个文件, $(($dir_count - 1)) 个子目录"
    elif [ -L "$target_path" ]; then
        item_type="符号链接"
        item_info="指向: $(readlink "$target_path")"
    else
        item_type="特殊文件"
    fi
    echo "类型: $item_type"
    echo "路径: $target_path"
    if [ -n "$item_info" ]; then
        echo "信息: $item_info"
    fi
    echo "警告: 此操作不可逆!"
    echo -n "确定要删除吗？(y|N): "
    read -r user_confirm
    if [ "$user_confirm" != "y" ]; then
        echo "操作已取消"
        return 0
    fi
    echo "正在删除..."
    if [ -f "$target_path" ] || [ -L "$target_path" ]; then
        if rm -f "$target_path"; then
            echo "已删除 $item_type: $target_path"
        else
            echo "删除失败: $target_path"
            return 1
        fi
    elif [ -d "$target_path" ]; then
        if rm -rf "$target_path"; then
            echo "已删除目录: $target_path"
        else
            echo "删除目录失败: $target_path"
            return 1
        fi
    else
        echo "无法识别的文件类型: $target_path"
        return 1
    fi
    return 0
}
command_new() {
    if [ -z "$ARGS" ]; then
        echo "new 命令用法:"
        echo "new <路径> - 新建目录或文件"
        return 1
    fi
    local target_path="$ARGS"
    if [ -e "$target_path" ]; then #检查路径是否已存在
        echo "路径 '$target_path' 已存在，无法重复创建"
        return 1
    fi
    echo "路径: $target_path"
    echo "请选择要创建的类型:"
    echo " 1) 目录 (directory)"
    echo " 2) 文件 (file)"
    echo -n "请输入选项 (1 或 2): "
    read -r user_choice
    case "$user_choice" in #根据用户选择执行相应操作
        1|directory|dir|d)
            echo "正在创建目录..."
            if mkdir -p "$target_path"; then
                echo "已创建目录: $target_path"
                
                # 显示目录权限信息
                local perm=$(stat -c "%a" "$target_path" 2>/dev/null || echo "未知")
                echo "权限: $perm"
            else
                echo "创建目录失败: $target_path，可能该目录已存在或您没有访问其上级目录的权限"
                return 1
            fi
            ;;
        2|file|f)
            echo "正在创建文件..."
            local parent_dir=$(dirname "$target_path") #确保父目录存在
            if [ ! -d "$parent_dir" ]; then
                echo "父目录不存在，自动创建: $parent_dir"
                mkdir -p "$parent_dir"
            fi
            if touch "$target_path"; then #创建空文件
                echo "✓ 已创建文件: $target_path"
                local perm=$(stat -c "%a" "$target_path" 2>/dev/null || echo "未知")
                local size=$(du -h "$target_path" | cut -f1)
                echo "权限: $perm"
                echo "大小: $size"
                echo ""
                echo -n "是否立即编辑文件内容？(y/N): "
                read -r edit_choice
                if [ "$edit_choice" = "y" ] || [ "$edit_choice" = "Y" ]; then
                    if command -v nano >/dev/null 2>&1; then
                        nano "$target_path"
                    elif command -v vim >/dev/null 2>&1; then
                        vim "$target_path"
                    elif command -v vi >/dev/null 2>&1; then
                        vi "$target_path"
                    else
                        echo "未找到可用的文本编辑器"
                    fi
                fi
            else
                echo "创建文件失败: $target_path，您可能没有访问其目录的权限"
                return 1
            fi
            ;;
        *)
            echo "无效的选择，操作已取消"
            return 1
            ;;
    esac
    
    return 0
}
command_mod() {
    if [ -z "$ARGS" ]; then
        echo "mod 命令用法:"
        echo "  mod <路径> - 修改文件或目录的属性"
        echo ""
        echo "可修改的属性:"
        echo "  - 文件权限 (chmod)"
        echo "  - 所有者和组 (chown)"
        echo "  - 时间戳 (touch)"
        echo "  - 重命名 (mv)"
        echo ""
        echo "示例:"
        echo "  mod file.txt"
        echo "  mod /path/to/directory"
        echo "  mod script.sh"
        return 1
    fi
    local target_path="$ARGS"
    if [ ! -e "$target_path" ]; then
        echo "错误: 路径 '$target_path' 不存在"
        return 1
    fi
    echo "=== 当前属性 ==="
    if [ -f "$target_path" ]; then
        echo "类型: 文件"
    elif [ -d "$target_path" ]; then
        echo "类型: 目录"
    elif [ -L "$target_path" ]; then
        echo "类型: 符号链接"
    else
        echo "类型: 特殊文件"
    fi
    echo "路径: $target_path"
    echo "权限: $(stat -c "%A (%a)" "$target_path" 2>/dev/null || echo "未知")"
    echo "所有者: $(stat -c "%U:%G" "$target_path" 2>/dev/null || echo "未知")"
    echo "大小: $(du -h "$target_path" | cut -f1)"
    echo "修改时间: $(stat -c "%y" "$target_path" 2>/dev/null || echo "未知")"
    echo "  1) 修改权限 (chmod)"
    echo "  2) 修改所有者和组 (chown)"
    echo "  3) 修改时间戳 (touch)"
    echo "  4) 重命名/移动 (mv)"
    echo "  5) 取消"
    echo ""
    echo -n "请选择操作 (1-5): "
    read -r user_choice
    case "$user_choice" in
        1)
            echo ""
            echo "当前权限: $(stat -c "%A (%a)" "$target_path")"
            echo ""
            echo "权限示例:"
            echo "  755 - 所有者:读/写/执行, 组:读/执行, 其他:读/执行"
            echo "  644 - 所有者:读/写, 组:读, 其他:读"
            echo "  777 - 所有用户:读/写/执行 (不推荐)"
            echo ""
            echo -n "请输入新的权限 (如 755): "
            read -r new_perms
            if [[ ! "$new_perms" =~ ^[0-7]{3,4}$ ]]; then
                echo "错误: 无效的权限格式 '$new_perms'"
                echo "权限必须是 3 或 4 位八进制数字 (如 755 或 0755)"
                return 1
            fi
            echo -n "确认将 '$target_path' 的权限改为 $new_perms? (y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if chmod "$new_perms" "$target_path"; then
                    echo "权限已修改: $(stat -c "%A (%a)" "$target_path")"
                else
                    echo "修改权限失败，可能需要 root 权限"
                    echo "尝试使用: sudo chmod $new_perms '$target_path'"
                fi
            else
                echo "操作已取消"
            fi
            ;;
        2)
            echo "当前所有者: $(stat -c "%U:%G" "$target_path")"
            echo -n "请输入新的所有者 (格式: 用户:组 或 用户): "
            read -r new_owner
            if [[ ! "$new_owner" =~ ^[a-zA-Z0-9_.-]+(:[a-zA-Z0-9_.-]+)?$ ]]; then
                echo "错误: 无效的所有者格式 '$new_owner'"
                echo "格式应为: 用户名 或 用户名:组名"
                return 1
            fi
            echo -n "确认将 '$target_path' 的所有者改为 $new_owner? (y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if chown "$new_owner" "$target_path"; then
                    echo "所有者已修改: $(stat -c "%U:%G" "$target_path")"
                else
                    echo "修改所有者失败，可能需要 root 权限"
                    echo "尝试使用: sudo chown $new_owner '$target_path'"
                fi
            else
                echo "操作已取消"
            fi
            ;;
        3)
            echo "当前修改时间: $(stat -c "%y" "$target_path")"
            echo "当前访问时间: $(stat -c "%x" "$target_path")"
            echo "时间戳选项:"
            echo "  1) 设置为当前时间"
            echo "  2) 设置为特定时间"
            echo "  3) 仅修改访问时间"
            echo "  4) 仅修改修改时间"
            echo -n "请选择时间戳操作 (1-4): "
            read -r time_choic
            case "$time_choice" in
                1)
                    if touch "$target_path"; then
                        echo "时间戳已更新为当前时间"
                        echo "新修改时间: $(stat -c "%y" "$target_path")"
                    else
                        echo "更新时间戳失败，请检查操作是否合法或您是否有修改权限"
                    fi
                    ;;
                2)
                    echo -n "请输入时间 (格式: YYYYMMDDhhmm.ss): "
                    read -r specific_time
                    if touch -t "$specific_time" "$target_path"; then
                        echo "时间戳已设置为: $specific_time"
                        echo "新修改时间: $(stat -c "%y" "$target_path")"
                    else
                        echo "设置时间戳失败，格式应为: YYYYMMDDhhmm.ss"
                    fi
                    ;;
                3)
                    if touch -a "$target_path"; then
                        echo "访问时间已更新为当前时间"
                        echo "新访问时间: $(stat -c "%x" "$target_path")"
                    else
                        echo "更新访问时间失败，请检查操作是否合法或您是否有修改权限"
                    fi
                    ;;
                4)
                    if touch -m "$target_path"; then
                        echo "修改时间已更新为当前时间"
                        echo "新修改时间: $(stat -c "%y" "$target_path")"
                    else
                        echo "更新修改时间失败，请检查操作是否合法或您是否有修改权限"
                    fi
                    ;;
                *)
                    echo "无效选择，操作已取消"
                    ;;
            esac
            ;;
        4)
            echo "当前路径: $target_path"
            echo -n "请输入新路径: "
            read -r new_path
            if [ -z "$new_path" ]; then
                echo "错误: 新路径不能为空"
                return 1
            fi
            if [ -e "$new_path" ]; then
                echo "警告: '$new_path' 已存在"
                echo -n "是否覆盖? (y/N): "
                read -r overwrite
                if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
                    echo "操作已取消"
                    return 0
                fi
            fi
            echo -n "确认将 '$target_path' 移动到 '$new_path'? (y/N): "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                if mv "$target_path" "$new_path"; then
                    echo "已移动/重命名: $new_path"
                    target_path="$new_path"
                else
                    echo "移动/重命名失败，请检查操作是否合法或您是否有修改权限"
                fi
            else
                echo "操作已取消"
            fi
            ;;
        5)
            echo "操作已取消"
            return 0
            ;;
        *)
            echo "无效选择，操作已取消"
            return 1
            ;;
    esac
    return 0
}
command_driver() {
    local need_root=false
    case "$ARGS" in
        "-i"*|"-d"*)
            need_root=true
            ;;
    esac
    if [ "$need_root" = true ] && [ "$(id -u)" -ne 0 ]; then
        echo "错误: 此操作需要 root 权限"
        echo "请使用: sudo driver $ARGS"
        return 1
    fi
    case "$ARGS" in
                "-r")
            echo "正在扫描所有驱动程序，请稍候..."
            if [ ! -d "/lib/modules/$(uname -r)" ]; then
                echo "警告: 未找到内核模块目录，可能在某些其他环境中（如容器）"
                echo "将显示可用信息..."
                echo ""
            fi
            local loaded_modules=()
            if command -v lsmod >/dev/null 2>&1; then
                loaded_modules=($(lsmod | awk 'NR>1 {print $1}'))
                echo "发现 ${#loaded_modules[@]} 个已加载的驱动程序"
                echo ""
            else
                echo "错误: lsmod 命令不可用"
                return 1
            fi
            printf "%-25s | %-20s | %-25s | %-15s\n" "驱动名称" "发行商" "加载时间" "状态"
            printf "%-25s-+-%-20s-+-%-25s-+-%-15s\n" "-------------------------" "--------------------" "-------------------------" "---------------"
            local count=0
            for module in "${loaded_modules[@]}"; do
                local module_info=$(modinfo "$module" 2>/dev/null)
                local vendor=$(echo "$module_info" | grep -i "vendor" | head -1 | cut -d: -f2- | sed 's/^ *//')
                local description=$(echo "$module_info" | grep -i "description" | head -1 | cut -d: -f2- | sed 's/^ *//')
                local license=$(echo "$module_info" | grep -i "license" | head -1 | cut -d: -f2- | sed 's/^ *//')
                if [ -z "$vendor" ]; then
                    if [ -n "$description" ]; then
                        vendor="$description"
                    elif [ -n "$license" ]; then
                        vendor="License: $license"
                    else
                        vendor="未知"
                    fi
                fi
                if [ ${#vendor} -gt 18 ]; then
                    vendor="${vendor:0:18}.."
                fi
                local load_time=""
                if [ -d "/sys/module/$module" ]; then
                    load_time=$(stat -c %y "/sys/module/$module" 2>/dev/null | cut -d. -f1)
                fi
                if [ -z "$load_time" ]; then
                    load_time="未知"
                fi
                local status="正常"
                if dmesg | grep -i "error.*$module" >/dev/null 2>&1; then
                    status="错误"
                elif dmesg | grep -i "warn.*$module" >/dev/null 2>&1; then
                    status="警告"
                fi
                printf "%-25s | %-20s | %-25s | %-15s\n" "$module" "$vendor" "$load_time" "$status"
                count=$((count + 1))
                if [ $count -eq 20 ]; then
                    echo ""
                    echo "已显示 20 个驱动程序，总共 ${#loaded_modules[@]} 个..."
                    echo -n "按 Enter 继续显示，或输入 'q' 退出: "
                    read -r user_input
                    if [ "$user_input" = "q" ] || [ "$user_input" = "Q" ]; then
                        echo "显示已终止"
                        break
                    fi
                    printf "%-25s | %-20s | %-25s | %-15s\n" "驱动名称" "发行商" "加载时间" "状态"
                    printf "%-25s-+-%-20s-+-%-25s-+-%-15s\n" "-------------------------" "--------------------" "-------------------------" "---------------"
                fi
            done
            echo "已加载驱动程序: ${#loaded_modules[@]} 个"
            local available_modules=()
            if command -v modprobe >/dev/null 2>&1 && [ -d "/lib/modules/$(uname -r)" ]; then
                available_modules=($(find /lib/modules/$(uname -r) -name "*.ko" -exec basename {} .ko \; 2>/dev/null))
                local loaded_count=${#loaded_modules[@]}
                local available_count=${#available_modules[@]}
                local not_loaded_count=$((available_count - loaded_count))
                echo "可用驱动程序: $available_count 个"
                echo "未成功加载驱动程序: $not_loaded_count 个"
                echo "若在WSL环境中，无法正常扫描驱动属正常现象"
                if [ $not_loaded_count -gt 0 ]; then
                    local displayed=0
                    for module in "${available_modules[@]}"; do
                        if [[ ! " ${loaded_modules[@]} " =~ " ${module} " ]]; then
                            printf "%s " "$module"
                            displayed=$((displayed + 1))
                            if [ $displayed -ge 10 ]; then
                                break
                            fi
                        fi
                    done
                    echo ""
                    echo "... 还有更多未加载驱动"
                fi
            fi
            echo ""
            echo "使用 'modinfo <驱动名称>' 查看详细驱动信息"
            ;;
        "-i")
            if command -v ubuntu-drivers >/dev/null 2>&1; then
                echo "正在检测可用驱动..."
                ubuntu-drivers devices
                echo ""
                echo "正在安装推荐的驱动..."
                sudo ubuntu-drivers autoinstall
                echo "驱动安装完成，建议重启系统"
            elif command -v apt >/dev/null 2>&1; then
                echo "使用 apt 安装通用驱动..."
                echo "正在更新软件包列表..."
                sudo apt update
                echo ""
                echo "安装硬件支持包..."
                sudo apt install -y linux-firmware firmware-linux-free firmware-linux-nonfree
                echo ""
                echo "安装常用驱动..."
                sudo apt install -y alsa-base pulseaudio
                echo "基础驱动安装完成"
            else
                echo "错误: 未找到可用的驱动管理工具"
                echo "请手动安装驱动或检查系统包管理器"
            fi
            ;;
        -i*)
            local driver_name="${ARGS#-i}"
            if [ -z "$driver_name" ]; then
                echo "错误: 未指定驱动名称"
                echo "用法: driver -i<驱动名称>"
                return 1
            fi
            if modinfo "$driver_name" >/dev/null 2>&1; then
                echo "驱动 $driver_name 已存在于系统中"
                echo "尝试加载驱动..."
                if sudo modprobe "$driver_name"; then
                    echo "驱动 $driver_name 加载成功"
                else
                    echo "驱动 $driver_name 加载失败"
                fi
                return 0
            fi
            if command -v apt >/dev/null 2>&1; then
                echo "正在搜索驱动包..."
                local pkg_name=""
                case "$driver_name" in
                    *nvidia*)
                        pkg_name="nvidia-driver-535"
                        ;;
                    *amd*|*radeon*)
                        pkg_name="xserver-xorg-video-radeon"
                        ;;
                    *intel*)
                        pkg_name="xserver-xorg-video-intel"
                        ;;
                    *broadcom*|*bcm*)
                        pkg_name="bcmwl-kernel-source"
                        ;;
                    *realtek*|*rtl*)
                        pkg_name="firmware-realtek"
                        ;;
                    *)
                        pkg_name="$driver_name"
                        ;;
                esac
                echo "尝试安装包: $pkg_name"
                if sudo apt install -y "$pkg_name"; then
                    echo "驱动安装完成"
                    echo "尝试加载驱动..."
                    if sudo modprobe "$driver_name" 2>/dev/null; then
                        echo "驱动 $driver_name 加载成功"
                    else
                        echo "驱动安装完成但加载失败，可能需要重启"
                    fi
                else
                    echo "驱动安装失败"
                    echo "请检查驱动名称或手动安装"
                fi
            else
                echo "错误: 不支持的包管理器"
                echo "请手动安装驱动: $driver_name"
            fi
            ;;
        -d*)
            local driver_name="${ARGS#-d}"
            if [ -z "$driver_name" ]; then
                echo "错误: 未指定驱动名称"
                echo "用法: driver -d<驱动名称>"
                return 1
            fi
            echo "删除驱动: $driver_name ==="
            if lsmod | grep -q "$driver_name"; then
                echo "正在卸载驱动模块..."
                if sudo modprobe -r "$driver_name"; then
                    echo "驱动模块已卸载"
                else
                    echo "驱动模块卸载失败，可能有其他模块共同使用"
                    echo "尝试强制卸载..."
                    if sudo rmmod "$driver_name"; then
                        echo "驱动模块已强制卸载"
                    else
                        echo "强制卸载失败，请手动卸载"
                    fi
                fi
            else
                echo "驱动 $driver_name 未加载"
            fi
            if command -v apt >/dev/null 2>&1; then
                echo "通过 apt 查找相关包..."
                local pkg_name=$(dpkg -l | grep -i "$driver_name" | awk '{print $2}' | head -1)
                
                if [ -n "$pkg_name" ]; then
                    echo "找到相关包: $pkg_name"
                    echo -n "确认删除此包? (y/N): "
                    read -r confirm
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        sudo apt remove -y "$pkg_name"
                        echo "包 $pkg_name 已删除"
                    else
                        echo "包删除已取消"
                    fi
                else
                    echo "未找到与 $driver_name 相关的安装包"
                fi
            else
                echo "注意: 仅卸载了驱动模块，未删除安装包"
            fi
            ;;
        "")
            echo "已加载的内核模块:"
            if command -v lsmod >/dev/null 2>&1; then
                lsmod | awk 'NR<=20 {printf "  %-30s %s\n", $1, $3}'
            else
                echo "  lsmod 命令不可用"
            fi
            echo "设备驱动信息:"
            if command -v lspci >/dev/null 2>&1; then
                local gpu_driver=$(lspci -k | grep -A 2 -i "VGA\|3D" | grep "Kernel driver" | cut -d: -f2 | sed 's/^ *//')
                if [ -n "$gpu_driver" ]; then
                    echo "  显卡驱动: $gpu_driver"
                else
                    echo "  显卡驱动: 未检测到"
                fi
            fi
            if [ -d "/proc/asound" ]; then
                local sound_driver=$(cat /proc/asound/version 2>/dev/null | head -1)
                if [ -n "$sound_driver" ]; then
                    echo "  声卡驱动: $sound_driver"
                else
                    echo "  声卡驱动: **^#%"
                fi
            fi
            if command -v ethtool >/dev/null 2>&1; then
                local net_interfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v lo | awk -F: '{print $2}' | sed 's/^ *//')
                for iface in $net_interfaces; do
                    local driver=$(ethtool -i "$iface" 2>/dev/null | grep driver | cut -d: -f2 | sed 's/^ *//')
                    if [ -n "$driver" ]; then
                        echo "  网络接口 $iface: $driver"
                    fi
                done
            fi
            echo "使用 'driver -r' 扫描所有硬件驱动"
            echo "使用 'driver -i' 自动安装缺失的驱动"
            ;;
        *)
            echo "driver 命令用法:"
            echo "  driver         - 列出当前已安装的驱动程序"
            echo "  driver -r      - 扫描所有硬件驱动（已安装和缺失的）"
            echo "  driver -i      - 自动安装缺失的驱动"
            echo "  driver -i<名称> - 安装指定的驱动"
            echo "  driver -d<名称> - 删除指定的驱动"
            echo ""
            echo "示例:"
            echo "  driver"
            echo "  driver -r"
            echo "  driver -i"
            echo "  driver -invidia"
            echo "  driver -dbcmwl"
            ;;
    esac
    
    return 0
}
command_backup() {
    local backup_config="$HOME/.mycommands/backup_config"
    local backup_log="$HOME/.mycommands/backup.log"
    mkdir -p "$(dirname "$backup_config")"
    echo "请选择备份类型:"
    echo "  1) 完全备份 - 备份所有文件"
    echo "  2) 增量备份 - 只备份上次备份后修改的文件"
    echo "  3) 差异备份 - 备份上次完全备份后修改的文件"
    echo "  4) 查看备份历史"
    echo "  5) 恢复备份"
    echo -n "请选择 (1-5): "
    read -r backup_choice
    case "$backup_choice" in
        1|2|3)
            echo ""
            echo -n "请输入要备份的源目录路径: "
            read -r source_dir
            if [ ! -d "$source_dir" ]; then
                echo "错误: 源目录 '$source_dir' 不存在"
                return 1
            fi
            echo -n "请输入备份存储目录路径: "
            read -r backup_dir
            if [ ! -d "$backup_dir" ]; then
                echo -n "备份目录不存在，是否创建? (y/N): "
                read -r create_dir
                if [ "$create_dir" = "y" ] || [ "$create_dir" = "Y" ]; then
                    mkdir -p "$backup_dir" || {
                        echo "错误: 无法创建备份目录"
                        return 1
                    }
                else
                    echo "操作已取消"
                    return 1
                fi
            fi
            local backup_type=""
            case "$backup_choice" in
                1) backup_type="full" ;;
                2) backup_type="incremental" ;;
                3) backup_type="differential" ;;
            esac
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local backup_name="backup_${backup_type}_${timestamp}"
            local backup_path="$backup_dir/$backup_name"
            mkdir -p "$backup_path" || {
                echo "错误: 无法创建备份目录 '$backup_path'，请注意权限"
                return 1
            }
            echo "开始备份..."
            echo "源目录: $source_dir"
            echo "备份到: $backup_path"
            echo "备份类型: $backup_type"
            local backup_count=0
            local total_size=0
            case "$backup_type" in
                "full")   
                    echo "执行完全备份..."
                    while IFS= read -r -d '' file; do
                        if [ -f "$file" ]; then
                            local rel_path="${file#$source_dir/}"
                            local target_dir="$backup_path/$(dirname "$rel_path")"
                            mkdir -p "$target_dir"
                            if cp -p "$file" "$backup_path/$rel_path" 2>/dev/null; then
                                backup_count=$((backup_count + 1))
                                local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                                total_size=$((total_size + file_size))
                                printf "\r已备份: %d 个文件, 总大小: %.2f MB" "$backup_count" "$(echo "scale=2; $total_size/1024/1024" | bc -q 2>/dev/null || echo "0")"
                            fi
                        fi
                    done < <(find "$source_dir" -type f -print0 2>/dev/null)
                    ;;
                "incremental")
                    echo "执行增量备份..."
                    local last_backup_time=""
                    if [ -f "$backup_log" ]; then
                        last_backup_time=$(grep "BACKUP_COMPLETED" "$backup_log" | tail -1 | cut -d'|' -f3)
                    fi
                    if [ -z "$last_backup_time" ]; then
                        echo "警告: 未找到上次备份记录，已自动执行执行完全备份"
                        backup_type="full"
                        command_backup
                        return 0
                    fi
                    while IFS= read -r -d '' file; do
                        if [ -f "$file" ]; then
                            local file_mtime=$(stat -c%Y "$file" 2>/dev/null)
                            if [ "$file_mtime" -gt "$last_backup_time" ]; then
                                local rel_path="${file#$source_dir/}"
                                local target_dir="$backup_path/$(dirname "$rel_path")"
                                mkdir -p "$target_dir"
                                if cp -p "$file" "$backup_path/$rel_path" 2>/dev/null; then
                                    backup_count=$((backup_count + 1))
                                    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                                    total_size=$((total_size + file_size))
                                    printf "\r已备份: %d 个文件, 总大小: %.2f MB" "$backup_count" "$(echo "scale=2; $total_size/1024/1024" | bc -q 2>/dev/null || echo "0")"
                                fi
                            fi
                        fi
                    done < <(find "$source_dir" -type f -print0 2>/dev/null)
                    ;;
                "differential")
                    echo "执行差异备份..."
                    local last_full_backup_time=""
                    if [ -f "$backup_log" ]; then
                        last_full_backup_time=$(grep "full.*BACKUP_COMPLETED" "$backup_log" | tail -1 | cut -d'|' -f3)
                    fi
                    
                    if [ -z "$last_full_backup_time" ]; then
                        echo "警告: 未找到完全备份记录，执行完全备份"
                        backup_type="full"
                        command_backup
                        return 0
                    fi
                    while IFS= read -r -d '' file; do
                        if [ -f "$file" ]; then
                            local file_mtime=$(stat -c%Y "$file" 2>/dev/null)
                            if [ "$file_mtime" -gt "$last_full_backup_time" ]; then
                                local rel_path="${file#$source_dir/}"
                                local target_dir="$backup_path/$(dirname "$rel_path")"
                                mkdir -p "$target_dir"
                                if cp -p "$file" "$backup_path/$rel_path" 2>/dev/null; then
                                    backup_count=$((backup_count + 1))
                                    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                                    total_size=$((total_size + file_size))
                                    printf "\r已备份: %d 个文件, 总大小: %.2f MB" "$backup_count" "$(echo "scale=2; $total_size/1024/1024" | bc -q 2>/dev/null || echo "0")"
                                fi
                            fi
                        fi
                    done < <(find "$source_dir" -type f -print0 2>/dev/null)
                    ;;
            esac
            echo "备份完成!"
            echo "备份位置: $backup_path"
            echo "备份文件数: $backup_count"
            echo "总大小: $(echo "scale=2; $total_size/1024/1024" | bc -q 2>/dev/null || echo "0") MB"
            local log_time=$(date +%s)
            echo "$(date '+%Y-%m-%d %H:%M:%S')|$backup_type|$log_time|$source_dir|$backup_path|$backup_count|$total_size|BACKUP_COMPLETED" >> "$backup_log"
            ;;
        4)
            if [ -f "$backup_log" ]; then
                printf "%-19s | %-12s | %-30s | %-8s | %s\n" "时间" "类型" "源目录" "文件数" "备份位置"
                printf "%-19s-+-%-12s-+-%-30s-+-%-8s-+-%s\n" "-------------------" "------------" "------------------------------" "--------" "------------------------------"
                while IFS='|' read -r date type time source target count size status; do
                    if [ "$status" = "BACKUP_COMPLETED" ]; then
                        local short_source=$(echo "$source" | cut -c1-30)
                        local short_target=$(basename "$target")
                        printf "%-19s | %-12s | %-30s | %-8s | %s\n" "$date" "$type" "$short_source" "$count" "$short_target"
                    fi
                done < "$backup_log"
            else
                echo "暂无备份记录"
            fi
            ;;
        5)
            if [ ! -f "$backup_log" ]; then
                echo "错误: 未找到备份记录"
                return 1
            fi
            echo "可恢复的备份:"
            local i=1
            local restore_options=()
            while IFS='|' read -r date type time source target count size status; do
                if [ "$status" = "BACKUP_COMPLETED" ]; then
                    echo "  $i) $date - $type - $source -> $(basename "$target")"
                    restore_options[$i]="$target|$source"
                    i=$((i + 1))
                fi
            done < "$backup_log"
            
            if [ $i -eq 1 ]; then
                echo "没有可恢复的备份"
                return 1
            fi
            echo -n "请选择要恢复的备份 (1-$((i-1))): "
            read -r restore_choice
            
            if [ "$restore_choice" -lt 1 ] || [ "$restore_choice" -ge $i ]; then
                echo "错误: 无效的选择"
                return 1
            fi
            local restore_info="${restore_options[$restore_choice]}"
            local restore_target=$(echo "$restore_info" | cut -d'|' -f1)
            local restore_source=$(echo "$restore_info" | cut -d'|' -f2)
            echo "恢复信息:"
            echo "  备份位置: $restore_target"
            echo "  恢复到: $restore_source"
            echo -n "确认恢复? 此操作将覆盖现有文件! (y/N): "
            read -r confirm_restore
            if [ "$confirm_restore" != "y" ] && [ "$confirm_restore" != "Y" ]; then
                echo "恢复已取消"
                return 0
            fi
            echo "开始恢复..."
            local restore_count=0
            if [ -d "$restore_target" ]; then
                while IFS= read -r -d '' file; do
                    if [ -f "$file" ]; then
                        local rel_path="${file#$restore_target/}"
                        local target_path="$restore_source/$rel_path"
                        local target_dir="$(dirname "$target_path")"
                        
                        mkdir -p "$target_dir"
                        if cp -p "$file" "$target_path" 2>/dev/null; then
                            restore_count=$((restore_count + 1))
                            printf "\r已恢复: %d 个文件" "$restore_count"
                        fi
                    fi
                done < <(find "$restore_target" -type f -print0 2>/dev/null)
                echo ""
                echo "恢复完成! 共恢复 $restore_count 个文件"
            else
                echo "错误: 备份目录不存在"
            fi
            ;;
        *)
            echo "无效选择"
            return 1
            ;;
    esac
    return 0
}
command_check() {
    case "$ARGS" in
        "-f")
            echo -n "请输入代码文件路径: "
            read -r code_file
            if [ -z "$code_file" ]; then
                echo "错误: 未指定文件路径"
                return 1
            fi
            if [ ! -f "$code_file" ]; then
                echo "错误: 文件 '$code_file' 不存在"
                return 1
            fi
            if [ ! -r "$code_file" ]; then
                echo "错误: 没有读取 '$code_file' 的权限"
                return 1
            fi
            echo "正在检查: $code_file"
            local extension="${code_file##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
            case "$extension" in
                "sh"|"bash")
                    echo "检查 Shell 脚本格式..."
                    if command -v shellcheck >/dev/null 2>&1; then
                        shellcheck "$code_file"
                        local shellcheck_result=$?
                        if [ $shellcheck_result -eq 0 ]; then
                            echo "Shell 脚本格式正确"
                        else
                            echo "Shell 脚本存在格式问题"
                        fi
                    else
                        echo "提示: 安装 shellcheck 可以获得更详细的检查"
                        echo "sudo apt install shellcheck"
                        echo "基础语法检查:"
                        if bash -n "$code_file" 2>/dev/null; then
                            echo "基础语法正确"
                        else
                            echo "基础语法错误"
                            bash -n "$code_file"
                        fi
                    fi
                    ;;
                "py")
                    echo "检查 Python 代码格式..."
                    if command -v python3 >/dev/null 2>&1; then
                        if python3 -m py_compile "$code_file" 2>/dev/null; then
                            echo "Python 语法正确"
                            local pyc_file="${code_file}c"
                            [ -f "$pyc_file" ] && rm -f "$pyc_file"
                        else
                            echo "Python 语法错误"
                            python3 -m py_compile "$code_file"
                        fi
                    else
                        echo "错误: 未找到 python3"
                    fi
                    if command -v flake8 >/dev/null 2>&1; then
                        echo ""
                        echo "PEP8 格式检查:"
                        flake8 "$code_file" --max-line-length=120
                    fi
                    ;;
                "js")
                    echo "检查 JavaScript 代码格式..."
                    if command -v node >/dev/null 2>&1; then
                        if node -c "$code_file" 2>/dev/null; then
                            echo "JavaScript 语法正确"
                        else
                            echo "JavaScript 语法错误"
                            node -c "$code_file"
                        fi
                    else
                        echo "错误: 未找到 Node.js"
                    fi
                    ;;
                "json")
                    echo "检查 JSON 格式..."
                    if command -v python3 >/dev/null 2>&1; then
                        if python3 -m json.tool "$code_file" >/dev/null 2>&1; then
                            echo "JSON 格式正确"
                        else
                            echo "JSON 格式错误"
                            python3 -m json.tool "$code_file"
                        fi
                    elif command -v jq >/dev/null 2>&1; then
                        if jq . "$code_file" >/dev/null 2>&1; then
                            echo "JSON 格式正确"
                        else
                            echo "JSON 格式错误"
                            jq . "$code_file"
                        fi
                    else
                        echo "提示: 安装 jq 或 python3 可以获得 JSON 格式检查"
                    fi
                    ;;
                "xml")
                    echo "检查 XML 格式..."
                    if command -v xmllint >/dev/null 2>&1; then
                        if xmllint --noout "$code_file" 2>/dev/null; then
                            echo "XML 格式正确"
                        else
                            echo "XML 格式错误"
                            xmllint --noout "$code_file"
                        fi
                    else
                        echo "提示: 安装 xmllint 可以获得 XML 格式检查"
                        echo "      sudo apt install libxml2-utils"
                    fi
                    ;;
                "html"|"htm")
                    echo "检查 HTML 格式..."
                    if command -v tidy >/dev/null 2>&1; then
                        echo "HTML 检查结果:"
                        tidy -q -errors "$code_file" 2>/dev/null
                        local tidy_result=$?
                        if [ $tidy_result -eq 0 ]; then
                            echo "HTML 格式基本正确"
                        elif [ $tidy_result -eq 1 ]; then
                            echo "HTML 存在警告"
                        else
                            echo "HTML 存在错误"
                        fi
                    else
                        echo "提示: 安装 tidy 可以获得 HTML 格式检查"
                        echo "      sudo apt install tidy"
                    fi
                    ;;
                "css")
                    echo "检查 CSS 格式..."
                    if command -v csslint >/dev/null 2>&1; then
                        csslint "$code_file" --quiet 2>/dev/null
                        local csslint_result=$?
                        if [ $csslint_result -eq 0 ]; then
                            echo "CSS 格式正确"
                        else
                            echo "CSS 存在格式问题"
                        fi
                    else
                        echo "提示: 安装 csslint 可以获得 CSS 格式检查"
                        echo "sudo npm install -g csslint"
                    fi
                    ;;
                *)
                    echo "不支持检查 '$extension' 格式的文件"
                    echo "支持的文件类型: sh, py, js, json, xml, html, css"
                    ;;
            esac
            ;;
        "")
            echo -n "请输入文件路径: "
            read -r file_path
            if [ -z "$file_path" ]; then
                echo "错误: 未指定文件路径"
                return 1
            fi
            if [ ! -f "$file_path" ]; then
                echo "错误: 文件 '$file_path' 不存在"
                return 1
            fi
            if [ ! -r "$file_path" ]; then
                echo "错误: 没有读取 '$file_path' 的权限"
                return 1
            fi
            echo "正在检查: $file_path"
            local file_info=$(file -b "$file_path" 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "文件类型: $file_info"
            else
                echo "文件类型: 未知"
            fi
            local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "未知")
            echo "文件大小: $file_size 字节"
            echo ""
            echo "编码分析:"
            local first_bytes=$(head -c 3 "$file_path" | od -An -tx1 | tr -d ' \n')
            if [ "$first_bytes" = "efbbbf" ]; then
                echo "UTF-8 with BOM"
            else
                echo "无BOM头"
            fi
            if grep -q -P "[^\x00-\x7F]" "$file_path" 2>/dev/null; then
                echo "包含非法ASCII字符"
                if command -v uchardet >/dev/null 2>&1; then
                    local detected_encoding=$(uchardet "$file_path" 2>/dev/null)
                    echo "检测编码: $detected_encoding"
                elif command -v enca >/dev/null 2>&1; then
                    local detected_encoding=$(enca -L none "$file_path" 2>/dev/null | head -1)
                    echo "检测编码: $detected_encoding"
                else
                    echo "提示: 安装 uchardet 或 enca 可以获得更准确的编码检测"
                fi
            else
                echo "纯ASCII文本"
            fi
            echo "行尾符检查:"
            local crlf_count=$(grep -c -U $'\x0D' "$file_path" 2>/dev/null || echo "0")
            local lf_count=$(grep -c -U $'\x0A' "$file_path" 2>/dev/null || echo "0")
            
            if [ "$crlf_count" -gt 0 ] && [ "$lf_count" -gt 0 ]; then
                echo "混合行尾符 (CRLF+LF)"
            elif [ "$crlf_count" -gt 0 ]; then
                echo "Windows 行尾符 (CRLF)"
            elif [ "$lf_count" -gt 0 ]; then
                echo "Unix 行尾符 (LF)"
            else
                echo "无行尾符或空文件"
            fi
            local blank_lines=$(grep -c '^$' "$file_path" 2>/dev/null || echo "0")
            echo "空行数量: $blank_lines"
            local last_char=$(tail -c 1 "$file_path" | od -An -tx1 | tr -d ' \n')
            if [ "$last_char" = "0a" ]; then
                echo "以换行符结束"
            else
                echo "未以换行符结束"
            fi
            echo ""
            echo "文件预览 (前10行):"
            echo "----------------------------------------"
            head -10 "$file_path" 2>/dev/null | cat -A
            echo "----------------------------------------"
            ;;
        *)
            echo "check 命令用法:"
            echo "  check         - 检查文件编码格式"
            echo "  check -f      - 检查代码文件格式"
            echo ""
            echo "示例:"
            echo "  check         # 检查文件编码"
            echo "  check -f      # 检查代码格式"
            ;;
    esac
    return 0
}
command_download() {
    if [ -z "$ARGS" ]; then
        echo "download 命令用法:"
        echo "download+URL-网络资源下载"
        echo "支持的协议: http, https, ftp"
        echo "工具程序会自动择取下载效率最高的下载方式"
        echo "所有依赖工具已由全局系统自动安装"
        echo "示例:"
        echo "download https://example.com/file.zip"
        echo "download ftp://ftp.example.com/file.tar.gz"
        return 1
    fi
    local URL="$ARGS"
    local filename=$(basename "$URL" | sed 's/?.*//')
    if [ -z "$filename" ] || [ "$filename" = "/" ]; then
        filename="downloaded_file_$(date +%Y%m%d_%H%M%S)"
    fi
    echo "目标文件名: $filename"
    if [ -f "$filename" ]; then
        echo "警告: 文件 '$filename' 已存在"
        echo -n "您希望覆盖现有的文件吗? [y/N]: "
        read -r overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            local counter=1
            while [ -f "${filename}.${counter}" ]; do
                counter=$((counter + 1))
            done
            filename="${filename}.${counter}"
        fi
    fi
    local selected_tool="" #WGET/CURL/FRP
    local tool_args=""
    if [[ "$URL" =~ ^ftp:// ]]; then
        if command -v curl >/dev/null 2>&1; then
            selected_tool="curl"
            tool_args="-u anonymous:anonymous -o"
        elif command -v ftp >/dev/null 2>&1; then
            selected_tool="ftp"
        else
            echo "错误: 没有可用的FTP客户端，下载已终止"
            return 1
        fi
    else
        if command -v aria2c >/dev/null 2>&1; then #HTTP/HTTPS
            selected_tool="aria2c"
            tool_args="-x 4 -s 4 -k 1M --summary-interval=0 -o"
        elif command -v axel >/dev/null 2>&1; then
            selected_tool="axel"
            tool_args="-n 4 -a -o"
        elif command -v wget >/dev/null 2>&1; then
            selected_tool="wget"
            tool_args="-c --progress=bar:force -O"
        elif command -v curl >/dev/null 2>&1; then
            selected_tool="curl"
            tool_args="-L -C - -o"
        else
            echo "错误: 未找到任何下载工具"
            echo "提示: 全局依赖系统正在安装，请稍后重试"
            return 1
        fi
    fi
    echo "将使用的下载工具: $selected_tool"
    echo "开始下载..."
    local start_time=$(date +%s)
    local download_result=0 #开始下载
    case "$selected_tool" in
        "aria2c")
            aria2c $tool_args "$filename" "$URL"
            download_result=$?
            ;;
        "axel")
            axel $tool_args "$filename" "$URL"
            download_result=$?
            ;;
        "wget")
            wget $tool_args "$filename" "$URL"
            download_result=$?
            ;;
        "curl")
            if [[ "$URL" =~ ^ftp:// ]]; then
                curl -u anonymous:anonymous -o "$filename" "$URL"
            else
                curl -L -C - -o "$filename" "$URL"
            fi
            download_result=$?
            ;;
        "ftp")
            local ftp_host=$(echo "$URL" | sed 's|ftp://||' | cut -d/ -f1)
            local ftp_path="/$(echo "$URL" | sed 's|ftp://[^/]*/||')"
            echo "正在连接FTP服务器: $ftp_host"
            echo "下载文件: $ftp_path"
            curl -u anonymous:anonymous -o "$filename" "$URL"
            download_result=$?
            ;;
        *)
            echo "错误: 未知下载工具/无法处理的URL"
            return 1
            ;;
    esac
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    if [ $download_result -eq 0 ]; then
        echo "下载成功!您可以通过"open"命令直接打开"
        if [ -f "$filename" ]; then
            local file_size=$(stat -c%s "$filename" 2>/dev/null || echo "0")
            local size_display=""
            
            if [ "$file_size" -ge 1073741824 ]; then
                size_display=$(echo "scale=2; $file_size/1073741824" | bc)" GB"
            elif [ "$file_size" -ge 1048576 ]; then
                size_display=$(echo "scale=2; $file_size/1048576" | bc)" MB"
            elif [ "$file_size" -ge 1024 ]; then
                size_display=$(echo "scale=2; $file_size/1024" | bc)" KB"
            else
                size_display="$file_size 字节"
            fi
            local speed=""
            if [ $duration -gt 0 ]; then
                local speed_bps=$((file_size / duration))
                if [ $speed_bps -ge 1048576 ]; then
                    speed=$(echo "scale=2; $speed_bps/1048576" | bc)" MB/s"
                elif [ $speed_bps -ge 1024 ]; then
                    speed=$(echo "scale=2; $speed_bps/1024" | bc)" KB/s"
                else
                    speed="$speed_bps B/s"
                fi
            fi
            echo "文件信息:"
            echo "  大小: $size_display"
            echo "  位置: $(pwd)/$filename"
            echo "  耗时: ${duration}秒"
            [ -n "$speed" ] && echo "  平均速度: $speed"
            if command -v file >/dev/null 2>&1; then
                local file_type=$(file -b "$filename" 2>/dev/null | head -c 60)
                echo "  类型: $file_type"
            fi
        fi
    else
        echo "下载失败-错误码: $download_result)"
        if [ $download_result -eq 4 ]; then #有可能是这些错误？？？
            echo "网络错误: 无法连接服务器"
        elif [ $download_result -eq 6 ]; then
            echo "URL错误: 无法解析主机名"
        elif [ $download_result -eq 22 ]; then
            echo "HTTP错误: 404 - 文件不存在"
        fi
        if [ -f "$filename" ] && [ $(stat -c%s "$filename" 2>/dev/null || echo 0) -lt 1024 ]; then
            rm -f "$filename"
            echo "已删除损坏的文件片段"
        fi
    fi
    return $download_result
}
command_search() {
    if [ -z "$ARGS" ]; then
        echo "search 命令用法:"
        echo "search <文件名>              -在整个系统中搜索文件"
        echo "search <路径> <文件名>        -在指定路径中搜索文件"
        echo ""
        echo "搜索选项:"
        echo "-t <类型>     文件类型: f(文件), d(目录), l(链接)"
        echo "-u <用户>     按所有者搜索"
        echo "-g <组>       按所属组搜索"
        echo "-s <大小>     按大小搜索 (+大于, -小于, 单位: k,M,G)"
        echo "-m <天数>     按修改时间搜索 (+超过, -以内)"
        echo ""
        echo "示例:"
        echo "search myfile.txt                   #全局搜索文件"
        echo "search /home/user myfile.txt        #在指定目录搜索"
        echo "search -t f myfile.txt              #只搜索普通文件"
        echo "search -u root myfile.txt           #搜索root用户的文件"
        echo "search -s +10M largefile            #搜索大于10MB的文件（文件大小可修改）"
        echo "search -m -7 recent_file            #搜索7天内修改的文件"
        return 1
    fi
    local search_path=""
    local search_name=""
    local find_options=""
    local use_locate=false
    local args_array=($ARGS)
    local i=0
    local arg_count=${#args_array[@]}
    while [ $i -lt $arg_count ]; do
        case "${args_array[i]}" in
            -t|--type)
                if [ $((i+1)) -lt $arg_count ]; then
                    local type_char="${args_array[i+1]}"
                    case "$type_char" in
                        f) find_options="$find_options -type f" ;;
                        d) find_options="$find_options -type d" ;;
                        l) find_options="$find_options -type l" ;;
                        *) echo "错误: 无效的文件类型 '$type_char'，请使用 f, d 或 l" && return 1 ;;
                    esac
                    i=$((i+2))
                else
                    echo "错误: -t 选项需要参数"
                    return 1
                fi
                ;;
            -u|--user)
                if [ $((i+1)) -lt $arg_count ]; then
                    find_options="$find_options -user ${args_array[i+1]}"
                    i=$((i+2))
                else
                    echo "错误: -u 选项需要参数"
                    return 1
                fi
                ;;
            -g|--group)
                if [ $((i+1)) -lt $arg_count ]; then
                    find_options="$find_options -group ${args_array[i+1]}"
                    i=$((i+2))
                else
                    echo "错误: -g 选项需要参数"
                    return 1
                fi
                ;;
            -s|--size)
                if [ $((i+1)) -lt $arg_count ]; then
                    find_options="$find_options -size ${args_array[i+1]}"
                    i=$((i+2))
                else
                    echo "错误: -s 选项需要参数"
                    return 1
                fi
                ;;
            -m|--mtime)
                if [ $((i+1)) -lt $arg_count ]; then
                    find_options="$find_options -mtime ${args_array[i+1]}"
                    i=$((i+2))
                else
                    echo "错误: -m 选项需要参数"
                    return 1
                fi
                ;;
            -l|--locate)
                use_locate=true
                i=$((i+1))
                ;;
            *)
                if [ -z "$search_path" ] && [ -d "${args_array[i]}" ]; then #这是啥？
                    search_path="${args_array[i]}"
                    i=$((i+1))
                else
                    search_name="${args_array[i]}"
                    for ((j=i+1; j<arg_count; j++)); do
                        if [[ "${args_array[j]}" != -* ]]; then
                            search_name="$search_name ${args_array[j]}"
                        else
                            break
                        fi
                    done
                    i=$arg_count
                fi
                ;;
        esac
    done
    if [ -z "$search_name" ]; then
        echo "错误: 请指定要搜索的文件名"
        return 1
    fi
    if [ -z "$search_path" ]; then
        if [ "$use_locate" = true ] && command -v locate >/dev/null 2>&1; then
            echo "使用 locate 进行全局搜索 (更快但需要更新数据库)..."
            if locate -b "$search_name" 2>/dev/null | head -100; then
                echo ""
                echo "提示: 使用 'sudo updatedb' 更新locate数据库以获得最新结果"
            else
                echo "未找到文件或locate数据库需要更新"
            fi
        else
            echo "使用 find 进行全局搜索 (可能需要较长时间)..."
            echo "正在搜索: $search_name"
            echo "========================================"
            sudo find / \
                -path /proc -prune -o \
                -path /sys -prune -o \
                -path /dev -prune -o \
                -path /run -prune -o \
                -path /tmp -prune -o \
                -name "*$search_name*" \
                $find_options \
                -print 2>/dev/null | head -200
            
            echo "========================================"
            echo "提示: 全局搜索可能需要较长时间，可以指定路径缩小搜索范围"
        fi
    else
        if [ ! -d "$search_path" ]; then
            echo "错误: 路径 '$search_path' 不存在或不是目录"
            return 1
        fi
        echo "在目录 '$search_path' 中搜索: $search_name"
        echo "========================================"
        find "$search_path" \
            -name "*$search_name*" \
            $find_options \
            -print 2>/dev/null
        
        echo "========================================"
        local result_count=$(find "$search_path" \
            -name "*$search_name*" \
            $find_options \
            -print 2>/dev/null | wc -l)
        
        echo "找到 $result_count 个匹配项"
    fi
    return 0
}
command_amend() {
    local file_path="$ARGS"
    if [ -z "$file_path" ]; then
        echo "amend命令用法: amend+文件路径"
        echo "示例: amend none.txt"
        echo "说明: 以可编辑文本形式打开任何类型的可访问文件"
        return 1
    fi
    if [ ! -e "$file_path" ]; then
        echo "文件'$file_path'不存在"
        return 1
    fi
    if [ ! -f "$file_path" ]; then
        echo "'$file_path'不是普通文件"
        return 1
    fi
    if [ ! -r "$file_path" ]; then
        echo "没有读取'$file_path'的权限"
        return 1
    fi
    # 选择编辑器（优先 nano，其次 vim，最后 vi）
    local editor=""
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        echo "未找到可用的文本编辑器 (nano/vim/vi)"
        return 1
    fi
    echo "使用编辑器: $editor 打开文件: $file_path"
    # 直接以文本方式打开，不检查文件类型
    $editor "$file_path"
    return 0
}
command_language() {
    local action="$1"
    local lang_code="$2"
    case "$action" in
        "")
            # 显示本机默认语言和支持的语言
            echo "=== 本机语言信息 ==="
            echo "当前默认语言: $LANG"
            echo "当前语言环境: $(locale | head -1)"
            echo ""
            echo "=== 已安装的支持语言 ==="
            if command -v locale >/dev/null 2>&1; then
                locale -a | grep -v "^C$" | grep -v "^POSIX$" | sort | uniq
            else
                echo "locale 命令不可用，请安装 locales 包"
                return 1
            fi
            echo ""
            echo "提示: 使用'language -a'查看可添加的语言"
            echo "使用'language -c <语言代号>'修改系统语言"
            ;;
        "-a")
            # 显示可添加的语言并提供下载
            echo "=== 可添加的语言包 ==="
            local supported_file="/usr/share/i18n/SUPPORTED"
            if [ -f "$supported_file" ]; then
                echo "以下语言包可供安装 (仅显示前20个):"
                head -20 "$supported_file" | awk -F'.' '{print $1}' | sort -u
                echo "... 共 $(wc -l < "$supported_file" | tr -d ' ') 个语言"
            else
                echo "未找到语言支持文件，尝试从软件源获取列表"
                if command -v apt >/dev/null 2>&1; then
                    apt-cache search language-pack- | head -20 | awk '{print $1}' | sed 's/language-pack-//'
                else
                    echo "无法获取可用语言列表"
                fi
            fi
            echo -n "请输入要下载的语言代号 (例如 zh_CN, en_US) 或按回车跳过: "
            read -r target_lang
            if [ -n "$target_lang" ]; then
                echo "正在后台下载语言包: $target_lang"
                # 调用 download 命令下载语言包 (后台运行)
                local pkg_name="language-pack-${target_lang%_*}"
                if command -v download >/dev/null 2>&1; then
                    download "http://archive.ubuntu.com/ubuntu/pool/main/l/language-pack-$pkg_name/$(apt-cache show $pkg_name 2>/dev/null | grep -m1 Filename | cut -d' ' -f2)" &
                else
                    echo "download 命令不可用，使用 apt 安装"
                    _silent_install "$pkg_name" &
                fi
                echo "下载任务已在后台启动，请稍后检查安装状态"
            fi
            ;;
        "-c")
            if [ -z "$lang_code" ]; then
                echo "用法:language -c <语言代号>"
                echo "示例:language -c zh_CN.UTF-8"
                return 1
            fi
            # 修改系统语言
            if [ "$(id -u)" -ne 0 ]; then
                echo "修改系统语言需要 root 权限"
                echo "请使用:sudo language -c $lang_code"
                return 1
            fi
            echo "正在修改系统语言为:$lang_code"
            # 生成对应的locale
            if command -v locale-gen >/dev/null 2>&1; then
                echo "$lang_code UTF-8" >> /etc/locale.gen
                locale-gen
            else
                echo "locale-gen 命令不可用，尝试安装 locales"
                _silent_install "locales"
                locale-gen "$lang_code"
            fi
            # 设置默认语言
            if command -v update-locale >/dev/null 2>&1; then
                update-locale LANG="$lang_code"
            else
                echo "LANG=$lang_code" > /etc/default/locale
            fi
            # 使更改生效（当前会话需重新登录）
            export LANG="$lang_code"
            echo "语言已修改为 $lang_code，可能需要注销重新登录才能完全生效"
            ;;
        *)
            echo "language 命令用法:"
            echo "language                 -显示当前语言和支持的语言"
            echo "language -a              -显示可添加的语言并下载语言包"
            echo "language -c <语言代号>    -修改系统语言为目标语言"
            echo "示例:"
            echo "language"
            echo "language -a"
            echo "language -c zh_CN.UTF-8"
            return 1
            ;;
    esac
    return 0
}
command_restart() {
    echo "正在重载命令工具链接符号..."
    local last_check_file="/tmp/.command_links_last_check"
    if [ -f "$last_check_file" ]; then
        rm -f "$last_check_file"
    fi
    silent_link_verify
    if [ $? -eq 0 ]; then
        echo "UCST命令工具链接符号已重载"
    else
        echo "链接符号重载失败，请检查权限或重启计算机"
        return 1
    fi
    return 0
}
#sai与account的预先基础设置
export LC_ALL=C.UTF-8 2>/dev/null
export LANG=C.UTF-8 2>/dev/null
_cmd_exists() { #何意味
    command -v "$1" >/dev/null 2>&1
}
command_account() {
    local config_file="$HOME/.ucst_sai_config"
    local action="$1"
    local LOGIN_URL="https://email.coludai.cn"
    local API_URL="https://ai.coludai.cn"
    case "$action" in
        "-s"|"--set")
            echo "===coludai账户登录与CA设置==="
            #获取账号信息
            local username=""
            local password=""
            echo "请输入您的coludai账户信息"
            echo -n "用户名: "
            read -r username
            echo -n "密码: "
            read -s -r password
            if [ -z "$username" ] || [ -z "$password" ]; then
                echo "账号或密码不能为空"
                return 1
            fi
            #获取CA令牌
            echo "请从coludai账户页面获取CA令牌"
            echo "CA是使用AI功能的必需凭证"
            echo -n "请输入CA: "
            read -r user_ca
            if [ -z "$user_ca" ]; then
                echo "CA不能为空"
                return 1
            fi
            #验证CA有效性
            echo "正在验证CA有效性"
            local test_prompt="test"
            local test_token=$(_generate_token_for_api "$test_prompt")
            echo "生成测试token: $test_token"
            local ca_valid=false
            local temp_response
            local http_status
            local response_body
            #尝试API连接
            echo "尝试连接到API"
            #使用临时文件存储响应
            temp_response=$(mktemp)
            #发送请求，状态码单独一行
            curl -s -X POST \
                "${API_URL}/api/chat" \
                -H "Content-Type: application/json" \
                -H "ca: ${user_ca}" \
                -d "{\"prompt\":\"$test_prompt\",\"token\":\"$test_token\",\"stream\":false}" \
                --connect-timeout 10 \
                --max-time 30 \
                -o "$temp_response" \
                -w "%{http_code}"
            temp_response=$(mktemp)
            local http_code
            http_code=$(curl -s -X POST \
                "${API_URL}/api/chat" \
                -H "Content-Type: application/json" \
                -H "ca: ${user_ca}" \
                -d "{\"prompt\":\"$test_prompt\",\"token\":\"$test_token\",\"stream\":false}" \
                --connect-timeout 10 \
                --max-time 30 \
                -o "$temp_response" \
                -w "%{http_code}")
            echo "HTTP状态码: $http_code"
            if [ "$http_code" = "200" ]; then
                response_body=$(cat "$temp_response")
                if echo "$response_body" | jq -e '.output' >/dev/null 2>&1; then
                    local chat_output=$(echo "$response_body" | jq -r '.output')
                    if [ -n "$chat_output" ] && [ "$chat_output" != "null" ]; then
                        ca_valid=true
                        echo "CA验证成功"
                    else
                        echo "API返回空输出，请重试"
                    fi
                else
                    echo "响应格式错误"
                    echo "响应内容: $response_body"
                fi
            else
                echo "连接失败, HTTP状态码: $http_code"
                response_body=$(cat "$temp_response" 2>/dev/null)
                echo "响应内容: $response_body"
            fi
            rm -f "$temp_response"
            if [ "$ca_valid" = false ]; then #显示调试信息
                echo "调试信息:"
                echo "CA: ${user_ca:0:20}..."
                echo "Prompt: $test_prompt"
                echo "Token: $test_token"
                echo "手动测试命令:"
                echo "curl -X POST 'https://ai.coludai.cn/api/chat' \\"
                echo "  -H 'Content-Type: application/json' \\"
                echo "  -H 'ca: ${user_ca}' \\"
                echo "  -d '{\"prompt\":\"test\",\"token\":\"$test_token\",\"stream\":false}'"
                echo -n "是否继续保存配置 [y/N]: "
                read -r force_save
                if [ "$force_save" != "y" ] && [ "$force_save" != "Y" ]; then
                    echo "操作已取消"
                    return 1
                fi
                ca_valid=true
            fi
            local encoded_pw=$(echo -n "$password" | base64 | tr -d '\n') #终于你🐎的我艹了终于完事了我艹🐎🖊的
            {
                echo "#在此Linux系统中由UCST生成的CA配置文件-生成于$(date '+%Y-%m-%d %H:%M:%S')"
                echo "username='$username'"
                echo "password='$encoded_pw'"
                echo "ca='$user_ca'"
                echo "login_url='$LOGIN_URL'"
                echo "api_url='$API_URL'"
                echo "last_update='$(date +%s)'"
            } > "$config_file"
            chmod 600 "$config_file"
            echo "配置保存成功"
            echo "文件: $config_file"
            echo "用户: $username"
            echo "CA: ${user_ca:0:12}..."
            echo -n "是否立即测试配置 [Y/n]: "
            read -r test_now
            if [ "$test_now" != "n" ] && [ "$test_now" != "N" ]; then
                command_account "-t"
            fi
            ;;
        "-i"|"--info")
            if [ ! -f "$config_file" ]; then
                echo "未找到配置文件, 请使用'account -s'设置账户和CA"
                return 1
            fi
            echo "===账户信息==="
            echo "配置文件: $config_file"
            echo "修改时间: $(stat -c %y "$config_file" 2>/dev/null || echo '未知')"
            while IFS= read -r line; do #显示配置
                case "$line" in
                    username=*)
                        echo "用户名: ${line#username=}" | sed "s/'//g"
                        ;;
                    ca=*)
                        local ca_val=${line#ca=}
                        ca_val=$(echo "$ca_val" | sed "s/'//g")
                        echo "CA令牌: ${ca_val:0:12}...${ca_val: -8}"
                        ;;
                    api_url=*)
                        echo "API地址: ${line#api_url=}" | sed "s/'//g"
                        ;;
                    login_url=*)
                        echo "登录地址: ${line#login_url=}" | sed "s/'//g"
                        ;;
                    last_update=*)
                        local ts=${line#last_update=}
                        ts=$(echo "$ts" | sed "s/'//g")
                        echo "最后更新: $(date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '未知')"
                        ;;
                esac
            done < "$config_file"
            ;;  
        "-t"|"--test")
            echo "===API连接测试==="
            if [ ! -f "$config_file" ]; then
                echo "未找到配置文件"
                return 1
            fi
            local config_ca=$(grep '^ca=' "$config_file" | cut -d"'" -f2 2>/dev/null) #读取配置的配置
            local config_api_url=$(grep '^api_url=' "$config_file" | cut -d"'" -f2 2>/dev/null)
            if [ -z "$config_ca" ]; then
                echo "未配置CA"
                return 1
            fi
            if [ -z "$config_api_url" ]; then
                config_api_url="https://ai.coludai.cn"
            fi
            echo "API服务器: $config_api_url" #你🐎的API折磨我两天
            echo "测试CA: ${config_ca:0:12}..."
            echo ""
            echo "1 测试网络连接" #网络连接
            local domain=$(echo "$config_api_url" | sed 's|https*://||' | sed 's|/.*||')
            if ping -c 1 -W 2 "$domain" >/dev/null 2>&1; then
                echo "网络连接正常"
            else
                echo "网络连接失败"
            fi
            echo "2.测试聊天API" #聊天API
            local test_prompt="你是谁"
            local test_token=$(_generate_token_for_api "$test_prompt")
            echo "   Prompt: $test_prompt"
            echo "   Token: $test_token"
            local temp_file=$(mktemp)
            local http_code
            http_code=$(curl -s -X POST \
                "${config_api_url}/api/chat" \
                -H "Content-Type: application/json" \
                -H "ca: ${config_ca}" \
                -d "{\"prompt\":\"$test_prompt\",\"token\":\"$test_token\",\"stream\":false}" \
                --connect-timeout 10 \
                -o "$temp_file" \
                -w "%{http_code}")
            echo "   HTTP状态码: $http_code"
            if [ "$http_code" = "200" ]; then
                if jq -e '.output' "$temp_file" >/dev/null 2>&1; then
                    local output=$(jq -r '.output' "$temp_file")
                    echo "   成功"
                    echo "   回复: ${output:0:80}"
                else
                    local error=$(jq -r '.detail // "未知错误"' "$temp_file" 2>/dev/null)
                    echo "   失败"
                    echo "   错误: $error"
                fi
            else
                echo "   失败, HTTP状态码: $http_code"
                if [ -s "$temp_file" ]; then
                    echo "   响应: $(head -c 200 "$temp_file")"
                fi
            fi
            rm -f "$temp_file"
            echo "3.测试Coder API" #Coder API
            local coder_prompt="print hello"
            local coder_token=$(_generate_token_for_api "$coder_prompt")
            temp_file=$(mktemp)
            http_code=$(curl -s -X POST \
                "${config_api_url}/api/chat/coder" \
                -H "Content-Type: application/json" \
                -H "ca: ${config_ca}" \
                -d "{\"prompt\":\"$coder_prompt\",\"token\":\"$coder_token\",\"stream\":false,\"sysprompt\":\"\"}" \
                --connect-timeout 10 \
                -o "$temp_file" \
                -w "%{http_code}")
            echo "   HTTP状态码: $http_code"
            if [ "$http_code" = "200" ]; then
                if jq -e '.output' "$temp_file" >/dev/null 2>&1; then
                    local output=$(jq -r '.output' "$temp_file")
                    echo "   成功"
                    echo "   回复: ${output:0:80}"
                else
                    local error=$(jq -r '.detail // "未知错误"' "$temp_file" 2>/dev/null)
                    echo "   失败"
                    echo "   错误: $error"
                fi
            else
                echo "   失败, HTTP状态码: $http_code"
                if [ -s "$temp_file" ]; then
                    echo "   响应: $(head -c 200 "$temp_file")"
                fi
            fi
            rm -f "$temp_file"
            ;;
        *)
            echo "account 命令用法"
            echo "account -s   -登录并设置账户"
            echo "account -i   -查看账户信息"
            echo "account -t   -测试API连接"
            echo "注意"
            echo "1.如果登录接口失败, 请直接输入CA令牌，但通常失败只是暂时的"
            echo "2.CA请从coludai账户页面获取"
            echo "3.API地址默认使用 https://ai.coludai.cn"
            echo "4.UCST工具暂不提供coludai账号注册服务，注册账号请前往account.coludai.cn"
            return 1
            ;;
    esac
    
    return 0
}

command_sai() {
    local config_file="$HOME/.ucst_sai_config"
    
    # 检查依赖
    for cmd in curl jq md5sum; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "缺少命令: $cmd，请安装"
            return 1
        fi
    done
    
    # 读取配置
    if [ ! -f "$config_file" ]; then
        echo "请先运行 'account -s' 配置 CA"
        return 1
    fi
    local api_url=$(grep '^api_url=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    local ca=$(grep '^ca=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    if [ -z "$api_url" ]; then
        api_url="https://ai.coludai.cn"
    fi
    if [ -z "$ca" ]; then
        echo "未找到 CA，请重新配置"
        return 1
    fi
    
    # 创建或获取当前会话
    # 如果没有活跃会话，新建一个
    if [ -z "$_SAI_CURRENT_SESSION" ]; then
        echo "正在创建新会话..."
        local create_resp=$(curl -s -X POST "${api_url}/api/session/create" \
            -H "Content-Type: application/json" \
            -H "ca: $ca" \
            -d '{"name":"UCST_CHAT"}')
        local new_sid=$(echo "$create_resp" | jq -r '.sessionid // empty')
        if [ -n "$new_sid" ]; then
            _SAI_CURRENT_SESSION="$new_sid"
            _add_local_session "$new_sid"
            echo "新会话已创建: ${new_sid:0:12}..."
            sleep 1
        else
            echo "创建会话失败，请检查网络或 CA"
            return 1
        fi
    fi
    
    # 清除旧的历史缓存
    _SAI_HISTORY_CACHE=""
    
    # 进入全屏
    clear
    
    # 主循环
    local running=true
    while $running; do
        # 绘制界面（包含历史）
        _draw_chat_interface
        # 光标移到输入行
        echo -n "您: "
        read -r user_input
        
        # 处理命令
        case "$user_input" in
            "/quit")
                running=false
                break
                ;;
            "/history")
                # 显示本地会话列表，让用户选择
                local sessions=$(cat "$SAI_SESSIONS_FILE" 2>/dev/null)
                if [ -z "$sessions" ]; then
                    echo "没有历史会话记录。"
                    sleep 1
                    continue
                fi
                echo ""
                echo "=== 历史会话列表 ==="
                local idx=1
                while IFS='|' read -r sid ts sum; do
                    echo "  $idx) $sid  (创建于 $ts) 摘要: $sum"
                    idx=$((idx+1))
                done <<< "$sessions"
                echo -n "请输入序号切换，或按回车取消: "
                read -r choice
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    local selected_sid=$(sed -n "${choice}p" "$SAI_SESSIONS_FILE" | cut -d'|' -f1)
                    if [ -n "$selected_sid" ]; then
                        _SAI_CURRENT_SESSION="$selected_sid"
                        # 清除旧缓存，并拉取历史
                        _SAI_HISTORY_CACHE=""
                        local history=$(_fetch_session_history "$_SAI_CURRENT_SESSION" "$api_url" "$ca")
                        if [ -n "$history" ]; then
                            _SAI_HISTORY_CACHE="$history"
                        fi
                        echo "已切换到会话: ${_SAI_CURRENT_SESSION:0:12}..."
                        sleep 1
                    fi
                fi
                continue
                ;;
            "")
                continue
                ;;
            *)
                # 普通消息
                # 显示"正在思考..."（绿色）
                echo -e "\033[1A\033[K${COLOR_GREEN}正在思考...${COLOR_RESET}"
                # 生成 token
                local token=$(_generate_token_for_api "$user_input")
                # 调用 API
                local json_data="{\"prompt\":\"$user_input\",\"token\":\"$token\",\"stream\":false,\"sessionid\":\"$_SAI_CURRENT_SESSION\"}"
                local response=$(curl -s -X POST "${api_url}/api/chat" \
                    -H "Content-Type: application/json" \
                    -H "ca: $ca" \
                    -d "$json_data")
                # 解析输出
                local output=$(echo "$response" | jq -r '.output // empty')
                if [ -n "$output" ]; then
                    # 解码 Unicode
                    output=$(echo -e "$output")
                    # 更新本地缓存（显示）
                    local new_entry="您: $user_input\nSAI: $output"
                    if [ -z "$_SAI_HISTORY_CACHE" ]; then
                        _SAI_HISTORY_CACHE="$new_entry"
                    else
                        _SAI_HISTORY_CACHE="${_SAI_HISTORY_CACHE}\n${new_entry}"
                    fi
                    # 更新摘要（仅第一次）
                    if ! grep -q "$_SAI_CURRENT_SESSION|" "$SAI_SESSIONS_FILE" | cut -d'|' -f3 | grep -q .; then
                        _update_session_summary "$_SAI_CURRENT_SESSION" "$(echo "$user_input" | head -c 30)"
                    fi
                else
                    # 错误处理
                    local err=$(echo "$response" | jq -r '.detail // "未知错误"')
                    echo "错误: $err"
                    sleep 1
                fi
                ;;
        esac
    done
    
    # 退出时不清屏，恢复普通终端
    echo "会话结束。"
}
# ======================== SAI 全屏交互（修复版） ========================
SAI_SESSION_DIR="$HOME/.ucst_sai_sessions"
SAI_SESSIONS_FILE="$SAI_SESSION_DIR/sessions.list"
mkdir -p "$SAI_SESSION_DIR"
_SAI_CURRENT_SESSION=""
_SAI_HISTORY_CACHE=""
# 颜色定义
COLOR_YELLOW='\033[33m'
COLOR_GREEN='\033[32m'
COLOR_RESET='\033[0m'
# ---------- token 生成（修正版） ----------
_generate_token_for_api() {
    local prompt="$1"
    local current_date=$(date +"%Y-%m-%d")
    local date_md5=$(echo -n "$current_date" | md5sum | awk '{print $1}')
    local date_md5_six="${date_md5:0:6}"
    local combined_str="${prompt}${date_md5_six}"   # 关键：日期MD5前6位拼在prompt后面
    local token=$(echo -n "$combined_str" | md5sum | awk '{print $1}')
    echo "$token"
}
# ---------- 本地会话管理 ----------
_get_local_sessions() {
    [ -f "$SAI_SESSIONS_FILE" ] && cat "$SAI_SESSIONS_FILE" || return 1
}
_add_local_session() {
    local sessionid="$1"
    if grep -q "^$sessionid|" "$SAI_SESSIONS_FILE" 2>/dev/null; then
        return 0
    fi
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$sessionid|$timestamp|新会话" >> "$SAI_SESSIONS_FILE"
}
_update_session_summary() {
    local sessionid="$1"
    local summary="$2"
    local temp_file=$(mktemp)
    while IFS='|' read -r sid ts sum; do
        if [ "$sid" = "$sessionid" ]; then
            echo "$sid|$ts|$summary"
        else
            echo "$sid|$ts|$sum"
        fi
    done < "$SAI_SESSIONS_FILE" > "$temp_file"
    mv "$temp_file" "$SAI_SESSIONS_FILE"
}
# ---------- 历史查询（修正字段名和解析） ----------
_fetch_session_history() {
    local sessionid="$1"
    local api_url="$2"
    local ca="$3"
    local response
    response=$(curl -s -X POST "${api_url}/api/session/query" \
        -H "Content-Type: application/json" \
        -H "ca: $ca" \
        -d "{\"sessionid\":\"$sessionid\"}")
    
    # 检查是否有效JSON数组
    if echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
        # 提取 role 和 content（注意API返回的是 content，不是 cotent）
        echo "$response" | jq -r '.[] | "\(.role): \(.content // "")"' 2>/dev/null
    else
        echo ""
    fi
}
_draw_chat_interface() {
    clear
    echo "===== SAI-Coder (ColudAI-秋田人工智能团队出品) (会话: ${_SAI_CURRENT_SESSION:0:12}...) ====="
    echo "输入消息按回车发送 | /quit 退出 | /history 切换会话"
    echo "----------------------------------------"
    
    if [ -n "$_SAI_HISTORY_CACHE" ]; then
        # 修改此处：使用 echo -e 解释转义序列
        echo -e "$_SAI_HISTORY_CACHE"
    else
        echo "（暂无历史记录，开始对话吧）"
    fi
    echo "----------------------------------------"
    echo -n "我："
}
# ---------- 主命令 ----------
command_sai() {
    local config_file="$HOME/.ucst_sai_config"
    
    for cmd in curl jq md5sum; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "缺少命令: $cmd，请安装"
            return 1
        fi
    done
    
    if [ ! -f "$config_file" ]; then
        echo "请先运行 'account -s' 配置 CA"
        return 1
    fi
    local api_url=$(grep '^api_url=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    local ca=$(grep '^ca=' "$config_file" | cut -d"'" -f2 2>/dev/null)
    if [ -z "$api_url" ]; then
        api_url="https://ai.coludai.cn"
    fi
    if [ -z "$ca" ]; then
        echo "未找到 CA，请重新配置"
        return 1
    fi
    
    if [ -z "$_SAI_CURRENT_SESSION" ]; then
        echo "正在创建新会话..."
        local create_resp=$(curl -s -X POST "${api_url}/api/session/create" \
            -H "Content-Type: application/json" \
            -H "ca: $ca" \
            -d '{"name":"UCST_CHAT"}')
        local new_sid=$(echo "$create_resp" | jq -r '.sessionid // empty')
        if [ -n "$new_sid" ]; then
            _SAI_CURRENT_SESSION="$new_sid"
            _add_local_session "$new_sid"
            echo "新会话已创建: ${new_sid:0:12}..."
            sleep 1
        else
            echo "创建会话失败，请检查网络或 CA"
            return 1
        fi
    fi
    
    _SAI_HISTORY_CACHE=""
    
    # ---------- 进入备用屏幕（全屏，类似 vim） ----------
    tput smcup
    # 清空备用屏幕（可选，通常备用屏幕是全新的）
    clear
    
    local running=true
    while $running; do
        _draw_chat_interface
        read -r user_input
        
        case "$user_input" in
            "/quit")
                running=false
                break
                ;;
            "/history")
                local sessions=$(cat "$SAI_SESSIONS_FILE" 2>/dev/null)
                if [ -z "$sessions" ]; then
                    echo "没有历史会话记录。"
                    sleep 1
                    continue
                fi
                echo ""
                echo "=== 历史会话列表 ==="
                local idx=1
                while IFS='|' read -r sid ts sum; do
                    echo "  $idx) $sid  (创建于 $ts) 摘要: $sum"
                    idx=$((idx+1))
                done <<< "$sessions"
                echo -n "请输入序号切换，或按回车取消: "
                read -r choice
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    local selected_sid=$(sed -n "${choice}p" "$SAI_SESSIONS_FILE" | cut -d'|' -f1)
                    if [ -n "$selected_sid" ]; then
                        _SAI_CURRENT_SESSION="$selected_sid"
                        _SAI_HISTORY_CACHE=""
                        local history=$(_fetch_session_history "$_SAI_CURRENT_SESSION" "$api_url" "$ca")
                    if [ -n "$history" ]; then
                        local formatted=""
                        local user_msg=""
                        local assistant_msg=""
                        while IFS= read -r line; do
                            if [[ "$line" =~ ^user: ]]; then
                                user_msg="我：${line#user: }"
                            elif [[ "$line" =~ ^assistant: ]]; then
                                assistant_msg="SAI：${line#assistant: }"
                                if [ -n "$user_msg" ] && [ -n "$assistant_msg" ]; then
                                    if [ -z "$formatted" ]; then
                                        formatted="${user_msg}\n${assistant_msg}\n----------------------------------------"
                                    else
                                        formatted="${formatted}\n${user_msg}\n${assistant_msg}\n----------------------------------------"
                                    fi
                                    user_msg=""
                                    assistant_msg=""
                                fi
                            fi
                        done <<< "$history"
                        _SAI_HISTORY_CACHE="$formatted"
                    fi
                        echo "已切换到会话: ${_SAI_CURRENT_SESSION:0:12}..."
                        sleep 1
                    fi
                fi
                continue
                ;;
            "")
                continue
                ;;
            *)
                # “正在思考”显示为绿色
                echo -e "\033[1A\033[K${COLOR_GREEN}正在思考...${COLOR_RESET}"
                
                local token=$(_generate_token_for_api "$user_input")
                local json_data="{\"prompt\":\"$user_input\",\"token\":\"$token\",\"stream\":false,\"sessionid\":\"$_SAI_CURRENT_SESSION\"}"
                local response=$(curl -s -X POST "${api_url}/api/chat" \
                    -H "Content-Type: application/json" \
                    -H "ca: $ca" \
                    -d "$json_data")
                
                local output=""
                if echo "$response" | jq -e '.output' >/dev/null 2>&1; then
                    output=$(echo "$response" | jq -r '.output // empty')
                else
                    local inner=$(echo "$response" | jq -r . 2>/dev/null)
                    if [ -n "$inner" ]; then
                        output=$(echo "$inner" | jq -r '.output // empty' 2>/dev/null)
                    fi
                fi
                
                if [ -n "$output" ]; then
                    output=$(echo -e "$output")
                    local user_entry="我：$user_input"
                    local sai_entry="SAI：${COLOR_YELLOW}$output${COLOR_RESET}"
                    local divider="----------------------------------------"
                    local new_block="${user_entry}\n${sai_entry}"
                    if [ -z "$_SAI_HISTORY_CACHE" ]; then
                        _SAI_HISTORY_CACHE="${new_block}"
                    else
                        # 在已有内容和新内容之间插入分隔线
                         _SAI_HISTORY_CACHE="${_SAI_HISTORY_CACHE}\n${divider}\n${new_block}"
                    fi
                    # 更新摘要...
                    if ! grep -q "$_SAI_CURRENT_SESSION|" "$SAI_SESSIONS_FILE" | cut -d'|' -f3 | grep -q .; then
                        _update_session_summary "$_SAI_CURRENT_SESSION" "$(echo "$user_input" | head -c 30)"
                    fi
                else
                    local err=$(echo "$response" | jq -r '.detail // "未知错误"' 2>/dev/null)
                    echo "错误: $err"
                    sleep 1
                fi
                ;;
        esac
    done
    
    # ---------- 恢复主屏幕（退出全屏，保留原终端内容） ----------
    tput rmcup
    echo "会话结束。"
}
command_service() {
    local action="$1"
    local service_name="$2"

    # 如果无参数，列出所有服务后立即返回
    if [ -z "$action" ]; then
        echo "=== 所有服务运行状态 ==="
        if command -v systemctl >/dev/null 2>&1; then
            printf "%-30s %-12s %-10s\n" "服务名" "状态" "运行状态"
            printf "%-30s %-12s %-10s\n" "------------------------------" "------------" "----------"
            systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null | \
            while read -r unit load active sub description; do
                [ -z "$unit" ] && continue
                service_name="${unit%.service}"
                if [ "$load" = "not-found" ]; then
                    status="未找到"
                    sub=""
                else
                    status="$active"
                fi
                printf "%-30s %-12s %-10s\n" "$service_name" "$status" "$sub"
            done
        else
            service --status-all 2>/dev/null | \
            while read -r line; do
                status_char=$(echo "$line" | awk '{print $2}')
                svc=$(echo "$line" | awk '{print $4}')
                if [ "$status_char" = "+" ]; then
                    status="运行中"
                elif [ "$status_char" = "-" ]; then
                    status="已停止"
                else
                    status="未知"
                fi
                printf "%-30s %-12s\n" "$svc" "$status"
            done
        fi
        return 0
    fi

    # 检查 systemctl 是否存在
    if command -v systemctl >/dev/null 2>&1; then
        local use_systemctl=true
    elif command -v service >/dev/null 2>&1; then
        local use_systemctl=false
    else
        echo "错误: 未找到 systemctl 或 service 命令"
        echo "请确保系统已安装 systemd 或 sysvinit"
        return 1
    fi

    # 处理带参数的情况
    case "$action" in
        "-k")
            if [ -z "$service_name" ]; then
                echo "用法: service -k <服务名>"
                return 1
            fi
            echo "正在停止服务: $service_name"
            if [ "$use_systemctl" = true ]; then
                if systemctl is-active --quiet "$service_name"; then
                    sudo systemctl stop "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "服务 $service_name 已停止"
                    else
                        echo "停止服务失败，请检查权限或服务名是否正确"
                    fi
                else
                    echo "服务 $service_name 未在运行，无需停止"
                fi
            else
                if service "$service_name" status >/dev/null 2>&1; then
                    sudo service "$service_name" stop
                    if [ $? -eq 0 ]; then
                        echo "服务 $service_name 已停止"
                    else
                        echo "停止服务失败，请检查权限或服务名是否正确"
                    fi
                else
                    echo "服务 $service_name 未在运行，无需停止"
                fi
            fi
            ;;
        "-o")
            if [ -z "$service_name" ]; then
                echo "用法: service -o <服务名>"
                return 1
            fi
            echo "正在启动服务: $service_name"
            if [ "$use_systemctl" = true ]; then
                if systemctl is-active --quiet "$service_name"; then
                    echo "服务 $service_name 已在运行，无需启动"
                else
                    sudo systemctl start "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "服务 $service_name 已启动"
                    else
                        echo "启动服务失败，请检查权限或服务名是否正确"
                    fi
                fi
            else
                if service "$service_name" status >/dev/null 2>&1; then
                    echo "服务 $service_name 已在运行，无需启动"
                else
                    sudo service "$service_name" start
                    if [ $? -eq 0 ]; then
                        echo "服务 $service_name 已启动"
                    else
                        echo "启动服务失败，请检查权限或服务名是否正确"
                    fi
                fi
            fi
            ;;
        *)
            # 默认显示指定服务信息
            service_name="$action"
            echo "=== 服务信息: $service_name ==="
            if [ "$use_systemctl" = true ]; then
                systemctl status "$service_name" --no-pager 2>/dev/null || echo "服务 $service_name 不存在或无法获取状态"
            else
                service "$service_name" status 2>/dev/null || echo "服务 $service_name 不存在或无法获取状态"
            fi
            ;;
    esac
}

# ------------------- update 命令相关函数 -------------------
# 解码 Base64 版本标识
_decode_version() {
    local encoded="$1"
    echo "$encoded" | base64 -d 2>/dev/null || echo "未知版本"
}

# 获取当前 UCST 版本信息
_get_current_ucst_version() {
    local script_path="/usr/local/bin/UCST-English"
    if [ -f "$script_path" ]; then
        local version_line=$(sed -n '3p' "$script_path" 2>/dev/null)
        if [[ "$version_line" =~ UCST_VERSION:[[:space:]]*([A-Za-z0-9+/=]+) ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    echo "未知"
}

# 从 GitHub 获取最新 UCST 版本信息
_get_latest_ucst_version() {
    local raw_url="https://raw.githubusercontent.com/HXLG-F/Ubuntu-Command-Simplification-Tool/main/UCST-English"
    local temp_file=$(mktemp)
    if wget -q -O "$temp_file" "$raw_url" 2>/dev/null; then
        local version_line=$(sed -n '3p' "$temp_file" 2>/dev/null)
        rm -f "$temp_file"
        if [[ "$version_line" =~ UCST_VERSION:[[:space:]]*([A-Za-z0-9+/=]+) ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    echo "未知"
}

# 获取 apt 包大小
_get_package_size() {
    local pkg="$1"
    apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Size:" | awk '{print $2}' | numfmt --to=iec 2>/dev/null || echo "未知"
}

# ------------------- update 主命令 -------------------
command_update() {
    local action="$1"
    local target="$2"

    if [ -z "$action" ]; then
        # ---- 启动动态省略号动画（后台） ----
        echo -n "正在检查更新，请稍后"
        while true; do
            for i in . .. ... ....; do
                echo -ne "\r正在检查更新，请稍后$i"
                sleep 0.3
            done
        done &
        local anim_pid=$!
        trap 'kill $anim_pid 2>/dev/null; wait $anim_pid 2>/dev/null; echo; return' INT TERM

        # ---- 准备数据 ----
        local table_data=()
        local index=1

        # ---- 阶段1: apt 包更新 ----
        echo -ne "\r正在检查更新，请稍后... [1/3] 正在检查 apt 软件包更新...   "
                # ---- A) apt 包更新 ----
        if command -v apt >/dev/null 2>&1; then
            local apt_raw
            apt_raw=$(timeout 10 apt list --upgradable 2>/dev/null | grep -v "Listing..." | head -20)
            if [ -n "$apt_raw" ]; then
                # 提取包名（第一个字段，去掉/后的发行版信息）
                local pkg_names=$(echo "$apt_raw" | awk -F/ '{print $1}' | tr '\n' ' ')
                for pkg in $pkg_names; do
                    # 使用 apt-cache policy 获取版本
                    local policy=$(apt-cache policy "$pkg" 2>/dev/null)
                    local current=$(echo "$policy" | grep "Installed:" | awk '{print $2}')
                    local available=$(echo "$policy" | grep "Candidate:" | awk '{print $2}')
                    [ -z "$current" ] && current="未安装"
                    [ -z "$available" ] && available="未知"
                    local size=$(_get_package_size "$pkg")
                    table_data+=("$index|A|$pkg|$current|$available|$size")
                    ((index++))
                done
            fi
        fi
        echo -ne "\r正在检查更新，请稍后... [1/3] 完成                     \n"

        # ---- 阶段2: snap 包更新 ----
        echo -ne "\r正在检查更新，请稍后... [2/3] 正在检查 snap 软件包更新...   "
        if command -v snap >/dev/null 2>&1; then
            local snap_updates
            snap_updates=$(timeout 5 snap refresh --list 2>/dev/null | grep -v "Name" | grep -v "All snaps" | head -10)
            if [ -n "$snap_updates" ]; then
                while IFS= read -r line; do
                    local name=$(echo "$line" | awk '{print $1}')
                    local current=$(echo "$line" | awk '{print $2}')
                    local available=$(echo "$line" | awk '{print $3}')
                    table_data+=("$index|B|$name|$current|$available|未知")
                    ((index++))
                done <<< "$snap_updates"
            fi
        fi
        echo -ne "\r正在检查更新，请稍后... [2/3] 完成                     \n"

        # ---- 阶段3: UCST 自身更新 ----
        echo -ne "\r正在检查更新，请稍后... [3/3] 正在检查 UCST 工具更新...   "
        local current_ucst=$(_get_current_ucst_version)
        local latest_ucst="未知"
        local temp_version_file=$(mktemp)

        # 使用 timeout 限制 wget 执行时间（5秒），防止卡死
        if timeout 5 wget -q -O "$temp_version_file" "https://raw.githubusercontent.com/HXLG-F/Ubuntu-Command-Simplification-Tool/main/UCST-English" 2>/dev/null; then
            local version_line=$(sed -n '3p' "$temp_version_file" 2>/dev/null)
            if [[ "$version_line" =~ UCST_VERSION:[[:space:]]*([A-Za-z0-9+/=]+) ]]; then
                latest_ucst="${BASH_REMATCH[1]}"
            fi
        fi
        rm -f "$temp_version_file"

        if [ "$latest_ucst" != "未知" ] && [ "$current_ucst" != "$latest_ucst" ] && [ "$latest_ucst" != "" ]; then
            local current_decoded=$(_decode_version "$current_ucst")
            local latest_decoded=$(_decode_version "$latest_ucst")
            # 同样为获取包大小添加超时
            local size=$(timeout 5 wget --spider -S "https://raw.githubusercontent.com/HXLG-F/Ubuntu-Command-Simplification-Tool/main/UCST-English" 2>&1 | grep -i "content-length" | awk '{print $2}' | numfmt --to=iec 2>/dev/null || echo "未知")
            table_data+=("$index|C|UCST工具|$current_decoded|$latest_decoded|$size")
            ((index++))
        fi
        echo -ne "\r正在检查更新，请稍后... [3/3] 完成                     \n"

        # ---- 停止动画并清行 ----
        kill $anim_pid 2>/dev/null
        wait $anim_pid 2>/dev/null
        echo -e "\r正在检查更新，请稍后... 全部完成    "
        echo ""

        # ---- 显示结果 ----
        if [ ${#table_data[@]} -eq 0 ]; then
            echo "=== 所有组件可用更新列表 ==="
            echo ""
            echo "所有组件已是最新版本"
            return 0
        fi

        echo "=== 所有组件可用更新列表 ==="
        echo ""
        printf "%-6s %-4s %-30s %-20s %-20s %-10s\n" "编号" "类型" "组件名" "当前版本" "可用版本" "大小"
        printf "%-6s %-4s %-30s %-20s %-20s %-10s\n" "------" "----" "------------------------------" "--------------------" "--------------------" "----------"
        for entry in "${table_data[@]}"; do
            IFS='|' read -r idx type name current available size <<< "$entry"
            printf "%-6s %-4s %-30s %-20s %-20s %-10s\n" "$idx" "$type" "$name" "$current" "$available" "$size"
        done
        echo ""
        echo -n "请输入要更新的组件编号（多个用空格分隔，如 '1 3 5'），或输入 'all' 更新全部，按回车取消: "
        read -r selection

        if [ -z "$selection" ]; then
            echo "操作已取消"
            return 0
        fi

        if [ "$selection" = "all" ]; then
            selection=$(printf '%s\n' "${table_data[@]}" | cut -d'|' -f1 | tr '\n' ' ')
        fi

        for idx in $selection; do
            local found_entry=""
            for entry in "${table_data[@]}"; do
                if [[ "$entry" == "$idx|"* ]]; then
                    found_entry="$entry"
                    break
                fi
            done

            if [ -z "$found_entry" ]; then
                echo "编号 $idx 无效，跳过"
                continue
            fi

            IFS='|' read -r _ type name current available size <<< "$found_entry"
            echo ""
            echo "正在更新: $name (类型: $type)"

            case "$type" in
                A)
                    echo "需要管理员权限，请输入密码"
                    sudo apt install --only-upgrade -y "$name"
                    if [ $? -eq 0 ]; then
                        echo "$name 更新成功"
                    else
                        echo "$name 更新失败"
                    fi
                    ;;
                B)
                    sudo snap refresh "$name"
                    if [ $? -eq 0 ]; then
                        echo "$name 更新成功"
                    else
                        echo "$name 更新失败"
                    fi
                    ;;
                C)
                    echo "更新 UCST 工具..."
                    _update_ucst
                    ;;
                D)
                    echo "自定义组件更新逻辑待实现"
                    ;;
                *)
                    echo "未知类型: $type"
                    ;;
            esac
        done
        echo ""
        echo "更新操作完成"
        return 0
    fi

    # ---- 用法2: update + 组件名 ----
    if [ -n "$action" ] && [ -z "$target" ]; then
        echo "=== 组件信息: $action ==="
        local found=false

        if apt-cache show "$action" >/dev/null 2>&1; then
            local current=$(apt list --installed 2>/dev/null | grep "^$action/" | head -1 | grep -oP '(?<=installed: )[^,]+' || echo "未安装")
            local available=$(apt-cache policy "$action" | grep -m1 "Candidate:" | awk '{print $2}' || echo "未知")
            local size=$(_get_package_size "$action")
            echo "组件类型: apt 包"
            echo "当前版本: $current"
            echo "可用版本: $available"
            echo "包大小: $size"
            found=true
        fi

        if [ "$found" = false ] && snap list 2>/dev/null | grep -q "^$action "; then
            local current=$(snap list | grep "^$action " | awk '{print $2}')
            local available=$(snap info "$action" 2>/dev/null | grep "latest/stable:" | awk '{print $2}' || echo "未知")
            echo "组件类型: snap 包"
            echo "当前版本: $current"
            echo "可用版本: $available"
            found=true
        fi

        if [ "$found" = false ] && { [ "$action" = "UCST" ] || [ "$action" = "UCST-English" ]; }; then
            local current=$(_get_current_ucst_version)
            local latest=$(_get_latest_ucst_version)
            echo "组件类型: UCST 工具"
            echo "当前版本: $(_decode_version "$current")"
            echo "可用版本: $(_decode_version "$latest")"
            found=true
        fi

        if [ "$found" = false ]; then
            echo "未找到组件: $action"
            return 1
        fi
        return 0
    fi

    # ---- 用法3: update + 组件名 + 版本号 ----
    if [ -n "$action" ] && [ -n "$target" ]; then
        echo "=== 查找指定版本: $action $target ==="
        if [ "$action" = "UCST" ] || [ "$action" = "UCST-English" ]; then
            local current=$(_get_current_ucst_version)
            local current_decoded=$(_decode_version "$current")
            local target_decoded=$(_decode_version "$target")

            echo "当前版本: $current_decoded"
            echo "目标版本: $target_decoded"

            if [ "$target_decoded" \< "$current_decoded" ]; then
                echo "警告: 目标版本 ($target_decoded) 旧于当前版本 ($current_decoded)"
                echo -n "是否确实要安装旧版本？(y/N): "
                read -r confirm
                if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                    echo "操作已取消"
                    return 0
                fi
            fi
            _update_ucst "$target"
        else
            echo "暂不支持指定版本更新非 UCST 组件"
        fi
        return 0
    fi

    echo "update 命令用法:"
    echo "  update              - 列出所有可用更新"
    echo "  update <组件名>      - 查询指定组件更新信息"
    echo "  update <组件名> <版本> - 安装指定版本"
    return 1
}
# ------------------- UCST 更新核心函数 -------------------
_update_ucst() {
    local target_version="$1"
    local raw_url="https://raw.githubusercontent.com/HXLG-F/Ubuntu-Command-Simplification-Tool/main/UCST-English"
    local backup_dir="/usr/local/.ucst_backup"
    local script_path="/usr/local/bin/UCST-English"
    local temp_file=$(mktemp)

    sudo mkdir -p "$backup_dir"

    if [ -f "$script_path" ]; then
        echo "正在备份当前版本..."
        local backup_name="UCST-English.backup.$(date +%Y%m%d_%H%M%S)"
        sudo cp "$script_path" "$backup_dir/$backup_name"
    fi

    echo "正在下载新版本..."
    if ! wget -q -O "$temp_file" "$raw_url"; then
        echo "下载失败，正在恢复..."
        _restore_ucst "$backup_dir"
        return 1
    fi

    if [ -n "$target_version" ]; then
        local downloaded_version=$(sed -n '3p' "$temp_file" | grep -oP '(?<=UCST_VERSION: )[A-Za-z0-9+/=]+')
        if [ "$downloaded_version" != "$target_version" ]; then
            echo "版本不匹配，期望: $target_version，实际: $downloaded_version"
            _restore_ucst "$backup_dir"
            rm -f "$temp_file"
            return 1
        fi
    fi

    echo "正在安装新版本..."
    sudo rm -f "$script_path"
    sudo mv "$temp_file" "$script_path"
    sudo chmod +x "$script_path"

    if [ ! -f "$script_path" ]; then
        echo "安装失败，正在恢复..."
        _restore_ucst "$backup_dir"
        return 1
    fi

    echo "正在重载符号链接..."
    command_restart 2>/dev/null || {
        echo "restart 命令不可用，手动重载符号链接..."
        silent_link_verify
    }

    sudo ls -t "$backup_dir"/UCST-English.backup.* 2>/dev/null | tail -n +4 | sudo xargs rm -f 2>/dev/null

    echo "UCST工具组件更新成功！"
    echo -n "是否需要重启计算机以完全生效？(y/N): "
    read -r reboot_choice
    if [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ]; then
        echo "系统将在5秒后重启..."
        sleep 5
        sudo reboot
    else
        echo "新版本已生效"
    fi
}
# ------------------- 恢复函数 -------------------
_restore_ucst() {
    local backup_dir="$1"
    local latest_backup=$(sudo ls -t "$backup_dir"/UCST-English.backup.* 2>/dev/null | head -1)

    if [ -n "$latest_backup" ]; then
        echo "正在从备份恢复: $latest_backup"
        sudo cp "$latest_backup" "/usr/local/bin/UCST-English"
        sudo chmod +x "/usr/local/bin/UCST-English"
        echo "恢复成功"
    else
        echo "没有找到可用备份，请手动恢复"
    fi
}
command_translate() {
    # 读取状态文件
    local state=0
    if [ -f "$UCST_TRANSLATE_STATE_FILE" ]; then
        state=$(cat "$UCST_TRANSLATE_STATE_FILE" | tr -d ' \n')
        [ -z "$state" ] && state=0
    fi

    # 如果当前已经启用（环境变量标记），则尝试禁用
    if [ -n "$UCST_TRANSLATE_ACTIVE" ] && [ "$UCST_TRANSLATE_ACTIVE" = "1" ]; then
        _translate_disable
        echo "0" > "$UCST_TRANSLATE_STATE_FILE"
        return 0
    fi

    # 否则尝试启用
    echo "正在启用报错翻译..."
    if _translate_enable; then
        echo "1" > "$UCST_TRANSLATE_STATE_FILE"
        echo "报错翻译已启用"
    else
        # 启用失败，保持状态文件为0
        echo "0" > "$UCST_TRANSLATE_STATE_FILE"
        return 1
    fi
    return 0
}
# ==================== ssh -r 救援命令 ====================
# 配置文件路径
SSH_R_CONFIG="/etc/ucst/ssh-r.conf"
SSH_R_SNAPSHOT_DIR="/var/log/ucst/snapshots"
SSH_R_PID_FILE="/tmp/ucst_ssh_r_local.pid"

# 默认值（如果配置文件缺少）
DEFAULT_SSH_USER="${SUDO_USER:-$USER}"
DEFAULT_SSH_PORT="22"

# ---------- 主命令 ----------
command_ssh_r() {
    # 加载配置
    if [ -f "$SSH_R_CONFIG" ]; then
        source "$SSH_R_CONFIG"
    else
        echo "错误: 配置文件 $SSH_R_CONFIG 不存在，请创建并设置以下变量:"
        echo "  PUBLIC_IP       - 本地公网IP"
        echo "  REVERSE_PORT    - 反向隧道端口（如443）"
        echo "  SNAPSHOT_PORT   - HTTP接收端口（如9999）"
        echo "  SNAPSHOT_DIR    - 快照存储目录（可选，默认 $SSH_R_SNAPSHOT_DIR）"
        return 1
    fi
    # 若未设置 SNAPSHOT_DIR，使用默认
    [ -z "$SNAPSHOT_DIR" ] && SNAPSHOT_DIR="$SSH_R_SNAPSHOT_DIR"
    mkdir -p "$SNAPSHOT_DIR" 2>/dev/null

    # 交互菜单
    while true; do
        echo ""
        echo "========== SSH-R 紧急救援系统 =========="
        echo "当前公网IP: $PUBLIC_IP"
        echo "反向隧道端口: $REVERSE_PORT"
        echo "HTTP接收端口: $SNAPSHOT_PORT"
        echo "快照存储目录: $SNAPSHOT_DIR"
        echo ""
        echo "1) 启动本地救生艇服务（反向隧道 + HTTP接收）"
        echo "2) 向可连接服务器部署救生艇脚本"
        echo "3) 查看本地服务状态"
        echo "4) 停止本地救生艇服务"
        echo "5) 退出"
        echo -n "请选择操作 [1-5]: "
        read -r choice
        case "$choice" in
            1) _ssh_r_start_local ;;
            2) _ssh_r_deploy_remote ;;
            3) _ssh_r_status ;;
            4) _ssh_r_stop_local ;;
            5) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

# ---------- 启动本地服务 ----------
_ssh_r_start_local() {
    if [ -f "$SSH_R_PID_FILE" ]; then
        local old_pid=$(cat "$SSH_R_PID_FILE" | awk '{print $1}')
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "本地服务已在运行 (PID: $old_pid)"
            return 0
        fi
        rm -f "$SSH_R_PID_FILE"
    fi

    echo "正在启动本地救生艇服务..."
    # 启动反向隧道监听 (socat)
    nohup socat TCP-LISTEN:$REVERSE_PORT,fork,reuseaddr EXEC:/bin/cat > /dev/null 2>&1 &
    local socat_pid=$!
    # 启动 HTTP 快照接收服务器
    nohup python3 -m http.server $SNAPSHOT_PORT --directory "$SNAPSHOT_DIR" > /dev/null 2>&1 &
    local http_pid=$!
    echo "$socat_pid $http_pid" > "$SSH_R_PID_FILE"
    echo "本地救生艇已启动 (反向隧道端口: $REVERSE_PORT, HTTP接收端口: $SNAPSHOT_PORT)"
    echo "PID: socat=$socat_pid, http=$http_pid"
}

# ---------- 停止本地服务 ----------
_ssh_r_stop_local() {
    if [ ! -f "$SSH_R_PID_FILE" ]; then
        echo "没有正在运行的本地服务"
        return 0
    fi
    local pids=$(cat "$SSH_R_PID_FILE")
    for pid in $pids; do
        kill "$pid" 2>/dev/null && echo "已终止进程 $pid"
    done
    rm -f "$SSH_R_PID_FILE"
    echo "本地救生艇服务已停止"
}

# ---------- 查看状态 ----------
_ssh_r_status() {
    if [ -f "$SSH_R_PID_FILE" ]; then
        local pids=$(cat "$SSH_R_PID_FILE")
        echo "本地服务运行中，PID: $pids"
        echo "反向隧道端口: $REVERSE_PORT"
        echo "HTTP接收端口: $SNAPSHOT_PORT"
        echo "快照存储目录: $SNAPSHOT_DIR"
    else
        echo "本地服务未运行"
    fi
}

# ---------- 部署远程救生艇 ----------
_ssh_r_deploy_remote() {
    echo ""
    echo "=== 部署救生艇脚本到远程服务器 ==="
    echo "当前配置（来自 $SSH_R_CONFIG）："
    echo "  本地公网IP: $PUBLIC_IP"
    echo "  反向隧道端口: $REVERSE_PORT"
    echo "  HTTP接收端口: $SNAPSHOT_PORT"
    echo "  快照存储目录: $SNAPSHOT_DIR"
    echo ""
    echo "请提供需要救援的服务器列表（支持多个，空格分隔）:"
    echo "示例: 192.168.1.10 192.168.1.11 host-03"
    echo -n "服务器地址: "
    read -r -a servers
    if [ ${#servers[@]} -eq 0 ]; then
        echo "未输入任何服务器，取消部署"
        return 0
    fi

    echo -n "SSH 用户名 [默认: $DEFAULT_SSH_USER]: "
    read -r ssh_user
    [ -z "$ssh_user" ] && ssh_user="$DEFAULT_SSH_USER"

    echo -n "SSH 端口 [默认: $DEFAULT_SSH_PORT]: "
    read -r ssh_port
    [ -z "$ssh_port" ] && ssh_port="$DEFAULT_SSH_PORT"

    # 生成远程脚本
    local remote_script="/tmp/ucst_remote_agent.sh"
    cat > "$remote_script" 
#!/bin/bash
PUBLIC_IP="$1"
REVERSE_PORT="$2"
SNAPSHOT_PORT="$3"

collect_snapshot() {
    local snapshot=$(mktemp)
    echo "{\"timestamp\":\"$(date -Iseconds)\", \"hostname\":\"$(hostname)\", \"uptime\":\"$(uptime -p)\", \"loadavg\":\"$(cat /proc/loadavg)\", \"processes\":\"$(ps aux | head -20)\"}" > "$snapshot"
    echo "$snapshot"
}

send_via_tunnel() {
    local snapshot="$1"
    nc -zv "$PUBLIC_IP" "$REVERSE_PORT" 2>/dev/null && cat "$snapshot" | nc "$PUBLIC_IP" "$REVERSE_PORT"
}

send_via_http() {
    local snapshot="$1"
    curl -s -X POST -H "Content-Type: application/json" -d @"$snapshot" "http://$PUBLIC_IP:$SNAPSHOT_PORT/" > /dev/null
}

while true; do
    snapshot_file=$(collect_snapshot)
    send_via_tunnel "$snapshot_file" || send_via_http "$snapshot_file"
    rm -f "$snapshot_file"
    sleep 60
done
EOF

    # 逐个部署
    for server in "${servers[@]}"; do
        echo "正在部署到 $server ..."
        scp -P "$ssh_port" -o ConnectTimeout=5 "$remote_script" "${ssh_user}@${server}:$remote_script" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "  SCP 上传失败，跳过 $server"
            continue
        fi
        ssh -p "$ssh_port" -o ConnectTimeout=5 "${ssh_user}@$server" \
            "chmod +x $remote_script && nohup $remote_script $PUBLIC_IP $REVERSE_PORT $SNAPSHOT_PORT > /dev/null 2>&1 &" &
        echo "  已部署到 $server"
    done
    rm -f "$remote_script"
    echo "远程部署完成"
}
# ---------- fix 命令依赖 ----------
_fix_ensure_deps() {
    local missing=()
    command -v debsums >/dev/null 2>&1 || missing+=("debsums")
    command -v systemctl >/dev/null 2>&1 || missing+=("systemd")
    if [ ${#missing[@]} -gt 0 ]; then
        echo "正在安装缺失依赖: ${missing[*]}"
        for pkg in "${missing[@]}"; do
            _silent_install "$pkg"
        done
    fi
}
# 检查 APT 包完整性
_fix_check_apt() {
    local problems=()
    # 获取所有已安装的包，排除自动安装的依赖？不排除所有。
    local pkg_list=$(dpkg -l | awk '/^ii/ {print $2}')
    for pkg in $pkg_list; do
        # 使用 debsums 检查（静默模式，只输出错误）
        local errors=$(debsums -s "$pkg" 2>/dev/null)
        if [ -n "$errors" ]; then
            problems+=("$pkg|apt|文件缺失或损坏")
        fi
    done
    printf '%s\n' "${problems[@]}"
}

# 检查 Snap 包（简单检查：能否执行 --version）
_fix_check_snap() {
    local problems=()
    if command -v snap >/dev/null 2>&1; then
        local snap_list=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')
        for snap in $snap_list; do
            # 检查是否可执行（运行 --version）
            if ! timeout 2 snap run "$snap" --version >/dev/null 2>&1; then
                problems+=("$snap|snap|无法正常运行")
            fi
        done
    fi
    printf '%s\n' "${problems[@]}"
}

# 检查系统服务（仅检查是否为 active）
_fix_check_services() {
    local problems=()
    local services=$(systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null | awk '{print $1}')
    for svc in $services; do
        local active=$(systemctl is-active "$svc" 2>/dev/null)
        if [ "$active" != "active" ]; then
            # 排除一些已知的静态服务（如 systemd-* 可能不会 active）
            if [[ "$svc" != systemd-* ]] && [[ "$svc" != *-setup ]] && [[ "$svc" != *-cleanup ]]; then
                problems+=("$svc|service|状态为 $active")
            fi
        fi
    done
    printf '%s\n' "${problems[@]}"
}
_fix_action_apt() {
    local pkg="$1"
    local action="$2"
    case "$action" in
        "修复")
            # 检查本地是否有备份？这里简化：尝试重新安装
            echo "尝试重新安装 $pkg ..."
            sudo apt install --reinstall -y "$pkg"
            ;;
        "删除")
            echo "卸载 $pkg ..."
            sudo apt remove -y "$pkg"
            ;;
        "重装")
            echo "完全卸载并重新安装 $pkg ..."
            sudo apt remove -y "$pkg" && sudo apt install -y "$pkg"
            ;;
        *)
            echo "未知操作"
            ;;
    esac
}

_fix_action_snap() {
    local snap="$1"
    local action="$2"
    case "$action" in
        "修复")
            echo "尝试重新安装 snap $snap ..."
            sudo snap refresh "$snap" --reinstall
            ;;
        "删除")
            echo "删除 snap $snap ..."
            sudo snap remove "$snap"
            ;;
        "重装")
            echo "完全卸载并重新安装 snap $snap ..."
            sudo snap remove "$snap" && sudo snap install "$snap"
            ;;
        *)
            echo "未知操作"
            ;;
    esac
}

_fix_action_service() {
    local svc="$1"
    local action="$2"
    case "$action" in
        "修复")
            echo "尝试重启服务 $svc ..."
            sudo systemctl restart "$svc"
            ;;
        "删除")
            echo "停止并禁用服务 $svc ..."
            sudo systemctl stop "$svc"
            sudo systemctl disable "$svc"
            ;;
        "重装")
            echo "重装服务 $svc（通常需要重装对应的软件包）"
            echo "请手动重装该服务对应的软件包，或使用 'fix <包名>' 处理"
            ;;
        *)
            echo "未知操作"
            ;;
    esac
}
command_fix() {
    local target="$1"

    # 确保依赖
    _fix_ensure_deps

    if [ -n "$target" ]; then
        # 指定组件名（简化：先检测是 APT 还是 snap 还是 service）
        echo "正在检查组件: $target ..."
        local problems=()
        # APT 检查
        if dpkg -l "$target" 2>/dev/null | grep -q "^ii"; then
            local errors=$(debsums -s "$target" 2>/dev/null)
            if [ -n "$errors" ]; then
                problems+=("$target|apt|文件缺失或损坏")
            fi
        fi
        # Snap 检查
        if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "^$target "; then
            if ! timeout 2 snap run "$target" --version >/dev/null 2>&1; then
                problems+=("$target|snap|无法正常运行")
            fi
        fi
        # Service 检查
        if systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -q "^$target.service"; then
            local active=$(systemctl is-active "$target" 2>/dev/null)
            if [ "$active" != "active" ]; then
                problems+=("$target|service|状态为 $active")
            fi
        fi

        if [ ${#problems[@]} -eq 0 ]; then
            echo "组件 $target 正常"
            return 0
        fi

        # 显示问题并让用户选择
        echo "组件 $target 存在问题:"
        for prob in "${problems[@]}"; do
            IFS='|' read -r name type detail <<< "$prob"
            echo "  类型: $type, 问题: $detail"
        done
        echo "请选择操作:"
        echo "  1) 修复"
        echo "  2) 删除"
        echo "  3) 重装"
        echo "  4) 忽略"
        echo -n "请输入选项 [1-4]: "
        read -r choice
        case "$choice" in
            1) action="修复" ;;
            2) action="删除" ;;
            3) action="重装" ;;
            4) echo "已忽略"; return 0 ;;
            *) echo "无效选择"; return 1 ;;
        esac
        # 根据类型执行
        local type=$(echo "${problems[0]}" | cut -d'|' -f2)
        case "$type" in
            apt) _fix_action_apt "$target" "$action" ;;
            snap) _fix_action_snap "$target" "$action" ;;
            service) _fix_action_service "$target" "$action" ;;
        esac
        return 0
    fi

    # 无参数：全面检查
    echo "正在扫描所有组件（APT包、Snap包、系统服务），请稍候..."
    local all_problems=()

    echo "检查 APT 包..."
    mapfile -t apt_problems < <(_fix_check_apt)
    all_problems+=("${apt_problems[@]}")

    echo "检查 Snap 包..."
    mapfile -t snap_problems < <(_fix_check_snap)
    all_problems+=("${snap_problems[@]}")

    echo "检查系统服务..."
    mapfile -t svc_problems < <(_fix_check_services)
    all_problems+=("${svc_problems[@]}")

    if [ ${#all_problems[@]} -eq 0 ]; then
        echo "所有组件均正常"
        return 0
    fi

    # 显示菜单
    echo ""
    echo "发现以下问题组件："
    echo "编号   名称                     类型      问题描述"
    echo "------ ------------------------- ---------- ----------"
    local idx=1
    declare -a menu_items
    for prob in "${all_problems[@]}"; do
        IFS='|' read -r name type detail <<< "$prob"
        printf "%-6s %-25s %-10s %s\n" "$idx" "$name" "$type" "$detail"
        menu_items[$idx]="$prob"
        ((idx++))
    done

    echo ""
    echo -n "请选择要处理的组件编号（多个用空格分隔），或输入 'all' 处理全部，按回车退出: "
    read -r selection
    if [ -z "$selection" ]; then
        echo "未选择任何操作"
        return 0
    fi

    if [ "$selection" = "all" ]; then
        selection=$(seq 1 ${#all_problems[@]} | tr '\n' ' ')
    fi

    for sel in $selection; do
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt ${#all_problems[@]} ]; then
            echo "无效编号: $sel"
            continue
        fi
        local prob="${menu_items[$sel]}"
        IFS='|' read -r name type detail <<< "$prob"
        echo ""
        echo "--- 处理: $name ($type) ---"
        echo "问题: $detail"
        echo "请选择操作:"
        echo "  1) 修复"
        echo "  2) 删除"
        echo "  3) 重装"
        echo "  4) 忽略"
        echo -n "请输入选项 [1-4]: "
        read -r choice
        case "$choice" in
            1) action="修复" ;;
            2) action="删除" ;;
            3) action="重装" ;;
            4) echo "已忽略 $name"; continue ;;
            *) echo "无效选择，跳过"; continue ;;
        esac
        case "$type" in
            apt) _fix_action_apt "$name" "$action" ;;
            snap) _fix_action_snap "$name" "$action" ;;
            service) _fix_action_service "$name" "$action" ;;
        esac
    done
    echo "处理完成。"
}

# ------------------- 简介与帮助命令 -------------------
command_UCST() {
    echo "Ubuntu Command Simplification Tool——Ubuntu命令简化工具"
    echo "此工具的开发皆在于简化Ubuntu命令使用户在更便捷的环境下完成工作"
    echo "请注意，此工具在使用过程中会产生大量下载内容（安装必须的依赖），请尽量保持互联网连接"
    echo "开发者：哈西力工"
    echo "Github存储库地址：https://github.com/HXLG-F/Ubuntu-Command-Simplification-Tool"
    echo "访问存储库以获取最新内容"
    echo "输入helpUCST获得可用命令帮助"
    echo "祝您工作顺利！"
}

command_helpUCST() {
    echo "=== 可用命令 ==="
    echo "UCST        -简介信息"
    echo "about       -查看基本信息"
    echo "about -a    -查看详细信息"
    echo "about -c    -查看处理器信息"
    echo "about -g    -查看显卡信息"
    echo "about -o    -查看操作系统信息"
    echo "about -s    -查看用户信息"
    echo "list        -查看文件列表（可能无效，建议使用ls）"
    echo "delete      -删除文件或目录"
    echo "network -i  -查看网络信息"
    echo "network -c  -查看网卡信息"
    echo "disk        -查看或挂载磁盘"
    echo "ctime       -查看时间信息"
    echo "process     -查看进程"
    echo "helpUCST    -查看帮助信息"
    echo "nkill       -修改进程活动状态"
    echo "open        -打开文件"
    echo "new         -新建目录或文件"
    echo "mod         -修改文件或目录属性"
    echo "driver      -查看与修改驱动程序"
    echo "backup      -文件备份与恢复"
    echo "check       -文件编码检查"
    echo "download    -网络资源下载"
    echo "search      -搜索文件"
    echo "account     -登录账户(coludai)"
    echo "sai         -启动SAI-Coder模型"
    echo "amend       -以文本形式打开文件"
    echo "language    -设置或下载语言包"
    echo "restart     -重载工具链接符号"
    echo "service     -查看/修改服务状态"
    echo "update      -更新组件"
    echo "translate   -启用/禁用报错翻译"
    echo "sshre       -SSH紧急救援工具"
    echo "fix         -检查并修复组件"
}
case "$CMD" in
    "about")
        command_about
        ;;
    "list")
        command_list
        ;;
    "network")
        command_network
        ;;
    "disk")
        command_disk
        ;;
    "ctime")
        command_ctime
        ;;
    "process")
        command_process
        ;;
    "nkill")
        command_nkill
        ;;
    "open")
        command_open
        ;;
    "delete")
        command_delete
        ;;
    "helpUCST") 
        command_helpUCST
        ;;
    "new")
        command_new
        ;;
    "mod")
        command_mod
        ;;
    "driver")
        command_driver
        ;;
    "backup")
        command_backup
        ;;
    "check")
        command_check
        ;;
    "UCST")
        command_UCST
        ;;
    "download")
        command_download
        ;;
    "search")
        command_search
        ;;
    "account")
        command_account $ARGS 
        ;;
    "sai")
        command_sai
        ;;
    "amend")
        command_amend
        ;;
    "language")
        command_language
        ;;
    "restart")
        command_restart
        ;;
    "service")
        command_service "$1" "$2"
        ;;
    "update")
        command_update "$1" "$2"
        ;;
    "translate")
        command_translate
        ;;
    "sshre")
        command_ssh_r
        ;;
    "fix")
        command_fix "$1"
        ;;
    "")
        echo "Ubuntu Command Simplification Tool——Ubuntu命令简化工具"
        echo "输入 'helpUCST' 查看可用命令" 
        ;;
    *)
        echo "错误: 未知命令 '$CMD'"
        echo "输入 'helpUCST' 查看可用命令"
        exit 1
        ;;
esac






















































##         ##   ####         ####   ####                  ########
##         ##   ####         ####   ####                 ##########
##         ##    ####       ####    ####                ##
##         ##      ####    ####     ####               ##
#############        ########       ####              ##
#############        ########       ####              ##      ######   
##         ##      ####    ####     ####               ##          #
##         ##    ####        ####   ####                ##         #
##         ##  ####           ####  ################     ##########
##         ##  ####           ####  ################      ########
#哈西力工防伪标识
#别乱搬运，谢谢
#正在尝试申请国家发明专利？（可行，申请工作正在进行，那当然我也不知道成不成）