#!/bin/bash 
# this program is control Apache virtual host server
# Date:2018-06-23
# Version:1.0
# Author: jiang zhi gang

# 全局变量
ConfRootDir=""
AddVirtalConfFile(){
	# 匹配行 取第二个 删除引号
	ConfRoot=`awk '/^ServerRoot/' /etc/httpd/conf/httpd.conf| awk '{print $2}'| sed 's/"//g'`
	ConfDir=`awk '/^IncludeOptional/' /etc/httpd/conf/httpd.conf | awk '{print $2}'| awk -F"/" '{print $1}'`
    Virtual="virtual.conf"
    VirtalConfFile="$ConfRoot/$ConfDir/$Virtual"
    
    echo "Virtal Host Conf File is virtual.conf Located In $ConfRoot/$ConfDir"
    PrintLine
    # 查询是否存在虚拟机配置文件
    if [ ! -f "$VirtalConfFile" ]
    then
    	echo "No $Virtual File, Will Creat It!"
  		touch "$VirtalConfFile"
	fi
}
PrintLine(){
	echo "--------------------------------------------------------------------"
}

# 显示配置文件中的虚拟主机
ExistingVirtualHost(){
	printf "The virtual Host That Exists In The Conf file: \n\n"
	# \s空格 任意空格开头+ServerName 的行 ServerName结果集
	Existing=`awk '/^\s*ServerName/' $VirtalConfFile `
	if [ -z "$Existing" ]
	then
		echo "Conf File Is Empty!"
		PrintLine
		return 0
	else
		# 输出匹配的当前行和下一行
		awk '/^\s*ServerName/{printf ""$0"\n";getline;printf ""$0"\n\n";}' $VirtalConfFile 
		PrintLine
		return 1
	fi
	
	
}

ApacheStatus(){
	PrintLine
	echo "Show Virtual Host And Apache Status , Firewall Status:"
	AddVirtalConfFile
	ExistingVirtualHost
	#显示apache相关配置信息
	echo "Apache Status:"
	systemctl status httpd |grep  Active
	
	# Net Stat
	REQUEST_NUM=`systemctl status httpd | grep Status | awk '{print $4}'| sed 's/;//'`
	echo "Request Number: $REQUEST_NUM"
	NETSTAT=`netstat -tunpl | grep httpd`
	printf "Net Stat: \n $NETSTAT\n"
	PrintLine
	
	# 显示Firewall相关配置信息
	echo "Firewall Status:"
	systemctl status firewalld |grep  Active
	
	DefaultZone=`firewall-cmd --get-default-zone`
	FirewallServices=`firewall-cmd --zone=$ActiveZones --list-all | grep services |awk -F":" '{print $2}'`
	echo "Default Zone:$DefaultZone"
	echo "Services:$FirewallServices"
}

AddVirtual(){
	PrintLine
	echo "Add Virtual Host:"
	AddVirtalConfFile
	NameVirtualHost=`awk '/^NameVirtualHost/' /etc/httpd/conf/httpd.conf| awk '{print $2}'`
	
	# 允许本机所有80端口网络通过 基于域名的虚拟主机
	if [ "$NameVirtualHost" != "*:80" ]
	then
		echo "Add NameVirtualHost *:80 >> /etc/httpd/conf/httpd.conf"
		echo "NameVirtualHost *:80" >> /etc/httpd/conf/httpd.conf
	fi
	
	ExistingVirtualHost $VirtalConfFile

	
	read -p "Please input ServerName( www.example.com ):" ServerName
	# 输入ServerName是否为空
	if [ -z $ServerName ]
	then
		echo "Please Input ServerName"
	else
		read -p "Please input DocumentRoot( /var/www/html/ ):" DocumentRoot
		
		# 输入DocumentRoot是否为空
		if [ -z $DocumentRoot ]
		then
			echo "Please Input DocumentRoot"
		else
# 写配置文件
(
cat <<EOF
# ShellCript Creat ServerName $ServerName Begin
<VirtualHost *:80>
  ServerName $ServerName
  DocumentRoot $DocumentRoot
</VirtualHost>
# ShellCript Creat ServerName $ServerName End
EOF
) >> $VirtalConfFile
# 写配置文件
			PrintLine
			echo "Add Succeed!"
			cat $VirtalConfFile
			echo "restart httpd..."
			systemctl restart httpd
		fi
	fi
} 

RemoveVirtual(){
	PrintLine
	echo "Remove Virtual Host:"
	AddVirtalConfFile
	ExistingVirtualHost $VirtalConfFile
	# 配置文件是否为空
	if [ $? == "0" ]
	then
		echo "No Virtual Host Can Be Removed!"
	else
		read -p "Please Select ServerName Remove It:" ServerName
		result=`cat $VirtalConfFile | grep "# ShellCript Creat ServerName $ServerName Begin"`
		
		# 输入是否为空
		if [ -z $ServerName ]
		then
			echo "Please Input ServerName"
		# 输入查询结果是否为空
		elif [ -z "$result" ]
		then
			echo "Please Input Existing ServerName"
		# 输入正确
		else
			sed -i "/# ShellCript Creat ServerName $ServerName Begin/,/# ShellCript Creat ServerName $ServerName End/d" $VirtalConfFile		
			PrintLine
			echo "Remove Succeed!"
			cat $VirtalConfFile
			echo "restart httpd..."
			systemctl restart httpd
		fi
	fi
}

ModifyVirtual(){
	PrintLine
	echo "Modify Virtual Host:"
	AddVirtalConfFile
	ExistingVirtualHost $VirtalConfFile
	# 配置文件是否为空
	if [ $? == "0" ]
	then
		echo "No Virtual Host Can Be Modify !"
	else
		read -p "Please Select ServerName Modify It:" ServerName
		result=`cat $VirtalConfFile | grep "# ShellCript Creat ServerName $ServerName Begin"`
		
		# 输入是否为空
		if [ -z "$ServerName" ]
		then
			echo "Please Input ServerName"
		# 输入查询结果是否为空
		elif [ -z "$result" ]
		then
			echo "Please Input Existing ServerName"
		# 输入正确
		else
			# 显示要修改的内容
			sed -n "/# ShellCript Creat ServerName $ServerName Begin/,/# ShellCript Creat ServerName $ServerName End/p" $VirtalConfFile
			PrintLine

			
			printf "What to Modify ? \n"
			MENU "1" "ServerName:"
			MENU "2" "DocumentRoot:"
			MENU "3" "Back:"

			read -p "please select a function(1-3):" U_SELECT
			case $U_SELECT in
			1)
				read -p "Please Input New ServerName:" NewServerName
				if [ -z "$NewServerName" ]
				then
					echo "Please Input NewServerName!"
				else
					sed -i "s/ServerName $ServerName/ServerName $NewServerName/g" $VirtalConfFile
					PrintLine
					echo "Modify ServerName Succeed!"
					cat $VirtalConfFile
					echo "restart httpd..."
					systemctl restart httpd
				fi
				;;
			2)
				read -p "Please Input New DocumentRoot:" NewDocumentRoot
				if [ -z "$NewDocumentRoot" ]
				then
					echo "Please Input NewDocumentRoot!"
				else
					# sed 中有/ 需要添加转义字符\ 
					NewDocumentRoot=$(echo $NewDocumentRoot | sed 's/\//\\\//g')
					# echo $NewDocumentRoot 
					sed -i "/^\s*ServerName $ServerName/{n;s/DocumentRoot.*/DocumentRoot $NewDocumentRoot/;}" $VirtalConfFile
					PrintLine
					echo "Modify DocumentRoot Succeed!"
					cat $VirtalConfFile
					echo "restart httpd..."
					systemctl restart httpd
				fi
				;;
			3)
				echo "Back..."
				;;

			*)
			echo "Please Select 1-3"
			;;
			esac
			
			
		fi
	fi
}

# 关闭Selinux 打开Firewalld
CloseSeOpenFw(){
	SeStatus=`getenforce`
	echo "Selinux Status:$SeStatus"
	
	if [ $SeStatus != "Disabled" ] 
	then 
		read -p "Do You Want To Close Selinux? Y/N(suggest closing it): " Close
		if [ $Close == "y" && $Close == "Y"]
		then
			sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
			sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
			# 临时关闭SELinux
			setenforce 0
			echo "Close Selinux Succeed!"
		else
			echo "Selinux is $SeStatus Do't Close It!"
		fi	
	fi
	
	FWStatus=`firewall-cmd --stat`
	echo "Firewalld Status:$FWStatus"

	if [ $FWStatus != "running" ] 
	then 
		read -p "Do You Want To Open Firewalld? Y/N(suggest open it): " Close
		if [ $Close == "y" && $Close == "Y"]
		then
		  echo "restart firewalld..."
			systemctl restart firewalld
			echo "Open Firewalld Succeed!"
			return 1
		else
			echo "Selinux is $FWStatus Do't Open It!"
			return 0
		fi	
	fi
	return 1
}
Addhttp(){
	CloseSeOpenFw
	if [ $? == "0" ]
	then
		echo "Please Open Firewalld !"
	else
		DefaultZone=`firewall-cmd --get-default-zone`
		FirewallServices=`firewall-cmd --zone=$ActiveZones --list-all | grep services |awk -F":" '{print $2}'`
		echo "Default Zone:$DefaultZone"
		echo "Services:$FirewallServices"
		Result=`echo $FirewallServices | awk /http/ `
		if [ -z "$Result" ]
		then
			echo "Add Http Service:"
			firewall-cmd --zone="$DefaultZone" --add-service=http --permanent
	  		firewall-cmd --zone="$DefaultZone" --add-service=http
	  	else
	  		echo "Http Services Already Exist In $DefaultZone Zone"
	  	fi
  	fi

}

Removehttp(){
	CloseSeOpenFw
	if [ $? == "0" ]
	then
		echo "Please Open Firewalld !"
	else
		DefaultZone=`firewall-cmd --get-default-zone`
		FirewallServices=`firewall-cmd --zone=$ActiveZones --list-all | grep services |awk -F":" '{print $2}'`
		echo "DefaultZone:$DefaultZone"
		echo "Services:$FirewallServices"
		Result=`echo $FirewallServices | awk /http/ `
		if [ -z "$Result" ]
		then
			echo "Http Services NO Already Exist In $DefaultZone Zone"
	  	else
	  		echo "Remove Http Service:"
	  		firewall-cmd --zone="$DefaultZone" --remove-service=http --permanent
	  		firewall-cmd --zone="$DefaultZone" --remove-service=http
	  		
	  	fi

		
  	fi    
}

HINT(){
	read -p "Press Enter to continue:"
} 

MENU(){
    if [ $1 == "1" ]
    then
    printf "+----------------------------------------+\n"
    fi
    printf "|%2s. %-35s |\n" "$1" "$2"
    printf "+----------------------------------------+\n"
}
 
while true
do
clear
printf "   Control Apache virtual Host Server\n"
MENU "1" "Apache And Firewalld Status:"
MENU "2" "Add Virtual Host:"
MENU "3" "Remove Virtual Host:"
MENU "4" "Modify Virtual Host:"
MENU "5" "Open Firewalld --> Add http:"
MENU "6" "Open Firewalld --> Remove http:"
MENU "7" "Exit Script:"

read -p "please select a function(1-7):" U_SELECT
case $U_SELECT in
	1)
ApacheStatus
HINT
;;
	2)
AddVirtual
HINT
;;
	3)
RemoveVirtual
HINT
;;
	4)
ModifyVirtual
HINT
;;
	5)
Addhttp
HINT
;;
	6)
Removehttp
HINT
;;
	7)
exit
;;
	*)
read -p "Please Select 1-7,Press Enter to continue:"
esac
done

