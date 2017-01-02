sudo su
sudo apt-get -y upgrade && sudo apt-get install gnome i3 firefox terminator zsh 
reboot
sudo rm -r /lib/firmware/ath10k/QCA6174/
wget https://github.com/kvalo/ath10k-firmware/archive/master.zip
unzip master
sudo cp -r ath10k-firmware-master/ /lib/firmware/ath10k/
cd ~/
ls
sudo rm -r /lib/firmware/ath10k/ath10k-firmware-master/
sudo cp -r ath10k-firmware-master/QCA6174/ /lib/firmware/ath10k/
cd /lib/firmware/ath10k/QCA6174/hw2.1/
sudo mv firmware-5.bin_SW_RM.1.1.1-00157-QCARMSWPZ-1 firmware-5.bin
cd /lib/firmware/ath10k/QCA6174/hw3.0/
sudo mv firmware-4.bin_WLAN.RM.2.0-00180-QCARMSWPZ-1 firmware-4.bin
reboot
hto
htop
sudo apt install htop
sudo apt-get install htop
vim ~/.config/i3/config 
ls
gnome-nettool 
nm-applet 
nm
nmcli
nm-connection-editor 
nm-online 
ping 8.8.8.8
sudo apt install wicd
wicd
sudo wicd
wicd-client 
ping 8.8.8.8
wicd-client 
links
lynx
sudo apt install links
logout
ping 8.8.8.8
ping vicyap.com
ping 192.168.1.254
ping 192.168.1.242
exit
lshw
lspci
ls
ls /lib/firmware/ath10k/QCA6174/hw2.1/
sudo service network restart
sudo service network-manager restart
ping 8.8.8.8
sudo apt install pavucontrol
cd Pictures/
ls
cd Webcam/
ls
exit
pacmd
sudo update-alternatives --config editor
exit
cd usbb/
ls
rm -rf .*
rm -rf ./*
ls
exit
cd usbb
ls
rm -rf ./*
exit
chown --help
atop
sudo apt install atop
atop
sudo atop
acpi
sudo apt install acpi
acpi
ls -laht
vim /etc/i3status.conf 
sudo vim /etc/i3status.conf 
vim ~/.config/i3/config 
i3lock --help
ls
man i3lock
sudo apt-get install feh
wicd-gtk
nm-applet
ls
cd Pictures/
ls
cp shelter.jpg ~/.config/i3/
cd ~/.config/i3/
ls
mv shelter.jpg wallpaper.jpg
sudo apt install arandr
ls
head --help
cat ~/.screenlayout/default.sh | xclip -c selection
sudo apt install xclip
cat ~/.screenlayout/default.sh | xclip -c selection
cat ~/.screenlayout/default.sh | xclip selection -c
cat ~/.screenlayout/default.sh | xclip -selection
cat ~/.screenlayout/default.sh | xclip -c -selection
cat ~/.screenlayout/default.sh | xclip selection
xclip --help
man xclip
cat ~/.screenlayout/default.sh | xclip -selection clipboard
cat ~/.screenlayout/default.sh | xclip -selection c
ls
cd ~/
ls
cd Downloads/
ls
unzip Font-Awesome-4.7.0.zip 
ls
cd ..
ls -la
mkdir .fonts
cd Downloads/Font-Awesome-4.7.0/fonts/
ls
cp fontawesome-webfont.ttf ~/.fonts/
ls
cd ..
ls
cd ~/.fonts/
ls
sudo apt install glances
ssh 99.44.88.214
ssh vicyap.com
ls
echo "99.44.88.214" >> shelter_ip
cat shelter_ip 
mv shelter_ip shelter
cat shelter 
ls
mv shelter Documents/
pactl
pactl --htlp
pactl --help
pactl list
pactl list | less
pacmd list-sinks
pacmd list-sinks | less
pactl list-sinks | less
pactl list sinks | less
pactl --htlp
pactl --help
xmodkey -pke
xmodmap -pke
xev
xmodmap -pke
cd Downloads/
ls
sudo dpkg -i playerctl-0.5.0_amd64.deb 
playerctl 
sudo apt-get install system-config-lvm
sudo system-config-lvm 
vim ~/.config/i3/config 
cd .config/
ls
cd i3
ls
vim config 
ls
cd ..
ls
cd ..
ls
rm -rf master.zip 
rm -rf ath10k-firmware-master/
ls
mkdir /mnt/usbb
sudo mkdir /mnt/usbb
mount /dev/sdb /mnt/usbb
sudo mount /dev/sdb /mnt/usbb
cd /mnt/usbb/
ls
cd ..
ls
cd ~
ls
cp -r /mnt/usbb usbb
sudo cp -r /mnt/usbb usbb
ls
cd usbb
ls
cd subb
cd usbb/
ls
cd ..
ls
rm -rf Candidate\ Expense\ Form_503_5210.pdf 
rm -rf configs.zip 
rm -rf aws_credentials.csv 
ls
cd usbb
ls
cd research/
ls
cd ..
ls
cd jobs
ls
cd ..
ls
cd ..
ls
cd ..
ls
rm -rf usbb
sudo rm -rf usbb
sudo nautilus
sudo chown -r vicyap /mnt/usbb/
sudo chown -R vicyap /mnt/usbb/
chgrp -R vicyap /mnt/usbb/
sudo nautilus
ls
rmdir /mnt/usbb/
sudo rmdir /mnt/usbb/
sudo umount /mnt/usbb 
sudo rmdir /mnt/usbb/
cd /media/vicyap/cf9bb5a2-1807-4d68-b9a9-e61ca9e1ce3c/
ls
ls ~
mkdir ~/usbb
cp -r ./* ~/usbb/
ls
chmod +r ./*
sudo chmod +r ./*
cp -r ./* ~/usbb/
sudo cp -r ./* ~/usbb/ && chown -R vicyap ~/usbb && chgrp -R vicyap ~/usbb
cd ~/usbb
ls
ls -la
ls -lah
ls
rm -rf ./*
sudo ~~
sudo rm -rf ./*
sudo cp -r /media/vicyap/cf9bb5a2-1807-4d68-b9a9-e61ca9e1ce3c/* ~/usbb/ && sudo chown -R vicyap ~/usbb && sudo chgrp -R vicyap ~/usbb
ls
ls -la
ls -lah
cd ..
ls
du -h -d 0 ./usbb
sudo apt-get install taskwarrior
task --help
man task
task add finish setting up i3
task list
task add install android studio
pip
sudo apt install python-pip
ls
glances
sudo apt install glances
pip install glances
pip install --upgrade pip
glances
htop
sudo apt install htop
glances
htop
xbacklight
sudo apt install xbacklight
xbacklight
xbacklight -dec 20
xbacklight -inc 20
xbacklight --help
xbacklight -get
ls
vim ~/.config/i3/config 
ls
systemctl suspend 
vim /etc/systemd/logind.conf 
sudo vim /etc/systemd/logind.conf 
systemctl restart systemd-logind.service 
sudo apt-get install pm-utils
sudo pm-suspend
sudo shutdown now
sudo vim /etc/network/interfaces
wicd-client 
sudo apt-get install uxvt
sudo apt search uxvt
sudo apt-get install urxvt
sudo apt-get install rxvt
rxvt
ls
vim ~/.config/i3/config 
vim ~/.Xresources
rxvt --help
rxvt --help | grep scroll
rxvt --help &>1 | grep scroll
rxvt --help 2&>1 | grep scroll
rxvt --help &2>1 | grep scroll
rxvt --help &2>1 | grep Scroll
rxvt --help | grep Scroll
screen
vim ~/.Xresources 
rxvt --help
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
exit
ls
rm 1
ls -lah
apt-get install rxvt-unicode
sudo apt-get install rxvt-unicode
vim ~/.config/i3/config 
ls
vim ~/.Xresources 
xrdb ~/.Xresources 
ls
vim ~/.Xresources 
xrdb ~/.Xresources 
ls
npm 
sudo apt install npm
npm install --global base16-builder
sudo npm install --global base16-builder
base16-builder --help
node
sudo apt install nodejs-legacy
base16-builder --help
base16-builder -s default -t rxvt-unicode -b dark
base16-builder -s default -t rxvt-unicode -b dark >> colors
ls
vim colors
vim ~/.Xresources 
xrdb ~/.Xresources 
ls
rm colors
vim ~/.config/i3/config 
cd ~/.config/
ls
cd i3
ls
mv wallpaper.jpg ../.wallpaper.jpg
vim i3
vim config 
sudo vim /usr/share/X11/xorg.conf.d/50-synaptics.conf 
sudo vim /usr/share/X11/xorg.conf.d/50-vmmouse.conf 
sudo vim /usr/share/X11/xorg.conf.d/50-synaptics.conf 
cat /usr/share/X11/xorg.conf.d/50-synaptics.conf 
sudo cp /usr/share/X11/xorg.conf.d/50-synaptics.conf /etc/X11/xorg.conf.d/50-synaptics.conf
cd /etc/X11/
ls
vim Xsession
mkdir -r xorg.conf.d
sudo mkdir xorg.conf.d
sudo cp /usr/share/X11/xorg.conf.d/50-synaptics.conf /etc/X11/xorg.conf.d/50-synaptics.conf
ls
rm -rf xorg.conf.d/
sudo rm -rf xorg.conf.d/
sudo touch /usr/share/X11/xorg.conf.d/20-natural-scrolling.conf
sudo vim /usr/share/X11/xorg.conf.d/20-natural-scrolling.conf 
xinput list
sudo apt install xinput
xinput list
xinput list-props {device id} | grep "Scrolling Distance"
xinput list-props {12} | grep "Scrolling Distance"
xinput list-props 12 | grep "Scrolling Distance"
xinput set-prop 12 275 -1 -1 -1
xinput set-prop 12 275 -112 -112
sudo vim /usr/share/X11/xorg.conf.d/20-natural-scrolling.conf 
upower
upower --help
man upower
systemd blame
systemd-blame
systemd-analyze blame
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily.timer 
ls
l
cd /usr/lib/urxvt/perl/
ls
ls -lah
wget https://raw.githubusercontent.com/effigies/urxvt-perl/master/fullscreen
sudo wget https://raw.githubusercontent.com/effigies/urxvt-perl/master/fullscreen
vim ~/.Xresources 
xrdb ~/.Xresources 
exit
sudo apt-get install wmctrl
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
cd /usr/lib/urxvt/perl/
ls
sudo wget ⎋https://raw.githubusercontent.com/simmel/urxvt-resize-font/master/resize-font
sudo wget https://raw.githubusercontent.com/simmel/urxvt-resize-font/master/resize-font
xrdb ~/.Xresources 
ls
vim ~/.Xresources 
sudo apt install wmctrl
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrvt-un
lsidf
ls
rxvt
rxvt-xterm 
rxvt-xpm 
vim ~/.config/i3/config 
vim ~/.Xresources 
rxvt-unicode 
ls
ls -lah
vim .Xresources 
ls -la /
man rxvt
man rxvt-unicode 
ls -la
mkdir .urxvt/etx -p
man rxvt-unicode 
cd .urxvt/etx/
cd ..
mv etx/ ext
cd ext/
ls
wget https://raw.githubusercontent.com/simmel/urxvt-resize-font/master/resize-font
wget https://raw.githubusercontent.com/effigies/urxvt-perl/master/fullscreen
ls
xrdb  ~/.Xresources 
xrdb --help
xrdb
cd /usr/lib/urxvt/perl/
ls
sudo rm fullscreen 
sudo rm resize-font 
cd ~/.urxvt/
ls
cd ext/
ls
man urxvt
xrdb ~/.Xresources 
rxvt --help
vim ~/.Xresources
sudo reboot
vim ~/.config/i3/config 
ls
sudo apt install perl
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.config/i3/config 
systemd-analyze blame
vim ~/.Xresources 
xrdb ~/.Xresources 
urxvt-extensions
urxvt -pe fullscreen
man urxvt
vim ~/.Xresources 
xrdb ~/.Xresources 
vim ~/.Xresources 
xrdb ~/.Xresources 
ls
echo "https://wiki.archlinux.org/index.php/Rxvt-unicode#Changing_font_size_on_the_fly"
ls
sudo reboot
logout
exit
vim ~/.config/i3/config 
systemd-analyze blame
ls
pip install youtube-dl
pip install youtube-dl --user
cd Videos/
ls
youtube-dl https://www.youtube.com/watch?v=MVMRzH0dBlg
bg
cd ..
ls
cd Music/
ls
youtube-dl -x --audio-format mp3 https://www.youtube.com/watch?v=MVMRzH0dBlg
ls
cd ..
ls
cd Vic
ls
cd Videos/
ls
sudo apt install vlc
ls
vlc Major\ Lazer\ \&\ MØ\ LIVE\ @\ Lollapalooza\ Festival\ 2016\ Chicago\ \ _FULL\ SHOW-MVMRzH0dBlg.mp4 
glances
task list
task add create dotfiles repo on github
task add figure out how to suspend
sudo shutdown
sudo shutdown now
import
exit
vim /etc/acpi/events/powerbtn 
cd /etc/acpi
ls
vim powerbtn.sh 
sudo vim events/lid
mkdir actions
sudo mkdir actions
sudo vim actions/lid.sh
sudo chmod +x actions/lid.sh 
exit
sudo vim /etc/acpi/actions/lid.sh 
apt search xscreensaver
sudo apt-get install xscreensaver
ls -lah
vim .xscreensaver
ls -la
vim .Xresources 
xrdb ~/.Xresources 
vim ~/.config/i3/config 
setterm -blank 0 -powerdown 0
setterm --blank 0 --powerdown 0
vim ~/.config/i3/config 
vim ~/.Xresources 
vim ~/.config/i3/config 
vim ~/.Xresources 
xrdb ~/.Xresources 
sudo apt-get install xss-lock
xss-lock --help
xss-lock -- i3lock -c 000000 -f
vim ~/.config/i3/config 
ls
vim ~/.config/i3/config 
i3lock --help
vim ~/.config/i3/config 
man i3lock
convert ~/.config/.wallpaper.jpg ~/.config/.wallpaper.png
vim ~/.config/i3/config 
convert --help
man i3lock 
convert --help
convert --help | less
convert -resize 1920x1080 ~/.config/.wallpaper.png ~/.config/.wallpaper_1920x1080.png 
feh ~/.config/.wallpaper_1920x1080.png 
convert -resize 1920x1200 ~/.config/.wallpaper.png ~/.config/.wallpaper_1920x1200.png 
feh ~/.config/.wallpaper_1920x1200.png 
mv ~/.config/.wallpaper.jpg ~/.config/.wallpaper.jpg.orig
mv ~/.config/.wallpaper.jpg.orig ~/.config/.wallpaper.orig.jpg
cd ~/.config/
ls
ls -la
mv .wallpaper_1920x1200.png .wallpaper.png
ls
rm .wallpaper_1920x1080.png 
ls -lah
vim i3/config 
cd ..
ls
sudo apt-get remove xscreensaver
vim ~/.Xresources 
reboot
sudo vim /etc/acpi/events/lid 
sudo rm /etc/acpi/events/lid 
reboot
base16-builder -s default -t i3
base16-builder --help
base16-builder -s default -t i3 -b dark
screen
gnome-screenshot 
ls
cd Pictures/
ls
feh Screenshot\ from\ 2016-12-29\ 00-28-36.png 
sudo apt-get install screenshot
gdm-screenshot 
compton --help
man compton
compton
vim ~/.config/i3/config 
cd .config
ls
mkdir i3status
cd i3status/
vim config
sudo bash /etc/fonts/infinality/infctl.sh setstyle
screen
rofi
vim ~/.config/i3/config 
sudo add-apt-repository ppa:numix/ppa
sudo apt-get update && sudo apt-get install numix-gtk-theme
sudo apt-get install libglib2.0-dev libgdk-pixbuf2.0-dev libxml2-utils
sudo apt-get install numix-gtk-theme 
sudo apt-get install numix-icon-theme
sudo apt-get install compton
compton --help
man compton
sudo apt-get install rofi
rofi
rofi --help
rofi --help | less
rofi
base16-builder -s default -t rofi -b dark
vim ~/.Xresources 
xrdb ~/.Xresources 
man rofi
sudo apt-get install numix-icon-theme-circle 
pip install py3status --user
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886
echo deb http://repository.spotify.com stable non-free | sudo tee /etc/apt/sources.list.d/spotify.list
sudo apt-get update
sudo apt-get install spotify-client
sudo apt-get update
sudo apt-get --fix-missing
sudo apt-get update --fix-missing
sudo apt-get install spotify-client
vim ~/.config/i3/config 
vim ~/.Xresources 
vim ~/.config/i3/config 
cd .config/i3
ls -la
rm .config.swp 
vim config 
vim ~/.config/i3/config 
base16-builder -s default -t i3status -b dark
base16-builder -s default -t vim -b dark
base16-builder -s default -t vim -b dark | less
base16-builder -s default -t xresources -b dark | less
vim ~/.Xresources 
xrdb ~/.Xresources 
base16-builder -s default -t less -b dark | less
base16-builder -s default -t ipython-notebook -b dark | less
sudo apt-get install lxappearance
ls -lah
vim .xscreensaver 
ls
rm .xscreensaver 
ls
ls -la
vim .gtkrc-2.0 
sudo add-apt-repository ppa:no1wantdthisname/ppa
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install fontconfig-infinality
vim ~/.config/i3/config 
py3status 
vim ~/.config/i3/config 
reboot
exit
sudo apt-get install pamixer
pactl
pactl --help
amixer
pavucontrol 
pyton
python
ipyton
ipython
pip install ipython --user
ipython
base16-builder -s default -t ipython -b dark
ipython
exit
pactl --help
pactl list
pactl --help
pactl list short
pactl list sinks
pactl list sinks | less
exit
cd usbb
ls
unzip configs.zip 
py3status -s
py3status --help
pip list
which py3status 
pip show py3status
cd ~/.local/lib/python2.7/
ls
cd site-packages/
ls
cd py3status
ls
cd modules/
ls
vim volume_status.py
git status
cd ~
pip install pytest pytest-flake8 --user
ls
mkdir Proje
ls
rmdir Proje/
mkdir Projects
cd Projects/
ls
git clone https://github.com/ultrabug/py3status/tree/master/doc#writing_custom_modules
git clone https://github.com/ultrabug/py3status.git
ls
cd py3status/
ls
py.test --flake8
ls
cd py3status/
ls
cd modules/
ls
vim volume_status.py 
cd ../../
ls
py.test --flake8
git status
git config
git config --global
git config --global user.name "vicyap"
git config --global user.email "victor.yap@utexas.edu"
git status
ls
git status
vim py3status/modules/volume_status.py 
ls
git status
ls
cd ..
ls
git clone https://github.com/vicyap/py3status.git
ls
rm -rf py3status/
git clone https://github.com/vicyap/py3status.git
cd py3status/
ls
vim py3status/modules/volume_status.py 
git status
git add py3status/modules/volume_status.py 
git commit -m "fixed volume_status PactlBackend to read user-specified device"
git push
ls
py.test --flake8
vim py3status/modules/volume_status.py 
py.test --flake8
vim py3status/modules/volume_status.py 
py.test --flake8
git status
git diff
git status
git checkout -- py3status/modules/volume_status.py
git status
ls
exit
ls
ls -lah
vim .config/i3status/config 
ls
cd ~/.config/i3status/con
l
cd ~/.config/i3status/
cp ~/usbb/.config/i3status/config ./config.old
vim config
vim config.old
mv config config.bak
mv config.old config
vim config
:q
exit
xrdb ~/.Xresources 
ls
vim ~/.config/i3status/config 
ls
cd ~/.config/i3status/
ls
cp /etc/i3status.conf ./config
vim config 
cp /etc/i3status.conf ./config
vim ~/.config/i3/config 
screen
cd ~
clear
screen
compton
htop
man rofi
xrdb ~/.Xresources 
compton
bg
fg
bg
compton
man rofi
base16-builder -s default -t dmenu -b dark
dmenu
dmenu_run --help
clear
dmenu_run --help
man dmenu_run
dmenu -nb '181818' -nf '585858' -sb '7cafc2' -sf '181818'
dmenu_run -nb '181818' -nf '585858' -sb '7cafc2' -sf '181818'
dmenu_run -nb #181818' -nf '585858' -sb '7cafc2' -sf '181818'
dmenu_run -nb #181818 -nf '585858' -sb '7cafc2' -sf '181818'
dmenu_run -nb '#181818' -nf '585858' -sb '7cafc2' -sf '181818'
man dmenu_run
exit
:w
ls
cd Downloads/
sudo dpkg -i google-chrome-stable_current_amd64.deb 
xprop
clear
xprop
vim ~/.config/i3/config 
ls 
screen
compton
compton -f -D 1
compton -f -D 100
compton -f -D 0.1
compton -f -D 1
man compton
compton -f -D 1
compton -f -D 2
xprop
vim ~/.config/i3/config 
xprop
xdg-open --help
man xdg-open
sensible-browser 
sensible-browser  --help
man sensible-browser 
update-alternatives --config browser
select-editor 
sensible-editor 
sudo update-alternatives --config editor
sudo update-alternatives --config x-www-browser 
sudo apt-get update
sudo update-alternatives --config x-www-browser 
sudo apt-get upgrade 
sudo apt-get update -f
sudo apt-get upgrade -f
sudo update-alternatives --config x-www-browser 
sensible-browser 
cd ~/.config/i3
ls
ls -lah
rm .config.swp 
vim config 
ls
ls -la
reboot
vim ~/.config/i3/config 
pactl --help
man pactl
pacmd
man pacmd
pacmd --help
pacmd --help | less
pacmd list-sinks
pacmd list-sinks | less
pulseaudio 
sudo su
pacmd --help
pacmd info
pacmd info | less
ls
man compton
vim ~/.config/i3/config 
task list
task --help
man task
task help
task help | less
task commands
task commands | less
task list
task done 4
task done 1
task add setup i3bar (py3status)
task add "finish setting up py3statusbar"
task add "attempt to make chicken rice via steeping chicken"
acpi
wicd-client 
shutdown now
vim ~/.config/i3/config 
ip address show
netifaces
ls /sys/class/net
ls /sys/class/net/enp2s0/
man stow
exit
