
# 🧱 Quarkus + Istio Zero Trust Demo (FULL Setup Guide)

[![Built with Devbox](https://www.jetify.com/img/devbox/shield_moon.svg)](https://www.jetify.com/devbox/docs/contributor-quickstart/)

> ✅ Build a microservices architecture using Zero Trust principles
> 💡 Based on [https://github.com/jonathanvila/quarkus-simple-rest](https://github.com/jonathanvila/quarkus-simple-rest)

---

## 🧰 Step 0: Prerequisites

Make sure the following are installed:

* [Docker](https://docs.docker.com/engine/install/)
* [Devbox](https://jetify-com.vercel.app/docs/devbox/installing_devbox)
* [Git](https://git-scm.com/downloads)

---

## 📦 Step 1: Clone the Project

```bash
git clone https://github.com/jonathanvila/quarkus-simple-rest.git
cd quarkus-simple-rest
```

---

## 🧪 Step 2: Devbox Environment Setup

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
    "task",
    "xdg-utils"
  ]
}
```

### 2.2 Enter Devbox Shell

```bash
devbox shell
```

---

## 🔐 Step 3: Keycloak (Authentication)

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

🧑‍💼 Admin login: `admin` / `admin`
🌐 Access: [http://localhost:8080](http://localhost:8080)

---

## 🛠 Step 4: Taskfile Automation

### 4.1 Create Taskfile.yml
```yaml
version: '3'

tasks:
  setup:cluster:
    cmds:
      - kind create cluster --name zta-demo --image kindest/node:v1.26.3
      - istioctl install --set profile=demo -y
      - kubectl label namespace default istio-injection=enabled --overwrite

  build:services:
    cmds:
      - ./mvnw clean package -Dquarkus.kubernetes.deploy=false

  deploy:services:
    deps: [build:services]
    cmds:
      - kubectl apply -f target/kubernetes/kubernetes.yml

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

  wait:kiali:
    cmds:
      - until kubectl get pods -n istio-system | grep kiali | grep Running; do echo "⏳ Waiting for Kiali..."; sleep 5; done

  wait:grafana:
    cmds:
      - until kubectl get pods -n istio-system | grep grafana | grep Running; do echo "⏳ Waiting for Grafana..."; sleep 5; done

  wait:jaeger:
    cmds:
      - until kubectl get pods -n istio-system | grep jaeger | grep Running; do echo "⏳ Waiting for Jaeger..."; sleep 5; done

  wait:all-observability:
    cmds:
      - task wait:kiali
      - task wait:grafana
      - task wait:jaeger

  port:kiali:
    deps: [wait:kiali]
    cmds:
      - kubectl port-forward svc/kiali 20001:20001 -n istio-system

  port:grafana:
    deps: [wait:grafana]
    cmds:
      - kubectl port-forward svc/grafana 3000:3000 -n istio-system

  port:jaeger:
    deps: [wait:jaeger]
    cmds:
      - kubectl port-forward svc/jaeger-query 16686:16686 -n istio-system

  open:dashboards:
    deps: [wait:all-observability]
    cmds:
      - echo "🔌 Port forwarding for dashboards..."
      - kubectl port-forward svc/kiali 20001:20001 -n istio-system & disown
      - kubectl port-forward svc/grafana 3000:3000 -n istio-system & disown
      - kubectl port-forward svc/jaeger-query 16686:16686 -n istio-system & disown
      - sleep 3
      - |
        BROWSER_CMD="${BROWSER:-$(command -v firefox || command -v google-chrome || command -v chromium || command -v brave || echo '')}"
        if [ -z "$BROWSER_CMD" ]; then
          echo "⚠️ No supported browser found. Please open manually:"
          echo "  http://localhost:20001 (Kiali)"
          echo "  http://localhost:3000 (Grafana)"
          echo "  http://localhost:16686 (Jaeger)"
        else
          echo "🌐 Opening dashboards in $BROWSER_CMD..."
          $BROWSER_CMD http://localhost:20001 &
          $BROWSER_CMD http://localhost:3000 &
          $BROWSER_CMD http://localhost:16686 &
        fi

  clean:
    cmds:
      - kind delete cluster
      - docker-compose down
```
> You can extend the Taskfile by adding test: or status: tasks for health checks or CI/CD integration.
### 4.1 Core Commands

```bash
task setup:cluster         # Start Kind cluster and install Istio
task deploy:services       # Build and manually deploy Quarkus service
task apply:istio-config    # Apply Istio ZTA security policies
task apply:observability   # Deploy Prometheus, Grafana, Jaeger, Kiali
task open:dashboards       # Wait, port-forward, and open observability UIs
```

---

## 🔐 Step 5: Get Access Token

### 5.1 Create `get-token.sh`

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

### 5.2 Call a Secure Endpoint

```bash
TOKEN=$(./get-token.sh)
curl -H "Authorization: Bearer $TOKEN" http://localhost:31591/echo/secure
```

---

## 📊 Step 6: Open Observability Dashboards

```bash
task open:dashboards
```

This:

* Waits for Kiali, Grafana, Jaeger pods to be ready
* Port-forwards each dashboard
* Launches your default browser (with BROWSER override support)

💡 If no browser is found, the task prints manual URLs.

---

## 🧪 Step 7: Load Testing (Optional)

```bash
ab -n 500 -c 20 http://localhost:31591/echo/loadtest
```

Requires `apache2-utils` or equivalent.

---

## 🧹 Step 8: Clean Everything

```bash
task clean
```

Shuts down Kind cluster and Keycloak.

---

## 📁 Directory Structure

```
quarkus-simple-rest/
├── devbox.json
├── Taskfile.yml
├── docker-compose.yaml
├── get-token.sh
├── src/main/k8s/
│   ├── gateway.yml
│   ├── virtualsvc.yml
│   ├── authn.yml
│   ├── authz.yml
```

---


## ✅ Best Practices Included

* 🧪 Manual `kubectl` deploy avoids Fabric8 incompatibilities
* 🛠 Portability via Devbox and Taskfile automation
* 🔐 Zero Trust enforced with Istio (AuthN/AuthZ + mTLS)
* 📈 Visual insight using Kiali, Jaeger, Grafana
* 💡 Safe browser logic (`BROWSER`, fallback, or manual links)
* 🔁 CI-friendly and developer-friendly repeatability
