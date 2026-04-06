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

# Install ESO with IRSA role
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw eso_role_arn) \
    --set installCRDs=true

helm list -n external-secrets

kubectl get all -n external-secrets

kubectl get crd | grep external-secrets
```