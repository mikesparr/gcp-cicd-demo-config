# Demo Configuration Repo
This repo leverages Argo CD and the App of Apps pattern to allow 
monitoring of specific folders and deploying those configs or workloads
to Kubernetes clusters.

# Structure
- `/apps/` configuration for apps that Argo CD will point to
- `/config/` default k8s configuration
