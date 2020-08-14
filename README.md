# Demo Configuration Repo
This repo leverages Argo CD and the App of Apps pattern to allow 
monitoring of specific folders and deploying those configs or workloads
to Kubernetes clusters.

# Structure
- `app-of-apps.yaml` bootstrapped on k8s server and points to `/apps/` folder
- `/apps/` configuration for app folders that Argo CD will point to
- `/kong/` Kong ingress controller manifests
- `/cert-manager/` Cert Manager manifests
- `/demo-app/` Demo App manifests
  - Namespace
  - Ingress
  - Service
  - Deployment
