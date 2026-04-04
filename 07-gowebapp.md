```bash
# kubectl apply -f manifests/app/
kubectl apply -f manifests/argo/gowebapp-appproject.yaml
kubectl apply -f manifests/argo/gowebapp-app.yaml
```

```bash
#External name service to hold db name
helm repo add gowebapp https://mahinraza.github.io/helm-charts/

helm repo update gowebapp

helm search repo gowebapp --versions

helm install gowebapp gowebapp/gowebapp -n gowebapp --create-namespace

helm uninstall gowebapp -n gowebapp
```

```bash
kubectl apply -f manifests/agro/gowebapp-appproject.yaml
kubectl apply -f manifests/agro/gowebapp-app-helm.yaml
```