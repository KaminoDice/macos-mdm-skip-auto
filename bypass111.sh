#!/bin/bash

# Global constants
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD"
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data"

# Text formating
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Checks if a volume with the given name exists
checkVolumeExistence() {
	local volumeLabel="$*"
	diskutil info "$volumeLabel" >/dev/null 2>&1
}

# Returns the name of a volume with the given type
getVolumeName() {
	local volumeType="$1"

	# Getting the APFS Container Disk Identifier
	apfsContainer=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
	# Getting the Volume Information
	volumeInfo=$(diskutil ap list "$apfsContainer" | grep -A 5 "($volumeType)")
	# Extracting the Volume Name from the Volume Information
	volumeNameLine=$(echo "$volumeInfo" | grep 'Name:')
	# Removing unnecessary characters to get the clean Volume Name
	volumeName=$(echo "$volumeNameLine" | cut -d':' -f2 | cut -d'(' -f1 | xargs)

	echo "$volumeName"
}

# Defines the path to a volume with the given default name and volume type
defineVolumePath() {
	local defaultVolume=$1
	local volumeType=$2

	if checkVolumeExistence "$defaultVolume"; then
		echo "/Volumes/$defaultVolume"
	else
		local volumeName
		volumeName="$(getVolumeName "$volumeType")"
		echo "/Volumes/$volumeName"
	fi
}

# Mounts a volume at the given path
mountVolume() {
	local volumePath=$1

	if [ ! -d "$volumePath" ]; then
		diskutil mount "$volumePath"
	fi
}

echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo -e "${YELLOW}* MacOS Skip MDM Auto Program  *${NC}"
echo -e "${RED}*             modified by sky                 *${NC}"
echo -e "${RED}*            forked from Phoenix Team                 *${NC}"
echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo ""

PS3='请键入选项前的数字并回车以继续: '
options=("自动绕过" "查询监管状态" "重启" "退出")

select opt in "${options[@]}"; do
	case $opt in
	"自动绕过")
		echo -e "\n\t${GREEN}自动绕过程序已启动${NC}\n"

		# Mount Volumes
		echo -e "${BLUE}挂载磁盘中…${NC}"
		# Mount System Volume
		systemVolumePath=$(defineVolumePath "$DEFAULT_SYSTEM_VOLUME" "System")
		mountVolume "$systemVolumePath"

		# Mount Data Volume
		dataVolumePath=$(defineVolumePath "$DEFAULT_DATA_VOLUME" "Data")
		mountVolume "$dataVolumePath"

		echo -e "${GREEN}磁盘已成功挂载${NC}\n"

		# Create User
		echo -e "${BLUE}查看用户目录中${NC}"
		dscl_path="$dataVolumePath/private/var/db/dslocal/nodes/Default"
		localUserDirPath="/Local/Default/Users"
		defaultUID="501"
		if ! dscl -f "$dscl_path" localhost -list "$localUserDirPath" UniqueID | grep -q "\<$defaultUID\>"; then
			echo -e "${CYAN}创建新用户${NC}"
			echo -e "${CYAN}按一下回车以继续，请注意：留空会自动创建一个默认账户！${NC}"
			echo -e "${CYAN}输入一个用户名，请注意：请键入全英文并不包含特殊字符以及空格！(默认: MacBook)${NC}"
			read -rp "Full name: " fullName
			fullName="${fullName:=MacBook}"

			echo -e "${CYAN}请注意：请键入全英文并不包含特殊字符以及空格！${NC}"
			read -rp "Username: " username
			username="${username:=MacBook}"

			echo -e "${CYAN}输入密码 (默认: 123456)${NC}"
			read -rsp "Password: " userPassword
			userPassword="${userPassword:=123456}"

			echo -e "\n${BLUE}创建用户中…${NC}"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UserShell "/bin/zsh"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" RealName "$fullName"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UniqueID "$defaultUID"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" PrimaryGroupID "20"
			mkdir "$dataVolumePath/Users/$username"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" NFSHomeDirectory "/Users/$username"
			dscl -f "$dscl_path" localhost -passwd "$localUserDirPath/$username" "$userPassword"
			dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
			echo -e "${GREEN}账户已成功创建！！！${NC}\n"
		else
			echo -e "${BLUE}账户已存在！！！${NC}\n"
		fi

		# Block MDM hosts
		echo -e "${BLUE}屏蔽域名中…${NC}"
		hostsPath="$systemVolumePath/etc/hosts"
		blockedDomains=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
		for domain in "${blockedDomains[@]}"; do
			echo "0.0.0.0 $domain" >>"$hostsPath"
		done
		echo -e "${GREEN}域名已成功屏蔽！！！${NC}\n"

		# Remove config profiles
		echo -e "${BLUE}移除监管配置文件中…${NC}"
		configProfilesSettingsPath="$systemVolumePath/var/db/ConfigurationProfiles/Settings"
		touch "$dataVolumePath/private/var/db/.AppleSetupDone"
		rm -rf "$configProfilesSettingsPath/.cloudConfigHasActivationRecord"
		rm -rf "$configProfilesSettingsPath/.cloudConfigRecordFound"
		touch "$configProfilesSettingsPath/.cloudConfigProfileInstalled"
		touch "$configProfilesSettingsPath/.cloudConfigRecordNotFound"
		echo -e "${GREEN}监管配置文件已成功移除！！！${NC}\n"

		echo -e "${GREEN}------ 自动监管绕过程序执行成功！！！ ------${NC}"
		echo -e "${CYAN}------ ———键盘输入reboot后按一下回车即可重启电脑！！！${NC}"
		break
		;;

	"查询监管状态")
		if [ ! -f /usr/bin/profiles ]; then
			echo -e "\n\t${RED}不要在恢复模式中使用该选项！！！${NC}\n"
			continue
		fi

		if ! sudo profiles show -type enrollment >/dev/null 2>&1; then
			echo -e "\n\t${GREEN}查询成功！！！${NC}\n"
		else
			echo -e "\n\t${RED}查询失败！！！${NC}\n"
		fi
		;;

	"重启")
		echo -e "\n\t${BLUE}重启中…${NC}\n"
		reboot
		;;

	"退出")
		echo -e "\n\t${BLUE}退出中…${NC}\n"
		exit
		;;

	*)
		echo "Invalid option $REPLY"
		;;
	esac
done