```bash
# Add the official Argo CD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm

# Verify that the repository was added successfully
helm repo list

# Similar to `apt update`, refreshes local cache of chart versions from all added Helm repositories
helm repo update

# Search for Argo-related charts across all added repositories
helm search repo argo

# List available versions of the official Argo CD Helm chart
helm search repo argo/argo-cd --versions

kubectl create ns argocd

helm install my-argo-cd argo/argo-cd \
  --version 9.1.9 \
  -n argocd 

helm ls -n argocd

kubectl get all -n argocd

kubectl get svc -n argocd

kubectl port-forward service/my-argo-cd-argocd-server -n argocd 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

argocd login localhost:8080

argocd repo add https://github.com/mahinraza/gowebapp-config.git \
  --name gowebapp-config-repo \
  --username mahinraza \
  --password <your github pat token>
```
```bash
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```