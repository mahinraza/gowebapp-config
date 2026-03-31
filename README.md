```bash
# Add Percona Helm repo
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

# Install the operator
helm install percona-operator percona/pxc-operator \
  --namespace mysql-operator \
  --create-namespace

# Verify
kubectl get pods -n mysql-operator
```
```bash
helm repo add gowebapp https://mahinraza.github.io/gowebapp-config

helm repo update gowebapp

helm install gowebapp gowebapp/gowebapp -n gowebapp --create-namespace
```