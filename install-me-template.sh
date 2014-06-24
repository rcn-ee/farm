#!/bin/sh -e
#
# Copyright (c) 2013-2014 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

#enable for debug
#debug=1

arch=$(uname -m)

release="release_VAR"
dpkg_arch="dpkg_arch_VAR"
version="version_VAR"

mirror="https://rcn-ee.net/deb"

use_mirror="disabled"
if [ "x${use_mirror}" = "xenabled" ] ; then
	mirror="http://rcn-ee.homeip.net:81/dl/mirrors/deb"
fi

system_checks () {
	if ! [ $(id -u) = 0 ] ; then
		echo ""
		echo "Error: this script: [$0] must be run as sudo user or root"
		echo "-----------------------------"
		exit
	fi

	#if [ "x${arch}" != "xx86_64" ] ; then
	if [ "x${arch}" != "xarmv7l" ] ; then
		echo ""
		echo "Error: this script: [$0] is not supported to run under [${arch}]"
		echo "-----------------------------"
		exit
	fi

	unset command_check
	command_check=$(which mkimage 2>/dev/null)
	if [ "${command_check}" ] ; then
		has_mkimage=1
		if [ "${debug}" ] ; then
			echo "Debug: system has mkimage"
		fi
	fi

	unset command_check
	command_check=$(which update-initramfs 2>/dev/null)
	if [ "${command_check}" ] ; then
		if [ "${debug}" ] ; then
			echo "Debug: system has update-initramfs"
		fi
	else
		apt-get install -y initramfs-tools
	fi

	unset third_party_modules
	if [ -f /etc/rcn-ee.conf ] ; then
		. /etc/rcn-ee.conf
		if [ "${debug}" ] ; then
			echo "Debug: third party modules : [${third_party_modules}]"
		fi
	fi
}

get_html_file_list () {
	mkdir -p /tmp/deb/
	if [ -f /tmp/deb/index.html ] ; then
		rm -rf /tmp/deb/index.html || true
	fi
	wget --no-verbose --directory-prefix=/tmp/deb/ ${mirror}/${release}-${dpkg_arch}/${version}/

	cat /tmp/deb/index.html | grep "<a href=" > /tmp/deb/temp.html
	sed -i -e "s/<a href/\\n<a href/g" /tmp/deb/temp.html
	sed -i -e 's/\"/\"><\/a>\n/2' /tmp/deb/temp.html
	cat /tmp/deb/temp.html | grep href > /tmp/deb/index.html
}

parse_index_html () {
	unset deb_file
	deb_file=$(cat /tmp/deb/index.html | grep linux-image)
	deb_file=$(echo ${deb_file} | awk -F ".deb" '{print $1}')
	deb_file=${deb_file##*linux-image-}

	unset kernel_version
	if [ "${deb_file}" ] ; then
		kernel_version=$(echo ${deb_file} | awk -F "_" '{print $1}')
		if [ "${debug}" ] ; then
			echo "Debug: kernel version [${kernel_version}]"
		fi
		deb_file="linux-image-${deb_file}.deb"
	fi

	unset dtb_file
	dtb_file=$(cat /tmp/deb/index.html | grep dtbs.tar.gz | head -n 1)
	dtb_file=$(echo ${dtb_file} | awk -F "\"" '{print $2}')

	unset thirdparty_file
	thirdparty_file=$(cat /tmp/deb/index.html | grep thirdparty | head -n 1)
	thirdparty_file=$(echo ${thirdparty_file} | awk -F "\"" '{print $2}')
}

dl_files () {
	if [ "${deb_file}" ] ; then
		if [ -f /tmp/deb/${deb_file} ] ; then
			rm -rf /tmp/deb/${deb_file} || true
		fi
		wget --directory-prefix=/tmp/deb/ ${mirror}/${release}-${dpkg_arch}/${version}/${deb_file}
	fi

	if [ "${dtb_file}" ] ; then
		if [ -f /tmp/deb/${dtb_file} ] ; then
			rm -rf /tmp/deb/${dtb_file} || true
		fi
		wget --directory-prefix=/tmp/deb/ ${mirror}/${release}-${dpkg_arch}/${version}/${dtb_file}
	fi
}

install_third_party () {
	if [ "${thirdparty_file}" ] ; then
		if [ -f /tmp/deb/${thirdparty_file} ] ; then
			rm -rf /tmp/deb/${thirdparty_file} || true
		fi
		wget --directory-prefix=/tmp/deb/ ${mirror}/${release}-${dpkg_arch}/${version}/${thirdparty_file}
		if [ -f /tmp/deb/thirdparty ] ; then
			sudo /bin/sh /tmp/deb/thirdparty
			sudo depmod ${kernel_version} -a
		fi
	fi
}

install_boot_files () {
	if [ -f "${bootdir}/SOC.sh" ] ; then
		. "${bootdir}/SOC.sh"
		if [ ! "${zreladdr}" ] ; then
			zreladdr=${load_addr}
		fi
	fi

	unset need_uimage_uinitrd
	echo "-----------------------------"
	if [ -f ${bootdir}/uImage ] ; then
		need_uimage_uinitrd="enable"
		echo "Backing up uImage as uImage_bak..."
		sudo mv -v ${bootdir}/uImage ${bootdir}/uImage_bak
		sync
	fi

	if [ -f ${bootdir}/zImage ] ; then
		echo "Backing up zImage as zImage_bak..."
		sudo mv -v ${bootdir}/zImage ${bootdir}/zImage_bak
		sync
	fi

	if [ -f ${bootdir}/uInitrd ] ; then
		need_uimage_uinitrd="enable"
		echo "Backing up uInitrd as uInitrd_bak..."
		sudo mv -v ${bootdir}/uInitrd ${bootdir}/uInitrd_bak
		sync
	fi

	if [ -f ${bootdir}/initrd.img ] ; then
		echo "Backing up initrd.img as initrd.bak..."
		sudo mv -v ${bootdir}/initrd.img ${bootdir}/initrd.bak
		sync
	fi

	if [ ! -f /boot/initrd.img-${kernel_version} ] ; then
		echo "Creating /boot/initrd.img-${kernel_version}"
		sudo update-initramfs -c -k ${kernel_version}
		sync
	fi

	if [ "${has_mkimage}" ] && [ "x${need_uimage_uinitrd}" = "xenable" ] ; then
		if [ "${zreladdr}" ] ; then
			echo "-----------------------------"
			mkimage -A arm -O linux -T kernel -C none -a ${zreladdr} -e ${zreladdr} -n ${kernel_version} -d /boot/vmlinuz-${kernel_version} ${bootdir}/uImage
			sync
		fi
		echo "-----------------------------"
		mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d /boot/initrd.img-${kernel_version} ${bootdir}/uInitrd
		sync
	fi

	echo "-----------------------------"
	cp -v /boot/vmlinuz-${kernel_version} ${bootdir}/zImage
	cp -v /boot/initrd.img-${kernel_version} ${bootdir}/initrd.img
	sync

	echo "-----------------------------"
	ls -lh ${bootdir}/*
	echo "-----------------------------"
}

install_files () {
	#it's a new dawn
	if [ -f "/boot/uEnv.txt" ] ; then
		bootdir="/boot"
	else
		#legacy
		bootdir="/boot/uboot"
	fi

	if [ "${dtb_file}" ] && [ -f "/tmp/deb/${dtb_file}" ] ; then
		if [ -d ${bootdir}/dtbs_bak/ ] ; then
			rm -rf ${bootdir}/dtbs_bak/ || true
		fi

		if [ -d ${bootdir}/dtbs/ ] ; then
			mv ${bootdir}/dtbs/ ${bootdir}/dtbs_bak/ || true
			sync
		fi

		mkdir -p ${bootdir}/dtbs/ || true

		if [ -d /tmp/deb/dtb/ ] ; then
			rm -rf /tmp/deb/dtb/ || true
		fi

		echo "Installing [${dtb_file}]"
		mkdir -p /tmp/deb/dtb/
		tar xf /tmp/deb/${dtb_file} -C /tmp/deb/dtb/
		cp -v /tmp/deb/dtb/*.dtb ${bootdir}/dtbs/ 2>/dev/null || true
		sync
	fi

	if [ "${deb_file}" ] && [ -f "/tmp/deb/${deb_file}" ] ; then
		echo "Installing [${deb_file}]"
		dpkg -i /tmp/deb/${deb_file}
		if [ "x${third_party_modules}" = "xenable" ] ; then
			install_third_party
		fi
		install_boot_files
	fi
}

all_done () {
	sync
	echo "Script done: please reboot"
}

system_checks
get_html_file_list
parse_index_html
dl_files
install_files
all_done
