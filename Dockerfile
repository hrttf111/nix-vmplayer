FROM ubuntu:16.04
ARG VAGRANT_VERSION=1.9.5
ARG PACKER_VERSION=1.0.3
ARG VMWARE_WORKSTATION_VERSION=12.5.7-5813279

COPY vagrant.lic /root/vagrant.lic

RUN set -xe \
  \
  && apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
    wget \
    unzip \
    ca-certificates \
    libxinerama1 \
    libxtst6 \
    libxcursor1 \
    libxi6 \
    libfuse2 \
    build-essential \
    net-tools \
    linux-headers-$(uname -r) \
    linux-image-$(uname -r) \
  \
  && wget -q https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb -O /tmp/vagrant.deb \
  && dpkg -i /tmp/vagrant.deb \
  \
  && wget -q https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -O /tmp/packer.zip \
  && unzip /tmp/packer.zip -d /usr/bin/ \
  \
  && vagrant plugin install vagrant-vmware-workstation \
  && vagrant plugin license vagrant-vmware-workstation /root/vagrant.lic \
  \
  && wget -q https://download3.vmware.com/software/wkst/file/VMware-Workstation-Full-${VMWARE_WORKSTATION_VERSION}.x86_64.bundle -O /tmp/VMWareWorkstation.bundle \
  && chmod +x /tmp/VMWareWorkstation.bundle \
  && /tmp/VMWareWorkstation.bundle --console --required --eulas-agreed \
  \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME /root
VOLUME /tmp

CMD ["/bin/bash"]
