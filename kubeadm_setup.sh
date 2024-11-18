#!/usr/bin/bash

function networking {
    # sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

    # Apply sysctl params without reboot
    sudo sysctl --system

    # Verify that net.ipv4.ip_forward is set to 1 with:
    sysctl net.ipv4.ip_forward
}

function install-crio {
    # https://github.com/cri-o/packaging/blob/main/README.md#usage

    # Set SELinux in permissive mode (effectively disabling it)
    #sudo setenforce 0
    #sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

    # Define the Kubernetes version and used CRI-O stream
    KUBERNETES_VERSION=v1.31
    CRIO_VERSION=v1.31

    # Add the Kubernetes repository
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF

    # Add the CRI-O repository
cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF

    # Install package dependencies from the official repositories
    dnf install -y container-selinux

    # Install the packages
    dnf install -y cri-o kubelet kubeadm kubectl

    # Start CRI-O
    systemctl enable crio --now

    # Bootstrap the cluster
    swapoff -a
    modprobe br_netfilter
    sysctl -w net.ipv4.ip_forward=1

    kubeadm init
}


networking
install-crio
