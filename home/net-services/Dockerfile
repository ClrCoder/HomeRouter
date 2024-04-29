FROM ubuntu:noble

# This might be very important for the systemd
ENV container docker

# Speedup for the local download
RUN sed -i 's/archive.ubuntu.com/nz.archive.ubuntu.com/g' /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y systemd systemd-sysv dbus --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Remove unnecessary systemd services
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

RUN systemctl set-default multi-user.target

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT exec bash -c "mount /sys/fs/cgroup -o remount,rw && /sbin/init"

# Installing basic network utils
RUN apt-get update \
    && apt-get install apt-utils --no-install-recommends -y \
    && apt-get install --no-install-recommends -y \
    iptables \
    iputils-ping \
    iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Installing dhcpd service
RUN apt-get update \
    && apt-get install --no-install-recommends isc-dhcp-server -y \
    && systemctl disable isc-dhcp-server \
    && systemctl disable isc-dhcp-server6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*