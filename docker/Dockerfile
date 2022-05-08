FROM ubuntu:18.04

ENV TZ=America/Montreal
ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
 && apt-get -y update \
 && apt-get -y upgrade \
 && apt-get -y install tofrodos iproute2 gawk xvfb git make net-tools libncurses5-dev tftpd \
 zlib1g:i386 libssl-dev flex bison libselinux1 gnupg wget diffstat chrpath socat xterm \
 autoconf libtool libtool-bin tar unzip texinfo gcc-multilib build-essential libsdl1.2-dev \
 libglib2.0-dev screen pax gzip sudo expect locales lsb-release cpio libgtk2.0 bc vim rsync \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && echo "dash dash/sh boolean false" | debconf-set-selections \
 && dpkg-reconfigure dash \
 && locale-gen en_US.UTF-8 \
 && update-locale

ENV INSTALLER=petalinux-v2021.1-final-installer.run
WORKDIR /installer/
COPY accept-eula.sh ${INSTALLER} /installer/

RUN useradd petalinux \
 && mkdir -p /opt/Xilinx/petalinux /home/petalinux/ \
 && chown -Rv petalinux:petalinux /installer/ /opt/Xilinx/petalinux/ /home/petalinux \
 && chmod +x ./* \
 && sudo -u petalinux ./accept-eula.sh ./${INSTALLER} /opt/Xilinx/petalinux/ \
 && cd / \
 && rm -rf /installer/ /tmp/*

WORKDIR /petalinux
ENV LANG=en_US.UTF-8
USER petalinux
