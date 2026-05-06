# SignificaDevOpsTask

CI/CD Automation για .NET 8 Web API → Docker → Minikube (Kubernetes)

---

## 📁 Δομή Repository

```
SignificaDevOpsTask/
├── src/MyApp/                  # .NET 8 Web API
│   ├── MyApp.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   └── Controllers/
│       └── WeatherForecastController.cs
├── k8s/
│   ├── deployment.yaml         # K8s Deployment + Probes
│   ├── service.yaml            # NodePort Service
│   └── hpa.yaml                # Horizontal Pod Autoscaler
├── Dockerfile                  # Multi-stage build
├── .dockerignore
├── azure-pipelines.yml         # CI/CD Pipeline (3 stages)
└── README.md
```

---

## 🚀 CI/CD Pipeline - azure-pipelines.yml

Το pipeline τρέχει αυτόματα σε κάθε commit στο `main` και έχει **3 stages**:

```
[Build & Test] → [Docker Build & Push] → [Deploy to K8s]
```

### Stage 1 - Build & Test
- Restore NuGet packages
- Build σε Release mode
- Publish artifacts

### Stage 2 - Docker Build & Push
- Build Docker image (multi-stage)
- Tag με `$(Build.BuildId)` + `latest`
- Push στο Docker Hub

### Stage 3 - Deploy to Kubernetes
- Apply `deployment.yaml`, `service.yaml`, `hpa.yaml`
- Αντικαθιστά το image tag με το νέο build ID

### Azure DevOps Service Connections (απαιτούνται)
| Όνομα | Τύπος | Χρήση |
|-------|-------|-------|
| `DockerHubConnection` | Docker Registry | Push image στο Docker Hub |
| `MinikubeConnection` | Kubernetes | Deploy στο Minikube |

---

## 🐳 Docker

### Multi-stage Dockerfile
- **Stage 1** (`sdk:8.0`): Build + Publish του app
- **Stage 2** (`aspnet:8.0`): Μόνο runtime → μικρό image (~200MB)

### Τοπικό build/run
```bash
docker build -t stamanos/myapp:latest .
docker run -p 8080:8080 stamanos/myapp:latest
# Άνοιξε: http://localhost:8080/swagger
```

---

## ☸️ Kubernetes

### Deployment
- **2 replicas** (min) για υψηλή διαθεσιμότητα
- Image: `stamanos/myapp:<buildId>`

### Probes (Zero-downtime rolling updates)
| Probe | Path | Σκοπός |
|-------|------|--------|
| **Startup** | `/health` | Περιμένει το app να ξεκινήσει (max 50s) |
| **Readiness** | `/health` | Βγάζει το pod από το traffic αν δεν είναι έτοιμο |
| **Liveness** | `/health` | Κάνει restart το pod αν κολλήσει |

> Κατά το rolling update: το Readiness Probe διασφαλίζει ότι το νέο pod είναι **πλήρως έτοιμο** πριν κατεβεί το παλιό → zero downtime.

### Service
- Τύπος: `NodePort` (για Minikube)
- Προσβάσιμο στο: `http://<minikube-ip>:30080`

### Horizontal Pod Autoscaler (HPA)
- Min: 2 pods, Max: 5 pods
- Scale up αν **CPU > 70%** ή **Memory > 80%**

### Τοπικό deployment (Minikube)
```bash
minikube start
kubectl apply -f k8s/
kubectl get pods
minikube service myapp-service --url
```

---

## 📊 Monitoring (Task 4)

### Εργαλεία & Stack

**Prometheus + Grafana** (προτεινόμενο για K8s):
- Prometheus: scrapes metrics από τα pods (`/metrics` endpoint)
- Grafana: dashboards για visualization

```bash
# Εγκατάσταση με Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack
```

### KPIs που παρακολουθούμε
| KPI | Εργαλείο | Threshold |
|-----|---------|-----------|
| **Latency** (p95, p99) | Prometheus + Grafana | < 500ms |
| **Error Rate** (5xx) | Prometheus | < 1% |
| **CPU Utilization** | Prometheus / HPA | < 70% |
| **Memory Usage** | Prometheus / HPA | < 80% |
| **Pod Restarts** | Prometheus | 0 |
| **Deployment Frequency** | Azure DevOps Analytics | - |

### Logging
- **Azure Monitor + Log Analytics**: συλλέγει logs από τα K8s pods
- Εναλλακτικά: **ELK Stack** (Elasticsearch + Logstash + Kibana)

---

## 🌍 Bonus: Multi-Region Failover Strategy

### Αρχιτεκτονική

```
                    ┌─────────────────────┐
      Users ──────▶ │  Azure Front Door   │  ← Global Load Balancer
                    │  (DNS + Failover)   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┴─────────────────┐
              ▼                                   ▼
   ┌─────────────────────┐           ┌─────────────────────┐
   │   Region A (Primary)│           │  Region B (Secondary│
   │   AKS Cluster       │           │  AKS Cluster        │
   │   West Europe       │           │  North Europe       │
   └──────────┬──────────┘           └──────────┬──────────┘
              │                                   │
              └──────────────┬────────────────────┘
                             ▼
                  ┌─────────────────────┐
                  │  Azure SQL / CosmosDB│
                  │  Geo-Replication    │
                  └─────────────────────┘
```

### Στρατηγική
- **Azure Front Door**: Global load balancing + automatic failover αν cluster/region αποτύχει
- **Active-Active**: Και τα 2 regions δέχονται traffic ταυτόχρονα
- **Data Replication**: CosmosDB με multi-region writes ή Azure SQL Geo-Replication
- **Health Probes**: Το Front Door ελέγχει `/health` σε κάθε region και αποκλείει αυτόματα unhealthy endpoints