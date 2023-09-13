#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export LANG=en_US.UTF-8
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
bblue(){ echo -e "\033[34m\033[01m$1\033[0m";}
rred(){ echo -e "\033[35m\033[01m$1\033[0m";}
readtp(){ read -t5 -n26 -p "$(yellow "$1")" $2;}
readp(){ read -p "$(yellow "$1")" $2;}





[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit 1
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red " 不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统"
exit 1
fi

[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ $(type -P kmod) ]] || $yumapt install kmod
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1 }'`
minor=`uname -r | awk -F . '{print $2}'`
uname -m | grep -q -E -i "aarch" && cpu=ARM64 || cpu=AMD64
vi=`systemd-detect-virt`
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="openvz版bbr-plus"
else
bbr="暂不支持显示"
fi
v46=`curl -s api64.ipify.org -k`
if [[ $v46 =~ '.' ]]; then
ip="$v46（IPV4优先）" 
else
ip="$v46（IPV6优先）"
fi


get_char(){
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}

back(){
white "------------------------------------------------------------------------------------------------"
white " 回主菜单，请按任意键"
white " 退出脚本，请按Ctrl+C"
get_char && bash <(curl -sSL https://gitlab.com/rwkgyg/ygkkktools/raw/main/tools.sh)
}

root(){
bash <(curl -L -s https://gitlab.com/rwkgyg/vpsroot/raw/main/root.sh)
back
}
opport(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
green "关闭VPS防火墙、开放端口规则执行完毕"
back
}

bbr(){
if [[ $vi = lxc ]]; then
red "VPS虚拟化类型为lxc，目前不支持安装各类加速（自带集成BBR除外） "
elif [[ $vi = openvz ]]; then
[[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]] && green "openvz版bbr-plus已在运行中" && back
green "VPS虚拟化类型为openvz，支持lkl-haproxy版的BBR-PLUS加速" && sleep 2
wget --no-cache -O lkl-haproxy.sh https://github.com/mzz2017/lkl-haproxy/raw/master/lkl-haproxy.sh && bash lkl-haproxy.sh
elif [[ ! $vi =~ lxc|openvz ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
if [[ $bbr != bbr ]]; then
yellow "当前TCP拥塞控制算法：$bbr，BBR+FQ加速未开启" && sleep 1
yellow "尝试安装BBR+FQ加速……" && sleep 2
bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
[[ -n $(lsmod | grep bbr) ]] && green "安装结束，已开启BBR+FQ加速"
else
green "当前TCP拥塞控制算法：$bbr，BBR+FQ加速已开启" 
fi
fi
back
}

v4v6(){
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
ab="1.设置IPV4优先\n2.设置IPV6优先\n3.恢复系统默认优先\n0.返回上一层\n 请选择："
readp "$ab" cd
case "$cd" in 
1 )
[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
sed -i '/^label 2002::\/16   2/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
2 )
[[ -e /etc/gai.conf ]] && grep -qE '^ *label 2002::/16   2' /etc/gai.conf || echo 'label 2002::/16   2' >> /etc/gai.conf
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
3 )
sed -i '/^precedence ::ffff:0:0\/96  100/d;/^label 2002::\/16   2/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
0 ) 
bash <(curl -sSL https://gitlab.com/rwkgyg/ygkkktools/raw/main/tools.sh)
esac
}

acme(){
bash <(curl -sSL https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
back
}

screen(){
bash <(curl -sSL https://cdn.jsdelivr.net/gh/kkkyg/screen-script/screen.sh)
back
}

warp(){
wget -N --no-check-certificate https://gitlab.com/rwkgyg/cfwarp/raw/main/CFwarp.sh && bash CFwarp.sh
back
}

start_menu(){
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██   ░██     ░██   ░██     ░██${plain}   ░██    ░██     ░██      ░██ ██ ${red}██${plain} "
echo -e "${bblue} ░██  ░██      ░██  ░██${plain}      ░██  ░██      ░██   ░██      ░██    ${red}░░██${plain} "            
echo -e "${bblue} ░██ ██        ░██${plain} ██        ░██ ██         ░██ ░██      ░${red}██        ${plain} "
echo -e "${bblue} ░██ ██       ${plain} ░██ ██        ░██ ██           ░██        ${red}░██    ░██ ██${plain} "
echo -e "${bblue} ░██ ░${plain}██       ░██ ░██       ░██ ░██          ░${red}██         ░██    ░░██${plain}"
echo -e "${bblue} ░${plain}██  ░░██     ░██  ░░██     ░██  ░░${red}██        ░██          ░██ ██ ██${plain} "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white " VPS系统信息如下："
white " 操作系统      : $(blue "$op")" 
white " 内核版本      : $(blue "$version")" 
white " CPU架构       : $(blue "$cpu")" 
white " 虚拟化类型    : $(blue "$vi")" 
white " TCP加速算法   : $(blue "$bbr")" 
white " 本地IP优先级  : $(blue "$ip")"                             
white " ==================一、VPS相关调整选择（更新中）=========================================="
green "  1. VPS一键root脚本、更改root密码 "
green "  2. 关闭VPS防火墙、开放端口规则"      
green "  3. 开启BBR加速(BBR+FQ)、openvz(BBR-PLUS)"      
green "  4. 更改VPS本地IP优先级"
green "  5. 一键ACME申请证书脚本"
green "  6. WARP脚本"
green "  0. 退出脚本 "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
readp "请输入数字:" Input
case "$Input" in     
 1 ) root;;
 2 ) opport;;
 3 ) bbr;;
 4 ) v4v6;;
 5 ) acme;; 
 6 ) warp;;
 7 ) screen;;
 8 ) warp;;	
 9 ) WARPOC;;
 * ) exit 0
esac
}
start_menu "first"
