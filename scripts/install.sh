#!/bin/bash
cd ~
echo "-----------------------------------------------------------------------"
echo "               Installing needed packages for volumio...               "
echo "-----------------------------------------------------------------------"
echo ""
sudo apt-get update
sudo apt-get install -y build-essential autoconf make libtool libfftw3-dev libiniparser-dev libmpdclient-dev libi2c-dev lm-sensors libasound2-dev autoconf-archive i2c-tools dkms

cd ~
echo "-----------------------------------------------------------------------"
echo "               Downloading kernel-headers for volumio...               "
echo "-----------------------------------------------------------------------"
echo ""
if [ ! -d "/usr/src/linux-headers-5.10.139-volumio" ] 
then
  wget https://github.com/volumio/x86-kernel-headers/raw/master/linux-headers-5.10.139-volumio_5.10.139-volumio-1_amd64.deb 
  sudo dpkg -i linux-headers-5.10.139-volumio_5.10.139-volumio-1_amd64.deb
  sudo ln -s /usr/src/linux-headers-5.10.139-volumio /lib/modules/5.10.139-volumio/build
fi

cd ~
echo "-----------------------------------------------------------------------"
echo "               Installing the i2c-ch341-usb drivers...                 "
echo "-----------------------------------------------------------------------"
echo ""
if [ ! -d "/lib/modules/5.10.139-volumio/updates/dkms/i2c-ch341-usb.ko" ]
then
	git clone https://github.com/gschorcht/i2c-ch341-usb.git
	cd i2c-ch341-usb
	make && sudo make install >> "/dev/null"
fi
cd ~

echo "-----------------------------------------------------------------------"
echo "               Adding Volumio to the i2c group...                      " 
echo "-----------------------------------------------------------------------"
echo ""
if id -Gn "volumio"|grep -c "i2c"; then
    echo "volumio already belongs to group i2c"
else
    sudo addgroup volumio i2c
fi

echo "-----------------------------------------------------------------------"
echo "               Installing the repo for CAVA...                         "
echo "-----------------------------------------------------------------------"
echo ""
if [ -d "/home/volumio/cava" ]
then
	git clone https://github.com/karlstav/cava
	cd cava
	./autogen.sh && ./configure --disable-input-portaudio --disable-input-sndio --disable-output-ncurses --disable-input-pulse --program-prefix=mpd_oled_ && make  && sudo make install-strip >> "/dev/null"
fi
cd ~

echo "-----------------------------------------------------------------------"
echo "               Installing and compiling the libu8g2 library.           "
echo "                  This will take some time. Hold on...                 "
echo "-----------------------------------------------------------------------"
echo ""
if [ -d "/home/volumio/libu8g2arm"]
then
	git clone https://github.com/antiprism/libu8g2arm.git
	cd libu8g2arm
	./bootstrap
	mkdir build && cd build
	CPPFLAGS="-W -Wall -Wno-psabi" ../configure --prefix=/usr/local  && make 
fi
cd ~

 echo "-----------------------------------------------------------------------"
 echo "               Installing the DEV branch of MPD_OLED...                "
 echo "-----------------------------------------------------------------------"
 echo ""
 git clone https://github.com/wheaten/mpd_oled_dev
 cd mpd_oled_dev
 ./bootstrap 
 LIBU8G2_DIR=../libu8g2arm CPPFLAGS="-W -Wall -Wno-psabi" ./configure --prefix=/usr/local &&  make  >> "/dev/null" &&  sudo make install-strip >> "/dev/null"
 
 ./bootstrap 
 LIBU8G2_DIR=../libu8g2arm CPPFLAGS="-W -Wall -Wno-psabi" ./configure --prefix=/usr/local &&  make  >> "/dev/null" &&  sudo make install-strip >> "/dev/null"
 cd ~

sudo mpd_oled_volumio_mpd_conf_install


# #sudo rm -rf /usr/src/linux-headers-5.10.139-volumio
# #sudo rm -rf /lib/modules/5.10.139-volumio

# #sudo apt-mark auto '^linux-headers-5.10.139-volumio'
# #sudo apt autoremove
# #sudo reboot
