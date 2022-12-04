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

result=$(apt list linux-headers-$(uname -r))
kernel=$(uname -r)
if [[ $result == *$kernel*  ]]
then 
  echo "-----------------------------------------------------------------------"
  echo "             Kernel-headers have already been loaded."
  echo "-----------------------------------------------------------------------"
  echo ""
else
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
if [ ! -d "/home/volumio/cava" ]
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
if [ ! -d "/home/volumio/libu8g2arm" ]
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

echo "-----------------------------------------------------------------------"
echo "               Installing the startup script...                        "
echo "-----------------------------------------------------------------------"
echo ""

if [ ! -d "/home/volumio/scripts" ] 
then
  mkdir /home/volumio/scripts
fi

if [ -f "/home/volumio/scripts/start_mpd.sh" ] 
then
  rm /home/volumio/scripts/start_mpd.sh
fi

cd /home/volumio/scripts
#touch start_mpd.sh
#echo "#/bin/bash" >> start_mpd.sh
#echo "sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L t -o SSD1306,128X64,I2C,bus_number='$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//')' -f 50" >> start_mpd.sh
cat << EOF > start_mpd.sh
#!/bin/bash
sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L n -o SSD1306,128X64,I2C,bus_number=\$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') -f 50
EOF
chmod 0755 start_mpd.sh
cd ~

echo "-----------------------------------------------------------------------"
echo "               Installing the startup service...                       "
echo "-----------------------------------------------------------------------"
echo ""

if [ -f "/lib/systemd/system/oledstart.service" ]
then
  sudo systemctl disable oledstart.service
  sudo rm /lib/systemd/system/oledstart.service
  sudo systemctl daemon-reload
  
else

service="oledstart"
tmp_file_name="/tmp/$service.service"
tmp_file_contents="[Unit]
Description=MPD OLED Plugin
After=network.target sound.target mpd.service
Requires=mpd.service

[Service]
ExecStart=/bin/bash /home/volumio/scripts/start_mpd.sh

[Install]
WantedBy=multi-user.target
"
echo "$tmp_file_contents" > $tmp_file_name

sudo systemctl is-active --quiet $service && sudo systemctl stop $service
sudo cp -n $tmp_file_name /lib/systemd/system
sudo chmod 644 /lib/systemd/system/$service.service
sudo systemctl daemon-reload
sudo systemctl enable $service

fi

sudo dpkg-reconfigure tzdata

sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L n -o SSD1306,128X64,I2C,bus_number=$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') -f 50
exit
^C
