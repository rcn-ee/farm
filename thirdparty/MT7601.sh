	file_dir="https://rcn-ee.net/deb/${release}-${dpkg_arch}/${FTPDIR}/"
	if [ "x${SUBARCH}" = "xomap-psp" ] ; then
		package="farm_mt7601u"

		cleanup_third_party

		echo '#!/bin/sh' > /build/buildd/thirdparty

		cd ${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/
		git clone https://github.com/rcn-ee/${package}.git

		cd /build/buildd/
		git clone https://github.com/rcn-ee/${package}.git

		cd /build/buildd/${package}/src/
		schroot -c ${release}-${dpkg_arch} -u ${chroot_user} -- ../build.sh

		#make sure the module was built
		file_upload="${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/${package}/src/os/linux/mt7601Usta.ko"
		if [ -f ${file_upload} ] ; then
			file_upload="${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/${package}/src/RT2870STA.dat"
			if [ -f ${file_upload} ] ; then
				generic_upload
				echo "mkdir -p /etc/Wireless/RT2870STA/" >> /build/buildd/thirdparty
				echo "wget ${file_dir}RT2870STA.dat -O /etc/Wireless/RT2870STA/RT2870STA.dat" >> /build/buildd/thirdparty
			fi

			file_upload="${CHROOT_DIR}/${release}-${dpkg_arch}/build/buildd/${package}/src/os/linux/mt7601Usta.ko"
			generic_upload
			echo "mkdir -p /lib/modules/${KERNEL_UTS}/kernel/drivers/net/wireless/" >> /build/buildd/thirdparty
			echo "wget ${file_dir}mt7601Usta.ko -O /lib/modules/${KERNEL_UTS}/kernel/drivers/net/wireless/mt7601Usta.ko" >> /build/buildd/thirdparty
			echo 'echo "mt7601Usta" > /etc/modules-load.d/mt7601.conf' >> /build/buildd/thirdparty

			file_upload="/build/buildd/thirdparty"
			generic_upload
		fi

		cleanup_third_party
	fi

