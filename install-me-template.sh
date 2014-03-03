#!/bin/sh -e
#
# Copyright (c) 2013 Robert Nelson <robertcnelson@gmail.com>
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

mirror="http://rcn-ee.net/deb"

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

	unset firmware_file
	firmware_file=$(cat /tmp/deb/index.html | grep firmware.tar.gz | head -n 1)
	firmware_file=$(echo ${firmware_file} | awk -F "\"" '{print $2}')

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

	if [ "${firmware_file}" ] ; then
		if [ -f /tmp/deb/${firmware_file} ] ; then
			rm -rf /tmp/deb/${firmware_file} || true
		fi
		wget --directory-prefix=/tmp/deb/ ${mirror}/${release}-${dpkg_arch}/${version}/${firmware_file}
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
	if [ -f "/boot/uboot/SOC.sh" ] ; then
		. "/boot/uboot/SOC.sh"
		if [ ! "${zreladdr}" ] ; then
			zreladdr=${load_addr}
		fi
	fi

	echo "-----------------------------"
	if [ -f /boot/uboot/uImage ] ; then
		echo "Backing up uImage as uImage_bak..."
		sudo mv -v /boot/uboot/uImage /boot/uboot/uImage_bak
		sync
	fi

	if [ -f /boot/uboot/zImage ] ; then
		echo "Backing up zImage as zImage_bak..."
		sudo mv -v /boot/uboot/zImage /boot/uboot/zImage_bak
		sync
	fi

	if [ -f /boot/uboot/uInitrd ] ; then
		echo "Backing up uInitrd as uInitrd_bak..."
		sudo mv -v /boot/uboot/uInitrd /boot/uboot/uInitrd_bak
		sync
	fi

	if [ -f /boot/uboot/initrd.img ] ; then
		echo "Backing up initrd.img as initrd.bak..."
		sudo mv -v /boot/uboot/initrd.img /boot/uboot/initrd.bak
		sync
	fi

	if [ ! -f /boot/initrd.img-${kernel_version} ] ; then
		echo "Creating /boot/initrd.img-${kernel_version}"
		sudo update-initramfs -c -k ${kernel_version}
		sync
	fi

	if [ "${has_mkimage}" ] ; then
		if [ "${zreladdr}" ] ; then
			echo "-----------------------------"
			mkimage -A arm -O linux -T kernel -C none -a ${zreladdr} -e ${zreladdr} -n ${kernel_version} -d /boot/vmlinuz-${kernel_version} /boot/uboot/uImage
			sync
		fi
		echo "-----------------------------"
		mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d /boot/initrd.img-${kernel_version} /boot/uboot/uInitrd
		sync
	fi

	echo "-----------------------------"
	if [ -f /boot/zImage ] ; then
		rm -rf /boot/zImage || true
		cp -v /boot/vmlinuz-${kernel_version} /boot/zImage
		sync
	fi
	cp -v /boot/vmlinuz-${kernel_version} /boot/uboot/zImage
	cp -v /boot/initrd.img-${kernel_version} /boot/uboot/initrd.img
	sync

	echo "-----------------------------"
	ls -lh /boot/uboot/*
	echo "-----------------------------"
}

install_files () {
	if [ "${dtb_file}" ] && [ -f "/tmp/deb/${dtb_file}" ] ; then
		if [ -d /boot/uboot/dtbs_bak/ ] ; then
			rm -rf /boot/uboot/dtbs_bak/ || true
		fi

		if [ -d /boot/uboot/dtbs/ ] ; then
			mv /boot/uboot/dtbs/ /boot/uboot/dtbs_bak/ || true
			sync
		fi

		mkdir -p /boot/uboot/dtbs/ || true

		if [ -d /tmp/deb/dtb/ ] ; then
			rm -rf /tmp/deb/dtb/ || true
		fi

		echo "Installing [${dtb_file}]"
		mkdir -p /tmp/deb/dtb/
		tar xf /tmp/deb/${dtb_file} -C /tmp/deb/dtb/
		cp -v /tmp/deb/dtb/*.dtb /boot/uboot/dtbs/ 2>/dev/null || true
		sync
	fi

	if [ "${firmware_file}" ] && [ -f "/tmp/deb/${firmware_file}" ] ; then
		if [ -d /tmp/deb/firmware/ ] ; then
			rm -rf /tmp/deb/firmware/ || true
		fi

		echo "Installing [${firmware_file}]"
		mkdir -p /tmp/deb/firmware/
		tar xf /tmp/deb/${firmware_file} -C /tmp/deb/firmware/
		cp -v /tmp/deb/firmware/*.dtbo /lib/firmware/ 2>/dev/null || true
		sync
	fi

	if [ "${deb_file}" ] && [ -f "/tmp/deb/${deb_file}" ] ; then
		echo "Installing [${deb_file}]"
		dpkg -i /tmp/deb/${deb_file}
		install_third_party
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
