# Install instructions for Volumio 3 using source on x86
These instructions are written as a guide to install mpd_oled from source on Volumio 3 with x86 arcitecture (Intel).
Using a [DollaTek CH341A USB naar UART/IIC/SPI/TTL/ISP Adapter EPP/MEM parallelle converter](https://www.amazon.nl/gp/product/B07DJZDRKG).
This is the only type I've tested.
Full CAVA only for a 128x64 pixel screen

## Base system

Install [Volumio](https://volumio.org/). Ensure a command line prompt is
available for entering the commands below (e.g.
[use SSH](https://volumio.github.io/docs/User_Manual/SSH.html).)

## Install all dependencies

Install all the packages needed to build and run cava and mpd_oled
```
sudo apt-get update
sudo apt-get install build-essential autoconf make libtool libfftw3-dev libiniparser-dev libmpdclient-dev libi2c-dev lm-sensors libasound2-dev autoconf-archive i2c-tools dkms
```

## Get headers to perform make (will break ATO):
```
wget https://github.com/volumio/x86-kernel-headers/blob/master/linux-headers-5.10.139-volumio_5.10.139-volumio-1_amd64.deb
sudo dpkg -i linux-headers-5.10.139-volumio_5.10.139-volumio-1_amd64.deb
sudo ln -s /usr/src/linux-headers-5.10.139-volumio /lib/modules/5.10.139-volumio/build
```

## Install driver:

```
git clone https://github.com/gschorcht/i2c-ch341-usb.git
cd i2c-ch341-usb
make
sudo make install
cd ..
```

Check if loaded:
```
dmesg | grep i2c-ch341-usb
```

Add volumio to group:
```
sudo addgroup volumio i2c
newgrp - i2c
```

## Build and install cava

mpd_oled uses Cava, a bar spectrum audio visualizer, to calculate the spectrum
   
   <https://github.com/karlstav/cava>

If you have Cava installed (try running `cava -h`), there is no need
to install Cava again, but to use the installled version you must use
`mpd_oled -k ...`.

Download, build and install Cava. These commands build a reduced
feature-set executable called `mpd_oled_cava`.
```
git clone https://github.com/karlstav/cava
cd cava
./autogen.sh
./configure --disable-input-portaudio --disable-input-sndio --disable-output-ncurses --disable-input-pulse --program-prefix=mpd_oled_
make
sudo make install-strip
cd ..    # leave cava directory
```

## Build and install mpd_oled

Download and build libu8g2arm (running `make` might take 0.5-1 hours on a low resource system)
```
git clone https://github.com/antiprism/libu8g2arm.git
cd libu8g2arm
./bootstrap
mkdir build
cd build
CPPFLAGS="-W -Wall -Wno-psabi" ../configure --prefix=/usr/local
make
cd ../..  # leave libu8g2arm/build directory
```

Download, build and install mpd_oled.
```
git clone https://github.com/antiprism/mpd_oled_dev
cd mpd_oled_dev
./bootstrap
LIBU8G2_DIR=../libu8g2arm CPPFLAGS="-W -Wall -Wno-psabi" ./configure --prefix=/usr/local
make
sudo make install-strip
cd ..
```

## I2C

I used a cheap 4 pin I2C [SSD1306](https://www.amazon.nl/gp/product/B074NJMPYJ) display on a HP EliteDesk G1 800 mini or Dell Wyse 3040. 
other PC's will also work, but haven't tested it.
It is wired like this. Depending on your OLED, you might need to change the 2 jumpers to switch between 5V and 3,3V on the VCC output.

![wired](connection_i2c.png)


## Configure a copy of the playing audio
*The next instruction configure MPD to make a copy of its output to a*
*named pipe, where Cava can read it and calculate the spectrum.*
*This works reliably, but has two disadvantages: the configuration*
*involves changing a Volumio system file, which must be undone*
*if Volumio is to be updated (see below); the spectrum*
*only works when the audio is played through MPD, like music files,*
*web radio and DLNA streaming. Creating a copy of the audio for all*
*audio sources is harder, and may be unreliable -- see the thread on*
*[using mpd_oled with Spotify and Airplay](https://github.com/antiprism/mpd_oled/issues/4)*

Configure MPD to copy its audio output to a named pipe
(Ignore the errors, as the pitastic was actually for the rPi, but it will fix the audio pipe)
```
wget -N http://pitastic.com/mpd_oled/packages/mpd_oled_volumio_install_latest.sh
sudo bash mpd_oled_volumio_install_latest.sh
sudo mpd_oled_volumio_mpd_conf_install
```

**Note:** after running this command the next Volumio update will fail
with a *system integrity check* error. The change can be undone by running
`sudo mpd_oled_volumio_mpd_conf_uninstall`, then after the Volumio update
run `sudo mpd_oled_volumio_mpd_conf_install` to re-enable the audio copy.

## Set the time zone

If the mpd_oled clock does not display the local time then you may need
to set the system time zone. Set this in the UI, or run the following
command for a console based application where you can specify your location
```
sudo dpkg-reconfigure tzdata
```

## Create a start script for MPD_OLED
If you want to run MPD_OLED in it's orignal configuration use:
```
sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L t -o SSD1306,128X64,I2C,bus_number=$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') -f 50
```

If you want too run as a full CAVA display, use:
```
sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L n -o SSD1306,128X64,I2C,bus_number=$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') -f 50
```

the code string $(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') is needed, as the bus number is not consistent. This way we always retrieve the correct number.

Running screens:

![.](display.png)

```
mkdir /home/volumio/scripts
nano /home/volumio/scripts/start_mpd.sh
```
```
#/bin/bash
sudo -u volumio /usr/local/bin/mpd_oled -b 20 -g 2 -P s -L n -o SSD1306,128X64,I2C,bus_number=$(dmesg | grep -iE "ch341_i2c_probe: created i2c device" | sed 's/^.*[/]//' | sed 's/.*-//') -f 50
```
Copy the desired string as mention above, in this case I take the full cava 

press CTRL+0 => Enter => CTRL+x
```
chmod 0755 /home/volumio/scripts/start_mpd.sh
```

## Configure mpd_oled and set to run at boot
Note: The program can be run without the audio copy enabled, in which case the spectrum analyser area will be blank

Create and Install a service file. 
```
sudo nano /lib/systemd/system/oled.service

[Unit]
Description=MPD OLED Plugin
User=volumio
Group=audio
After=network.target sound.target mpd.service
Requires=mpd.service

[Service]
ExecStart=/bin/bash /home/volumio/scripts/start_mpd.sh

[Install]
WantedBy=multi-user.target
```
press CTRL+0 => Enter => CTRL+x
```
sudo chmod 644 /lib/systemd/system/oled.service
sudo systemctl daemon-reload
sudo systemctl enable oled.service
sudo reboot
```
## Only tested with
Adafruit
SSD1306,128X64,I2C

## To do:
* Make screen size dynamic, currently only supporting 128x64 for full CAVA
* Currently a running PoC, to switch the layout (Normal/Full CAVA) with a switch via GPIO0


