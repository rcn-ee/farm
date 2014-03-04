	file_dir="https://rcn-ee.net/deb/${release}-${dpkg_arch}/${FTPDIR}/"
	if [ "x${SUBARCH}" = "xomap-psp" ] ; then
		third_party="http://rcn-ee.net/deb/thirdparty"
		mt7601="DPO_MT7601U_LinuxSTA_3.0.0.4_20130913"

		cleanup_third_party

		echo '#!/bin/sh' > /build/buildd/thirdparty

		${wget_dl} ${third_party}/MT7601/${mt7601}.tar.bz2
		if [ -f /build/buildd/${mt7601}.tar.bz2 ] ; then
			mkdir -p /build/buildd/${mt7601}
			mv /build/buildd/${mt7601}.tar.bz2 ${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/
			cd ${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/
			tar xf ${mt7601}.tar.bz2
			rm -rf ${mt7601}.tar.bz2 || true
			cd /build/buildd/${mt7601}
			make_mt7601="make ARCH=arm CROSS_COMPILE= LINUX_SRC=/build/buildd/linux-src all"
			schroot -c ${release}-${dpkg_arch} -u ${CHROOTUSER} -- ${make_mt7601}
		fi
		file_upload="${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/${mt7601}/RT2870STA.dat"
		if [ -f ${file_upload} ] ; then
			generic_upload
			echo "mkdir -p /etc/Wireless/RT2870/" >> /build/buildd/thirdparty
			echo "wget ${file_dir}RT2870STA.dat -O /etc/Wireless/RT2870/RT2870STA.dat" >> /build/buildd/thirdparty
		fi
		file_upload="${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/${mt7601}/os/linux/mt7601Usta.ko"
		if [ -f ${file_upload} ] ; then
			generic_upload
			echo "mkdir -p /lib/modules/${KERNEL_UTS}/kernel/drivers/net/wireless/" >> /build/buildd/thirdparty
			echo "wget ${file_dir}mt7601Usta.ko -O /lib/modules/${KERNEL_UTS}/kernel/drivers/net/wireless/mt7601Usta.ko" >> /build/buildd/thirdparty
			echo 'echo "mt7601Usta" > /etc/modules-load.d/mt7601.conf' >> /build/buildd/thirdparty
		fi

		file_upload="/build/buildd/thirdparty"
		generic_upload

		cleanup_third_party
	fi