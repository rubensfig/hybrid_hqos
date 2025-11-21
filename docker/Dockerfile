#Copyright (C) 2024 Intel Corporation

#This software and the related documents are Intel copyrighted materials, and
#your use of them is governed by the express license under which they were
#provided to you ("License"). Unless the License provides otherwise, you may not
#use, modify, copy, publish, distribute, disclose or transmit this software or
#the related documents without Intel's prior written permission.

#This software and the related documents are provided as is, with no express or
#implied warranties, other than those that are expressly stated in the License.

FROM ubuntu:22.04 AS builder
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt -y upgrade && \
    apt install -y cmake python3 python3-pip sudo git wget 

# Install Go
RUN set -eux; \
        wget -nv -O go.tgz "https://golang.org/dl/go1.20.12.linux-amd64.tar.gz"; \
        tar -C /usr/local -xzf go.tgz; \
        rm go.tgz;

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# AGF enabled by default; set bng_enabled to 'true' to enable the BNG User Plane function
ARG bng_enabled=false
ARG power_mgmt=false
ARG multi_session=false

COPY vpp_agent /opt/vpp_agent

# Clone Ligato VPP-Agent 
RUN git clone https://github.com/ligato/vpp-agent.git /src/vpp-agent && \
    cd /src/vpp-agent && \
    git checkout 723f8db0bf7a67908e2dda1d860444a4747a99d8 && \
    if [ "$bng_enabled" = "true" ]; then \
        git apply /opt/vpp_agent/bng_agent_v24.03.patch; \
    else \
        git apply /opt/vpp_agent/agf_agent_v24.03.patch; \
    fi; 


RUN cd /src/vpp-agent/ && \
    go mod download && \
    make install purge


COPY vpp_patches /opt/vpp_patches

# Clone VPP
# VPP stable/2402 branch, tested commit ID 455960759b5417c767ed331748c7ee76662ffd18 at the time of this release.
RUN git clone https://github.com/FDio/vpp.git /opt/vagf_vpp && \
    cd /opt/vagf_vpp && \
    git checkout 455960759b5417c767ed331748c7ee76662ffd18 && \
    git apply /opt/vpp_patches/0001-INTEL-UPSTREAM.patch && \
    git apply /opt/vpp_patches/0002-add-config-to-change-the-speed.patch && \
    git apply /opt/vpp_patches/0003-dpdk-add-pmdlink.patch && \
    git apply /opt/vpp_patches/0004-add-pmdlink-changes.patch  && \
    git apply /opt/vpp_patches/0005-fix-compilation-issue-for-n_tx_queues.patch
    # git apply /opt/vpp_patches/0001-edit-values-for-25gb-4k.patch && \
    # git apply /opt/vpp_patches/0001-25gbps-config.patch;

WORKDIR /opt/vagf_vpp


RUN yes | make install-dep && \
    make build-release && \
    make pkg-deb && \
    make wipe-release

## New Container
FROM ubuntu:22.04
WORKDIR /opt/

# Adding all CLI configurations to container directories 
# Set a default value for configs_dir
ARG configs_dir=./configs/

COPY $configs_dir /opt/configs

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt install -y build-essential automake python3 python3-pip libcap-ng-dev gawk pciutils curl vim kmod hwdata libc6 lsb-base git libnuma-dev iproute2 findutils apt-utils autoconf libtool fakeroot cmake libmbedtls-dev sudo

# Copy VPP debian packages from build container
COPY --from=builder /opt/vagf_vpp/build-root/*.deb /opt/

RUN apt install -y ./*.deb


## Ligato VPP-Agent
# agent binaries
COPY --from=builder \
    /go/bin/agentctl \
    /go/bin/vpp-agent \
    /go/bin/vpp-agent-init \
 /bin/

# agent config files
COPY ./configs/*.conf \
 /opt/vpp-agent/dev/

COPY ./configs/init_hook.sh /usr/bin/
# COPY $configs_dir/startup.conf /etc/vpp/vpp.conf

RUN mkdir -p /run/vpp
ENV SUPERVISOR_CONFIG=/opt/vpp-agent/dev/supervisor.conf


## ETCD
# The default value for ARG ETCD_VER below can be overwritten by --build-arg
ARG ETCD_VER=v3.5.7
ENV ETCD_VER=${ETCD_VER}
# ETCD Download URL
ENV DOWNLOAD_URL=https://storage.googleapis.com/etcd
# Install etcdctl
WORKDIR /tmp
RUN curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    mkdir /tmp/etcd && \
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd --strip-components=1 && \
    rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    cp /tmp/etcd/etcdctl /tmp && \
    rm -rf /tmp/etcd

WORKDIR /opt/
COPY pod_down.sh /opt/pod_down.sh

# Copy and set entrypoint script
COPY start.sh .
ENTRYPOINT ["./start.sh"]

# To build: docker build --tag localhost:30500/vagf . --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy

# To run: docker run -d --network="host" --privileged=true -v /dev/hugepages:/dev/hugepages --cpuset-cpus=<DLCORE1>,<ULCORE>,<DLCORE2>,<CLICORE> --env PCIDEVICE_INTEL_COM_APP_AGF_UP=0000:<VF_PCI-1>,0000:<VF-PCI-2> --env MY_POD_IP=localhost --name=agf-<INSTANCE-NUM> -h agf-<INSTANCE-NUM> -it localhost:30500/vagf
