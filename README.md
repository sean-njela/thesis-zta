# 🧱 Quarkus + Istio Zero Trust Demo (FULL Setup Guide)

> ✅ Build a microservices architecture using Zero Trust principles
> 💡 Based on [https://github.com/jonathanvila/quarkus-simple-rest](https://github.com/jonathanvila/quarkus-simple-rest)


## 🧰 Step 0: Prerequisites

Make sure the following are installed on your host system:

* [Docker](https://www.docker.com/products/docker-desktop/)
* [Devbox](https://www.jetpack.io/devbox/docs/install/)
* [Git](https://git-scm.com/downloads)


## 📦 Step 1: Clone the Project

```bash
git clone https://github.com/jonathanvila/quarkus-simple-rest.git
cd quarkus-simple-rest
```


## 🧪 Step 2: Create the Devbox Environment

### 2.1 Create `devbox.json`

```json
{
  "packages": [
    "docker",
    "kubectl",
    "kind",
    "istioctl",
    "maven",
    "openjdk17",
    "jq",
    "task"
  ],
  "shell": {
    "init_hook": [
      "export PATH=$HOME/.istioctl/bin:$PATH"
    ]
  }
}
```

### 2.2 Launch Devbox Shell

```bash
devbox shell
```

This installs all required tools inside an isolated shell environment.


## 🔧 Step 3: Set Up Dockerized Keycloak (Single Sign-On)

### 3.1 Create `docker-compose.yaml`

```yaml
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:22.0.5
    command: start-dev
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=admin
      - KC_DB=dev-mem
    ports:
      - "8080:8080"
```

### 3.2 Start Keycloak

```bash
docker-compose up -d
```

🔓 Access Keycloak Admin at: [http://localhost:8080](http://localhost:8080)
🧑‍💼 Login: `admin` / `admin`



## 🛠 Step 4: Automate Everything with Taskfile

### 4.1 Create `Taskfile.yml`

```yaml
version: '3'

tasks:
  setup:cluster:
    cmds:
      - kind create cluster --name zta-demo
      - istioctl install --set profile=demo -y
      - kubectl label namespace default istio-injection=enabled --overwrite

  deploy:services:
    cmds:
      - ./mvnw clean install -Dquarkus.container-image.build=true
      - ./mvnw -Dquarkus.kubernetes.deploy=true

  apply:istio-config:
    cmds:
      - kubectl apply -f src/main/k8s/gateway.yml
      - kubectl apply -f src/main/k8s/virtualsvc.yml
      - kubectl apply -f src/main/k8s/authn.yml
      - kubectl apply -f src/main/k8s/authz.yml

  apply:observability:
    cmds:
      - kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/prometheus.yaml
      - kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/jaeger.yaml
      - kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/grafana.yaml
      - kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/kiali.yaml

  port:kiali:
    cmds:
      - kubectl port-forward svc/kiali 20001:20001 -n istio-system

  clean:
    cmds:
      - kind delete cluster
      - docker-compose down
```

## 🚀 Step 5: Launch the Stack

### 5.1 Start Kubernetes Cluster with Istio

```bash
task setup:cluster
```

### 5.2 Build and Deploy Quarkus Microservice

```bash
task deploy:services
```

### 5.3 Apply Istio ZTA Config

```bash
task apply:istio-config
```

### 5.4 Enable Observability Dashboards

```bash
task apply:observability
```


## 🔐 Step 6: Fetch a JWT Access Token

### 6.1 Create `get-token.sh`

```bash
#!/bin/bash
CLIENT_ID=istio
USERNAME=admin
PASSWORD=admin
REALM=quarkus-demo
AUTH_URL="http://localhost:8080/realms/$REALM/protocol/openid-connect/token"

curl -s -X POST \
  -d "client_id=$CLIENT_ID" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "grant_type=password" \
  "$AUTH_URL" | jq -r .access_token
```

Make it executable:

```bash
chmod +x get-token.sh
```

### 6.2 Use the Token to Call a Secure Endpoint

```bash
TOKEN=$(./get-token.sh)
curl -H "Authorization: Bearer $TOKEN" http://localhost:31591/echo/secure
```


## 📊 Step 7: Access Observability Tools

Run:

```bash
task port:kiali
```

* Kiali: [http://localhost:20001](http://localhost:20001)
* Jaeger: `kubectl port-forward svc/jaeger-query 16686:16686 -n istio-system`
* Grafana: `kubectl port-forward svc/grafana 3000:3000 -n istio-system`



## 🔁 Step 8: Test Load & Performance (Optional)

Install Apache Bench (`ab`) and run:

```bash
ab -n 500 -c 20 http://localhost:31591/echo/loadtest
```


## 🧹 Step 9: Clean Everything

```bash
task clean
```


## 📁 Directory Structure (Final)

```
quarkus-simple-rest/
├── devbox.json
├── Taskfile.yml
├── docker-compose.yaml
├── get-token.sh
├── src/
│   └── main/k8s/
│       ├── gateway.yml
│       ├── authn.yml
│       ├── authz.yml
│       ├── virtualsvc.yml
...
```


## 📌 Final Notes

> ✅ You now have a full **Zero Trust demo** stack:

* AuthN/AuthZ via Keycloak + Istio
* mTLS + Envoy Sidecars
* Observability via Grafana, Kiali, Jaeger
* Repeatable setup via Devbox + Task
