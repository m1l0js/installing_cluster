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


#!/bin/bash

# Function to configure kubectl for a non-root user
configure_non_root_user() {
    echo "Configuring kubectl for non-root user: $USER"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo "Kubectl has been configured for non-root user: $USER"
}

# Function to configure kubectl for root user
configure_root_user() {
    echo "Configuring kubectl for root user"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "Kubectl has been configured for root user"
    echo "To make this permanent, add 'export KUBECONFIG=/etc/kubernetes/admin.conf' to your .bashrc or equivalent."
}



networking
install-crio

# Check if the user is root
if [ "$(id -u)" -eq 0 ]; then
    # User is root
    configure_root_user
else
    # User is not root
    configure_non_root_user
fi
