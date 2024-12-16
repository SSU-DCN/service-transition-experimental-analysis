# Service Transition Experimental Analysis - Pod Migration

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

Start the `pod-migration` controller and the accompanying API server to manage and trigger pod migrations:

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

Ensure the controller and API server are runningh and accessible in the cluster

## 5. Deploy Application for testing.

To test the migration setuo, deploy the following applications:

1. Video Streaming Application.
   This application simulates a real-time video streaming workload with the following characteristics:

   - High sensitivity to latency during migration
   - requires minimal downtime to maintain stream continuity

   Deployment:

   ```
   kubectl apply -f video.yaml
   kubectl apply -f svc-video.yaml
   ```
2. Redis.

   Redis is used to evaluate the migration of stateful applications. Characteristics:

   - Persistence enabled with Append-Only File (AOF).
   - Tests consistency and recovery of in-memory data during migration.

   Deployment:

   ```
   kubectl apply -f redis.yaml
   kubectl apply -f svc-redis.yaml
   ```
3. Machine Learning (Image classification-training).

   This application performs training for image classification models. Characteristics:

   - Resource-intensive workload.
   - Tests how migration affects long-running compute tasks.

   Deployment:

   ```
   kubectl apply -f ml-training.yaml
   kubectl apply -f svc-ml-training.yaml
   ```

## 6. Start Monitoring Scripts

Two monitoring scripts are provided to assist in observing the system:

1. **Pod event monitoring script**: Monitors the status of pods in the cluster and measure pod's creation time, application accessible time.

   ```
   service-transition-experimental-analysis\config\samples\migration-example\ python3 measurement.py 
   ```

   Edit the corresponding application name, protocol and service pord in the script

   ```
   monitor_pod_events(
       namespace="default",
       label_selector="app=video",
       app_url="192.168.28.184",
       app_port=31680,    #redis:31625, mongo:30257
       app_type="http"  # Use "http" for HTTP-based apps or "redis" for Redis
   )
   ```
2. **Pod Migration Monitoring Script:** Observes and logs pod migrations triggered by node drains, remove and re-deploy pod in new nodes.

```
   service-transition-experimental-analysis\config\samples\migration-example\ bash k8s_default_migrate.sh

```

## Note

This operator is controller of Kuberntes Pod migration for Kubernetes. It needs several changes to work such as: kubelet, container-runtime-cri (containerd-cri). The modified vesions of Kuberntes and containerd-cri beside this operator can be found in the following repos:

* https://github.com/vutuong/kubernetes
* https://github.com/vutuong/containerd-crierences
