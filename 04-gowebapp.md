```bash
kubectl apply -f manifests/app/
```

```bash
#External name service to hold db name
helm repo add gowebapp https://mahinraza.github.io/gowebapp-config

helm repo update gowebapp

helm install gowebapp gowebapp/gowebapp -n gowebapp --create-namespace
```