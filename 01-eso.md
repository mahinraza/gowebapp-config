```bash
helm repo add external-secrets https://charts.external-secrets.io

helm repo ls

helm repo update

helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --version 2.1.0 \
    --set installCRDs=true

helm list -n external-secrets

kubectl get all -n external-secrets

kubectl get crd | grep external-secrets
```