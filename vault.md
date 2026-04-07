```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/sbin/   

sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo chmod 777 /var/run/docker.sock

cat << EOF | docker compose -f - up -d
services:
  vault:
    image: registry.hub.docker.com/hashicorp/vault:1.19
    container_name: vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=root
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
      - VAULT_ADDR=http://127.0.0.1:8200      # ← add this
      - VAULT_TOKEN=root                       # ← add this
    cap_add:
      - IPC_LOCK
    command: server -dev
EOF

#OR

docker run -d --name vault --cap-add=IPC_LOCK -p 8200:8200 -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 hashicorp/vault:1.19.0 server -dev

# Check container status
docker ps | grep vault

# Check Vault status
curl http://localhost:8200/v1/sys/health

# Or access Vault UI
# Open browser to: http://localhost:8200
# Token: root

# View logs
docker logs vault

# Execute commands inside vault
# docker exec -it vault \
#   env VAULT_ADDR='http://127.0.0.1:8200' \
#   vault status

docker exec -it vault vault status

docker exec -it vault  sh

#OR
# If you want to use vault CLI from your HOST
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

vault status

export VAULT_IP='43.204.237.206'
export VAULT_ADDR="http://${VAULT_IP}:8200"
vault status

# Create namespace if not exists
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

cat << EOF > endpoint-slice.yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: vault-external
  namespace: external-secrets
  labels:
    kubernetes.io/service-name: vault-external  # Important: links to service
    app: vault
    component: external
addressType: IPv4
endpoints:
- addresses:
  - "${VAULT_IP}"  # Your Vault IP
  conditions:
    ready: true
    serving: true
    terminating: false
  # Optional: Add node name if you have it
  # nodeName: your-node-name
  # Optional: Add targetRef for ownership
  # targetRef:
  #   kind: Service
  #   name: vault-external
  #   namespace: database
ports:
- name: vault
  port: 8200
  protocol: TCP
EOF

cat << EOF > headless-service.yaml
# Create headless service with endpoints
apiVersion: v1
kind: Service
metadata:
  name: vault-external
  namespace: external-secrets
  labels:
    app: vault
    component: external
spec:
  type: ClusterIP
  clusterIP: None  # Headless service
  ports:
  - port: 8200
    targetPort: 8200
    protocol: TCP
    name: vault
EOF

kubectl apply -f endpoint-slice.yaml
kubectl apply -f headless-service.yaml

# List EndpointSlices
kubectl get endpointslices -n external-secrets

# Describe the EndpointSlice
kubectl describe endpointslices vault-external -n external-secrets

# Check details
kubectl get endpointslices vault-external -n external-secrets -o yaml

# Check service details
kubectl describe svc vault-external -n external-secrets

# You should see the endpoints reflected
kubectl get svc vault-external -n external-secrets

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n external-secrets -- \
  nslookup vault-external.external-secrets.svc.cluster.local

# Test connectivity via service
kubectl run -it --rm test-vault \
  --image=curlimages/curl \
  --restart=Never \
  -n external-secrets \
  -- curl -k -s http://vault-external.external-secrets.svc.cluster.local:8200/v1/sys/health

# Or test directly with IP
kubectl run -it --rm test-vault \
  --image=curlimages/curl \
  --restart=Never \
  -n external-secrets \
  -- curl -k -s http://${VAULT_IP}:8200/v1/sys/health


# Enable KV secrets engine 
vault secrets enable -path=kv kv-v2

vault secrets list -detailed

# If version=1 was enabled by mistake:
# vault secrets disable kv/
# vault secrets enable -path=kv kv-v2

# Store ROOT credentials (for admin tasks)
vault kv put kv/prod/do/database/mysql/root_cred \
  username="<MASTER_USER>" \
  password="<MASTER_USER_PASSWORD>"

# Store APPLICATION credentials (for the app to use)
vault kv put kv/prod/gowebapp/database/app_cred \
  username="<APP_USER>" \
  password="<APP_USER_PASSWORD>" \
  database="<APP_DATABASE>" \
  session-secret-key="<SECRET_SESSION_KEY>"

vault kv put kv/prod/do/database/mysql/endpoint \
  host="mysql-external-service.gowebapp.svc.cluster.local" \
  port=25060

# Verify both secrets
vault kv get kv/prod/do/database/mysql/root_cred
vault kv get kv/prod/gowebapp/database/app_cred
vault kv get kv/prod/do/database/mysql/endpoint

# Enable AppRole auth if not already enabled
vault auth enable approle

vault auth list

# Create policy
vault policy write gowebapp-policy - <<EOF
# Allow reading root credentials (for init job)
path "kv/data/prod/do/database/mysql/root_cred" {
  capabilities = ["read"]
}

# Allow reading app credentials (for application)
path "kv/data/prod/gowebapp/database/app_cred" {
  capabilities = ["read"]
}

# Allow reading endpoint
path "kv/data/prod/do/database/mysql/endpoint" {
  capabilities = ["read"]
}

# Allow listing metadata for these paths
path "kv/metadata/prod/do/database/mysql/root_cred" {
  capabilities = ["read", "list"]
}

path "kv/metadata/prod/gowebapp/database/app_cred" {
  capabilities = ["read", "list"]
}

path "kv/metadata/prod/do/database/mysql/endpoint" {
  capabilities = ["read", "list"]
}
EOF

# Verify policy
vault policy read gowebapp-policy

# Create role
vault write auth/approle/role/gowebapp-role \
  token_policies="gowebapp-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=720h \
  secret_id_num_uses=0

# Verify role created
vault read auth/approle/role/gowebapp-role

export ROLE_ID="$(vault read -field=role_id auth/approle/role/gowebapp-role/role-id)"
echo $ROLE_ID

export SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/gowebapp-role/secret-id)"
echo $SECRET_ID

vault write auth/approle/login \
  role_id="${ROLE_ID}" \
  secret_id="${SECRET_ID}"

export VAULT_TOKEN="s.xxxxxxxxxxxx"

vault kv get kv/prod/do/database/mysql/root
vault kv get kv/prod/gowebapp/database/app

# Test that policy blocks other paths
# vault kv get gowebapp/admin/secrets
# Error: permission denied ✅ (blocked correctly)

# Create secrets for AppRole credentials
kubectl create secret generic vault-gowebapp-roleid \
  --namespace external-secrets \
  --from-literal=role_id="$ROLE_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic vault-gowebapp-secretid \
  --namespace external-secrets \
  --from-literal=secret_id="$SECRET_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl get secrets -n external-secrets | grep vault-gowebapp

cat << EOF > gowebapp-secret-store.yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: vault-gowebapp-store
spec:
  provider:
    vault:
      # Using the headless service DNS name
      server: "http://vault-external.external-secrets.svc.cluster.local:8200"
      path: "kv"
      version: "v2"
      # If using self-signed certificates, you might need to skip verification
      # skipTLSVerify: true
      # Or provide CA certificate
      # caProvider:
      #   type: "Secret"
      #   name: "vault-ca-cert"
      #   namespace: "database"
      #   key: "ca.crt"
      auth:
        appRole:
          path: "approle"
          roleRef:
            name: "vault-gowebapp-roleid"
            namespace: "external-secrets"
            key: "role_id"
          secretRef:
            name: "vault-gowebapp-secretid"
            namespace: "external-secrets"
            key: "secret_id"
EOF

kubectl apply -f gowebapp-secret-store.yaml

# Stop and remove container
docker stop vault && docker rm vault

# Or force remove
docker rm -f vault
```
