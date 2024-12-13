* Service Transition Experimental Analysis - Pod Migration

This repository contains experimental analysis for service transition using **pod migration** in a Kubernetes cluster. The primary focus is to evaluate and improve **latency during migration** using **CRIU** (Checkpoint/Restore in Userspace) and other tools.

## Key Features

* **Pod Migration:** Leveraging CRIU and containerd to enable live migration of pods between Kubernetes worker nodes.
* **NFS Integration:** Shared state storage to support checkpointing and restoration.
* **Performance Optimization:** Analyzing latency and optimizing the migration process, compared to the default Kubernetes.

## Getting Started

### 1. Prerequisites

* Kubernetes cluster with 1 master node and 2 worker nodes
* CRIU installed on the worker nodes
* NFS server configured and accessible from all nodes
* containerd as the container runtime
* Extended kubelet

## 2. Provision Kubernetes cluster with Podmigratin enabled.

 The document to init k8s cluster, which enables podmigration feature can be found at:

* https://github.com/SSU-DCN/podmigration-operator/blob/main/init-cluster-containerd-CRIU.md

## 3. Install Checkpoint and migrate commands in Kubernets cluster

To install ``kubectl migrate/checkpoint`` command, follow the guide at

* https://github.com/SSU-DCN/podmigration-operator/tree/main/kubectl-plugin

## 4. Start pod-migration controller and api-server

Run the following command at directory podmigration-operator:

* To run Podmigration operator:

```
sudo snap install kustomize
sudo apt-get install gcc
make manifests
make install
make run
```

* To run api-server, which enables ``kubectl migrate`` command:

```
go run ./api-server/cmd/main.go
```

## 5. Deploy Application for testing.


## Note

This operator is controller of Kuberntes Pod migration for Kubernetes. It needs several changes to work such as: kubelet, container-runtime-cri (containerd-cri). The modified vesions of Kuberntes and containerd-cri beside this operator can be found in the following repos:

* https://github.com/vutuong/kubernetes
* https://github.com/vutuong/containerd-crierences
