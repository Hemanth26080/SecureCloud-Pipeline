# SecureCloud-Flask

> Production-grade, security-hardened Flask application on AWS — built with DevSecOps and SRE best practices.

![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?style=flat&logo=jenkins&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Hardened-2496ED?style=flat&logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=flat&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-eu--west--3-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-0%20CVEs-1904DA?style=flat&logo=aquasecurity&logoColor=white)
![SonarQube](https://img.shields.io/badge/SonarQube-Quality%20Gate%20Passed-4E9BCD?style=flat&logo=sonarqube&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

---

## What This Project Demonstrates

This is a portfolio-grade project targeting **DevSecOps Engineer**, **SRE**, and **Cloud Engineer** roles in the French and EU tech market. It shows end-to-end ownership of a system — from writing secure application code to provisioning cloud infrastructure to running automated security scans in a CI/CD pipeline.

**Key proof points:**
- 9-stage Jenkins pipeline with automated security gates
- 0 HIGH/CRITICAL CVEs in the production Docker image (Trivy verified)
- Zero hardcoded credentials — AWS Secrets Manager with 30-day auto-rotation
- All AWS infrastructure provisioned as code with Terraform
- SonarQube Quality Gate enforced on every commit
- Live Prometheus + Grafana observability with alerting rules

---

## Architecture

```
[Developer Laptop]
       │
       ▼
[GitHub] ──► PR/push trigger
       │
       ▼
[Jenkins CI/CD — Docker]
       │
       ├──► Lint (flake8) + SAST (bandit + SonarQube)
       ├──► Unit Tests (pytest + coverage)
       ├──► Docker Build (multi-stage, non-root)
       ├──► Image Scan (Trivy — blocks on HIGH/CRITICAL)
       ├──► Deploy to Staging (Terraform)
       ├──► Manual Approval Gate
       └──► Deploy to Production (Terraform)

[AWS — eu-west-3 Paris]
       │
       ├── VPC
       │   ├── Public Subnet  → ALB (internet-facing)
       │   ├── Private Subnet → Flask App (EC2/ECS)
       │   └── Private Subnet → MySQL RDS (never public)
       │
       ├── Security
       │   ├── AWS Secrets Manager (DB credentials, auto-rotated)
       │   ├── IAM Roles (EC2 instance profile, no static keys)
       │   ├── Security Groups (least-privilege, ALB→App→DB only)
       │   └── RDS encryption at rest (AWS KMS)
       │
       └── Observability
           ├── Prometheus (scrapes /metrics every 15s)
           ├── Grafana (dashboards + alerting)
           ├── Loki + Promtail (centralised logs)
           └── Alertmanager (Slack alerts on error rate / downtime)
```

---

## Tech Stack

| Category | Tools | Purpose |
|---|---|---|
| **Application** | Python 3.11, Flask 3.x | REST API with /health, /ready, /metrics endpoints |
| **Containerisation** | Docker (multi-stage), Docker Compose | Secure, minimal runtime image |
| **CI/CD** | Jenkins LTS, Pipeline-as-Code | 9-stage automated pipeline |
| **Infrastructure as Code** | Terraform 1.6+ | VPC, subnets, security groups, RDS |
| **Cloud** | AWS (VPC, RDS, Secrets Manager, IAM, ECR) | Production cloud infrastructure |
| **Security Scanning** | Trivy (images + filesystem), bandit, flake8 | Shift-left vulnerability detection |
| **Code Quality** | SonarQube 10 Community | SAST, quality gate, coverage enforcement |
| **Secrets Management** | AWS Secrets Manager | Zero hardcoded credentials, auto-rotation |
| **Observability** | Prometheus, Grafana, Loki, Promtail, Alertmanager | Metrics, logs, dashboards, alerts |
| **Testing** | pytest, pytest-cov | Unit tests with coverage reporting |

---

## Security Controls

| Control | Implementation | Verified By |
|---|---|---|
| **No hardcoded secrets** | All credentials fetched from AWS Secrets Manager at runtime | Trivy secret scan — 0 findings |
| **Image hardening** | Multi-stage Dockerfile, non-root user (UID 1001), minimal base | Trivy image scan — 0 HIGH/CRITICAL CVEs |
| **Code security** | bandit SAST + SonarQube quality gate on every build | Jenkins pipeline gate — blocks merge on failure |
| **Network isolation** | Flask in private subnet, DB in private subnet, no public DB access | Terraform security groups — port 3306 only from app SG |
| **Credential rotation** | Secrets Manager auto-rotates DB password every 30 days | AWS Console — rotation enabled |
| **Least-privilege IAM** | EC2 instance profile with only `secretsmanager:GetSecretValue` | IAM policy — scoped to `securecloud/*` only |
| **Encryption at rest** | RDS storage encrypted with AWS KMS | AWS Console — encryption: enabled |
| **Unfixable CVE tracking** | `.trivyignore` documents suppressed CVEs with justification and review dates | Peer review on PRs |

---

## CI/CD Pipeline

The Jenkins pipeline runs automatically on every push to `main`. All stages must pass before code reaches production.

```
Checkout SCM
     │
     ▼
Lint & Security Scan          ← flake8 + bandit
     │
     ▼
SonarQube Analysis            ← quality gate must pass
     │
     ▼
Unit Tests                    ← pytest, coverage report archived
     │
     ▼
Build Docker Image            ← multi-stage Dockerfile
     │
     ▼
Scan Docker Image             ← Trivy: exits 1 on HIGH/CRITICAL
     │
     ▼
Deploy to Staging             ← terraform apply (staging workspace)
     │
     ▼
Integration Tests
     │
     ▼
Manual Approval Gate          ← human click required
     │
     ▼
Deploy to Production          ← terraform apply (prod workspace)
     │
     ▼
Health Check                  ← curl /health — must return 200
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Liveness probe — returns `{"status": "healthy"}` |
| GET | `/ready` | Readiness probe — returns `{"status": "ready"}` |
| GET | `/metrics` | Prometheus metrics (request count, latency, DB pool) |
| GET | `/` | Root — returns service info |
| GET | `/api/users` | Example data endpoint |

---

## Quick Start (Local Development)

**Prerequisites:** Docker Desktop, Git

```bash
# 1. Clone the repo
git clone https://github.com/Hemanth26080/SecureCloud-Pipeline.git
cd SecureCloud-Pipeline

# 2. Start Flask app + MySQL with Docker Compose
docker-compose -f docker/docker-compose.dev.yml up --build

# 3. Verify the app is running (new terminal)
curl http://localhost:5000/health
# Expected: {"status": "healthy", "service": "securecloud-flask"}

curl http://localhost:5000/metrics
# Expected: Prometheus metrics output

# 4. Run unit tests
pip install -r requirements.txt pytest pytest-cov
pytest tests/unit/ -v --cov=app

# 5. Run Trivy security scan
docker build -t securecloud-flask:test -f docker/Dockerfile .
trivy image --severity HIGH,CRITICAL --ignorefile .trivyignore securecloud-flask:test
# Expected: Total: 0 (HIGH: 0, CRITICAL: 0)

# 6. Stop everything
docker-compose -f docker/docker-compose.dev.yml down
```

---

## Project Structure

```
SecureCloud-Pipeline/
├── app/
│   ├── __init__.py
│   ├── main.py               # Flask routes (/health, /ready, /metrics, /api/users)
│   └── db.py                 # MySQL connection pool + Secrets Manager integration
│
├── docker/
│   ├── Dockerfile            # Multi-stage, non-root, healthcheck
│   ├── docker-compose.dev.yml       # Local dev: Flask + MySQL
│   ├── docker-compose.jenkins.yml   # Jenkins CI server
│   └── docker-compose.sonar.yml     # SonarQube + Postgres
│
├── infra/terraform/
│   ├── providers.tf          # AWS provider + S3 backend
│   ├── variables.tf          # Input variables
│   ├── main.tf               # Module wiring
│   ├── outputs.tf            # VPC ID, DB endpoint
│   └── modules/
│       ├── vpc/              # VPC, subnets, IGW, NAT, route tables
│       ├── security/         # Security groups + IAM role + instance profile
│       └── database/         # RDS MySQL (encrypted, Multi-AZ ready)
│
├── observability/
│   ├── prometheus.yml        # Scrape config (Flask, Node Exporter)
│   ├── alerting-rules.yml    # FlaskAppDown, HighErrorRate, DiskSpaceLow
│   ├── alertmanager.yml      # Slack notification routing
│   ├── promtail.yml          # Log shipping to Loki
│   └── docker-compose.observability.yml
│
├── tests/
│   ├── unit/
│   │   └── test_routes.py    # /health, /ready, /api/users — 4 tests
│   └── integration/          # Placeholder for staging tests
│
├── Jenkinsfile               # 9-stage pipeline definition
├── requirements.txt          # Python dependencies (pinned versions)
├── sonar-project.properties  # SonarQube project config
├── .trivyignore              # Documented CVE suppressions
├── .gitignore                # Excludes .env, .tfstate, credentials
├── SECURITY.md               # Threat model and security controls
└── RUNBOOK.md                # Deployment, rollback, incident response
```

---

## AWS Infrastructure

Provisioned with Terraform in `eu-west-3` (Paris region).

```bash
# Initialise
cd infra/terraform
terraform init
terraform workspace new staging

# Preview
terraform plan -var="environment=staging" -var="aws_region=eu-west-3"

# Apply
terraform apply -var="environment=staging" -var="aws_region=eu-west-3"

# Destroy (to stop all costs)
terraform destroy -var="environment=staging" -var="aws_region=eu-west-3"
```

**Resources created:**
- VPC with public + private subnets across 2 AZs
- Internet Gateway + NAT Gateway
- Security groups (ALB → App port 5000, App → DB port 3306 only)
- RDS MySQL 8.0 (db.t3.micro, encrypted, private subnet)
- IAM role + instance profile (read `securecloud/*` secrets only)

---

## Observability

```bash
# Start the full observability stack
cd observability
docker-compose -f docker-compose.observability.yml up -d
```

| Service | URL | Credentials |
|---|---|---|
| Prometheus | http://localhost:9090 | None |
| Grafana | http://localhost:3000 | admin / securepassword |
| Alertmanager | http://localhost:9093 | None |
| Loki | http://localhost:3100 | None |

**Grafana dashboards to import:**
- ID `11159` — Flask application metrics (requests, latency, errors)
- ID `1860` — Node Exporter (CPU, RAM, disk)

**Alerting rules configured:**
- `FlaskAppDown` — app unreachable for > 1 min → CRITICAL
- `HighErrorRate` — > 10% 5xx responses → CRITICAL
- `HighResponseTime` — p95 latency > 2s → WARNING
- `DiskSpaceLow` — < 10% disk free → WARNING

---

## Success Metrics

| Metric | Target | Actual |
|---|---|---|
| CVEs in prod image | 0 HIGH/CRITICAL | 0 ✅ |
| SonarQube quality gate | PASSED | PASSED ✅ |
| Unit test coverage | ≥ 80% | Measured per build |
| Pipeline duration | < 10 min | ~8 min |
| Secrets in codebase | 0 | 0 ✅ |

---

## Author

**Hemanth Ponugothi**
- GitHub: [@Hemanth26080](https://github.com/Hemanth26080)
- LinkedIn: [linkedin.com/in/your-profile](https://www.linkedin.com/in/hemanth260800/)

*Built as a portfolio project targeting DevSecOps Engineer, SRE, and Cloud Engineer roles in France and the EU.*

---

## License

MIT — see [LICENSE](LICENSE) for details.