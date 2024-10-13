# Kind-WI: Kind Cluster with Microsoft Workload Identity

Kind-WI (Kind Workload Identity) is a project that sets up a local Kubernetes cluster using Kind (Kubernetes in Docker) with support for Microsoft Workload Identity. This environment allows developers to test and develop applications that leverage Microsoft's Workload Identity for authentication and authorization in Kubernetes.

## Prerequisites

- Docker Desktop
- kubectl
- Azure CLI
- Azure Developer CLI (azd)

## Quick Start

1. Clone this repository:
   ```
   git clone <repository-url> kind-wi
   cd kind-wi
   ```

2. Provision the environment:
   ```
   azd init -e dev
   azd provision
   ```

3. Verify the cluster is running:
   ```
   export KUBECONFIG=./cluster/kubeconfig/config
   kubectl get nodes
   ```

## Usage

After provisioning the environment with `azd provision`, you can start developing and testing your applications that use Microsoft Workload Identity. The local Kind cluster is configured to work with the Azure AD emulator, allowing you to simulate Azure AD authentication and authorization flows.

To deploy your applications to the cluster, use standard Kubernetes deployment methods with `kubectl`.

## Cleanup

To stop and remove all resources:

```
azd down --force --purge
```
