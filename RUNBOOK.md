# Runbook — SecureCloud-Flask

This runbook covers deployment, rollback, incident response, and common operational procedures for SecureCloud-Flask. It is written for an on-call engineer who may not be familiar with the system.

**Quick links:**
- App health: `http://YOUR-ALB-DNS/health`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Alertmanager: `http://localhost:9093`
- Jenkins: `http://localhost:8080`
- SonarQube: `http://localhost:9000`
- GitHub: `https://github.com/Hemanth26080/SecureCloud-Pipeline`

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Deployment — Normal Release](#2-deployment--normal-release)
3. [Rollback Procedure](#3-rollback-procedure)
4. [Incident Response](#4-incident-response)
5. [Alert Playbooks](#5-alert-playbooks)
6. [Database Operations](#6-database-operations)
7. [Secrets Rotation](#7-secrets-rotation)
8. [Scaling](#8-scaling)
9. [Destroy / Shutdown](#9-destroy--shutdown)
10. [Common Errors and Fixes](#10-common-errors-and-fixes)
11. [Contacts](#11-contacts)

---

## 1. System Overview

```
Internet → ALB (public subnet)
              → Flask App on EC2/ECS (private subnet, port 5000)
                    → MySQL RDS (private subnet, port 3306)
                    → AWS Secrets Manager (VPC endpoint)
                    → Prometheus /metrics scrape
```

**Environments:**

| Environment | AWS Workspace | Branch | Approval Required |
|---|---|---|---|
| Staging | `staging` | `main` (auto) | No |
| Production | `prod` | `main` (manual gate) | Yes — Jenkins input step |

**Key file locations:**

| What | Where |
|---|---|
| App code | `app/main.py`, `app/db.py` |
| Dockerfile | `docker/Dockerfile` |
| Pipeline | `Jenkinsfile` |
| Infrastructure | `infra/terraform/` |
| Alerting rules | `observability/alerting-rules.yml` |
| Credentials | AWS Secrets Manager — `securecloud/db-credentials` |

---

## 2. Deployment — Normal Release

A normal release happens automatically when code is merged to `main`. No manual steps needed for staging. Production requires one human approval click in Jenkins.

### Automatic path (staging)

```
Developer pushes to main
         │
         ▼
Jenkins detects push (within 30 seconds)
         │
         ▼
Pipeline runs all stages automatically
         │
         ▼
Staging updated — check http://STAGING-ALB/health
```

### Manual steps for production

1. Watch the Jenkins build at `http://localhost:8080`
2. Wait for all stages to go green up to **"Approve Production?"**
3. Jenkins pauses and waits — click **"Proceed"** to deploy to prod
4. Watch the **Deploy to Production** and **Health Check** stages
5. Verify production health:

```bash
curl -f https://YOUR-PROD-DOMAIN/health
# Expected: {"status": "healthy", "service": "securecloud-flask"}
```

### Verify deployment succeeded

```bash
# Check the app is responding
curl http://YOUR-ALB-DNS/health
curl http://YOUR-ALB-DNS/ready
curl http://YOUR-ALB-DNS/metrics | head -20

# Check Prometheus is scraping the new version
# Go to http://localhost:9090/targets
# flask-app should show State: UP

# Check Grafana for traffic spike after deploy
# Go to http://localhost:3000 — request rate graph should show activity
```

### If the pipeline fails

Check which stage failed in Jenkins → click the stage → read the logs → search this runbook for that stage name in [Section 10](#10-common-errors-and-fixes).

---

## 3. Rollback Procedure

Use this when a bad deployment reaches production and you need to revert fast.

### Option A — Docker image rollback (fastest, < 5 minutes)

Every build produces an image tagged with the Jenkins `BUILD_NUMBER`. Roll back by redeploying a previous tag.

```bash
# List recent image tags in ECR
aws ecr describe-images \
  --repository-name securecloud-flask \
  --region eu-west-3 \
  --query 'sort_by(imageDetails, &imagePushedAt)[-10:].imageTags' \
  --output table

# Redeploy a previous build (replace 42 with the last known good build number)
GOOD_BUILD=42
aws ecs update-service \
  --cluster securecloud-cluster \
  --service securecloud-flask \
  --force-new-deployment \
  --region eu-west-3
```

### Option B — Terraform rollback (if infrastructure changed)

```bash
cd infra/terraform
terraform workspace select prod

# See what changed in the bad apply
terraform plan -var="environment=prod" -var="aws_region=eu-west-3"

# Roll back specific resource (example: ECS task definition)
terraform apply \
  -target=aws_ecs_task_definition.app \
  -var="image_tag=42" \
  -var="environment=prod" \
  -var="aws_region=eu-west-3"
```

### Option C — Git revert (if bad code was merged)

```bash
# Find the last good commit
git log --oneline -10

# Revert the bad commit (creates a new revert commit — safe for shared branches)
git revert HEAD
git push origin main

# Jenkins will auto-trigger and redeploy the reverted code
```

### After any rollback

```bash
# Confirm the app is healthy again
curl -f http://YOUR-ALB-DNS/health

# Check error rate dropped in Grafana
# http://localhost:3000 — HighErrorRate alert should resolve within 5 minutes

# Write a post-incident note (see Section 4)
```

---

## 4. Incident Response

### Severity levels

| Level | Definition | Response Time | Example |
|---|---|---|---|
| P1 — Critical | Production down, data loss risk | Immediately | App returning 500 on all requests |
| P2 — High | Degraded performance, partial outage | 15 minutes | Error rate > 10%, DB connections failing |
| P3 — Medium | Non-critical feature broken | 1 hour | Single endpoint returning errors |
| P4 — Low | Minor issue, no user impact | Next business day | Disk space warning, slow query |

### Incident response steps

**Step 1 — Detect**
Prometheus/Alertmanager fires a Slack alert, or a user reports an issue.

**Step 2 — Assess**
```bash
# Is the app up?
curl -f http://YOUR-ALB-DNS/health
echo "Exit code: $?"   # 0 = up, non-zero = down

# What does Prometheus say?
# Go to http://localhost:9090
# Query: up{job="flask-app"}
# 1 = up, 0 = down

# Check recent logs
docker logs securecloud-app --tail 100

# Check error rate
# Prometheus query: rate(flask_http_request_total{status=~"5.."}[5m])
```

**Step 3 — Communicate**
Post in `#incidents` Slack channel:
```
INCIDENT STARTED — [P1/P2/P3]
Time: HH:MM UTC
Impact: [what is broken, who is affected]
Investigating: [your name]
```

**Step 4 — Mitigate**
Choose rollback option from Section 3, or apply a hotfix directly.

**Step 5 — Resolve**
```bash
# Confirm resolved
curl -f http://YOUR-ALB-DNS/health

# Silence the Alertmanager alert if still firing
# Go to http://localhost:9093 → click alert → Silence → set 1 hour
```

**Step 6 — Post-incident review**
Write a brief note within 24 hours:
```
INCIDENT RESOLVED — [P1/P2/P3]
Duration: HH:MM to HH:MM UTC (X minutes)
Root cause: [one sentence]
Fix applied: [what you did]
Prevention: [how to stop this happening again]
```

---

## 5. Alert Playbooks

### FlaskAppDown — CRITICAL

**Meaning:** Prometheus cannot reach `http://flask-app:5000/metrics` for > 1 minute.

```bash
# Step 1 — check if the container is running
docker ps | grep securecloud-app
# If not listed → container crashed

# Step 2 — check container logs
docker logs securecloud-app --tail 50

# Step 3 — restart the container
docker-compose -f docker/docker-compose.dev.yml restart app

# Step 4 — if restart doesn't help, redeploy
# Trigger a new Jenkins build or use Option A rollback from Section 3

# Step 5 — check DB connectivity (common cause of startup failure)
docker exec securecloud-app python3 -c "import mysql.connector; print('DB OK')"

# Step 6 — check Secrets Manager is reachable
aws secretsmanager get-secret-value \
  --secret-id securecloud/db-credentials \
  --region eu-west-3 \
  --query SecretString \
  --output text
```

**Common causes:** DB connection failure on startup, Secrets Manager unreachable, OOM kill, bad deploy.

---

### HighErrorRate — CRITICAL

**Meaning:** More than 10% of requests returning HTTP 5xx for > 2 minutes.

```bash
# Step 1 — check which endpoint is failing
# Prometheus query: rate(flask_http_request_total{status=~"5.."}[5m]) by (endpoint)

# Step 2 — check app logs for the error
docker logs securecloud-app --tail 100 | grep -i error

# Step 3 — check DB connection pool
# Prometheus query: db_connection_pool_active
# If near pool_size (5) → pool exhausted

# Step 4 — check RDS status
aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='securecloud-mysql-staging'].DBInstanceStatus" \
  --output text \
  --region eu-west-3
# Should return: available

# Step 5 — if DB is down, restart RDS (takes ~5 mins)
aws rds reboot-db-instance \
  --db-instance-identifier securecloud-mysql-staging \
  --region eu-west-3
```

**Common causes:** DB down, connection pool exhausted, bad code deploy, upstream dependency failure.

---

### HighResponseTime — WARNING

**Meaning:** 95th percentile response time exceeds 2 seconds for > 5 minutes.

```bash
# Step 1 — identify slow endpoints
# Prometheus query: flask_http_request_duration_seconds{quantile="0.95"} by (endpoint)

# Step 2 — check DB slow queries
# Connect to RDS and run:
# SHOW FULL PROCESSLIST;
# SELECT * FROM information_schema.processlist WHERE time > 5;

# Step 3 — check CPU and memory
# Grafana → Node Exporter dashboard → CPU usage graph

# Step 4 — check if it's a traffic spike
# Prometheus query: rate(flask_http_request_total[5m])
# If traffic is unusually high → consider scaling (see Section 8)
```

**Common causes:** Missing DB index, N+1 query, traffic spike, underpowered instance.

---

### DiskSpaceLow — WARNING

**Meaning:** Less than 10% disk space free on the root filesystem.

```bash
# Step 1 — check current disk usage
df -h /

# Step 2 — find what is using space
du -sh /* 2>/dev/null | sort -rh | head -20

# Step 3 — clean Docker artifacts (usually the biggest culprit)
docker system prune -f
docker image prune -a -f

# Step 4 — clean old Jenkins build artifacts
# Go to http://localhost:8080 → your job → Build History
# Delete old builds manually, or configure "Discard Old Builds" in job config

# Step 5 — clean old logs
find /var/log -name "*.log" -mtime +30 -delete

# Step 6 — if still low, expand EBS volume in AWS Console
# EC2 → Volumes → Modify Volume → increase size
# Then: sudo growpart /dev/xvda 1 && sudo resize2fs /dev/xvda1
```

---

## 6. Database Operations

### Connect to RDS (from EC2 in private subnet)

```bash
# Get the DB endpoint
export DB_HOST=$(aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='securecloud-mysql-staging'].Endpoint.Address" \
  --output text \
  --region eu-west-3)

# Get credentials from Secrets Manager
export DB_CREDS=$(aws secretsmanager get-secret-value \
  --secret-id securecloud/db-credentials \
  --region eu-west-3 \
  --query SecretString \
  --output text)

export DB_USER=$(echo $DB_CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
export DB_PASS=$(echo $DB_CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# Connect
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS flaskdb
```

### Check database health

```bash
# From inside MySQL:
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Uptime';
SHOW VARIABLES LIKE 'max_connections';

# Check for long-running queries
SHOW FULL PROCESSLIST;
```

### Manual backup

```bash
# RDS automated backups run daily — retained 7 days
# To trigger a manual snapshot:
aws rds create-db-snapshot \
  --db-instance-identifier securecloud-mysql-staging \
  --db-snapshot-identifier securecloud-manual-$(date +%Y%m%d-%H%M) \
  --region eu-west-3

# List all snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier securecloud-mysql-staging \
  --region eu-west-3 \
  --query "DBSnapshots[*].{ID:DBSnapshotIdentifier,Status:Status,Time:SnapshotCreateTime}" \
  --output table
```

### Point-in-time recovery

```bash
# Restore to a specific point in time (e.g. 1 hour ago)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier securecloud-mysql-staging \
  --target-db-instance-identifier securecloud-mysql-restored \
  --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region eu-west-3
# Takes ~15 minutes — creates a NEW instance, does not overwrite the original
```

---

## 7. Secrets Rotation

Secrets Manager auto-rotates the DB password every 30 days. This section covers manual rotation and what to do if rotation fails.

### Check rotation status

```bash
aws secretsmanager describe-secret \
  --secret-id securecloud/db-credentials \
  --region eu-west-3 \
  --query "{LastRotated:LastRotatedDate,NextRotation:NextRotationDate,RotationEnabled:RotationEnabled}"
```

### Manually trigger rotation

```bash
aws secretsmanager rotate-secret \
  --secret-id securecloud/db-credentials \
  --region eu-west-3

# Monitor rotation progress
aws secretsmanager describe-secret \
  --secret-id securecloud/db-credentials \
  --region eu-west-3 \
  --query "RotationRules"
```

### If the app fails after rotation

The app fetches credentials fresh on startup. A restart picks up the new password automatically.

```bash
# Restart the app container
docker-compose -f docker/docker-compose.dev.yml restart app

# Or redeploy via Jenkins — trigger a build manually at http://localhost:8080
```

### Update a secret value manually

```bash
aws secretsmanager update-secret \
  --secret-id securecloud/db-credentials \
  --secret-string '{
    "username": "admin",
    "password": "NEW-STRONG-PASSWORD",
    "host": "YOUR-RDS-ENDPOINT",
    "dbname": "flaskdb",
    "port": "3306"
  }' \
  --region eu-west-3
```

---

## 8. Scaling

### Vertical scaling — bigger instance (RDS or EC2)

```bash
# Change instance class in variables.tf
# db_instance_class = "db.t3.small"   # was db.t3.micro

cd infra/terraform
terraform apply \
  -var="environment=staging" \
  -var="aws_region=eu-west-3" \
  -var="db_instance_class=db.t3.small"
# RDS modification takes ~10 minutes with a brief restart
```

### Horizontal scaling — more app instances

```bash
# If using ECS — update desired count
aws ecs update-service \
  --cluster securecloud-cluster \
  --service securecloud-flask \
  --desired-count 3 \
  --region eu-west-3
```

### When to scale

| Signal | Threshold | Action |
|---|---|---|
| CPU > 80% for 10 min | Prometheus `node_cpu_seconds_total` | Scale vertically or add instances |
| Response time p95 > 2s | `flask_http_request_duration_seconds` | Check DB first, then scale |
| DB connections > 80% of max | `Threads_connected / max_connections` | Increase pool size or scale RDS |
| Disk > 80% used | `node_filesystem_avail_bytes` | Expand EBS or clean up |

---

## 9. Destroy / Shutdown

Use this to fully stop everything and eliminate all AWS costs.

```bash
# Step 1 — destroy AWS infrastructure
cd infra/terraform
terraform workspace select staging
terraform destroy \
  -var="environment=staging" \
  -var="aws_region=eu-west-3"
# Type "yes" — takes ~10 mins

# Step 2 — delete the secret
aws secretsmanager delete-secret \
  --secret-id securecloud/db-credentials \
  --force-delete-without-recovery \
  --region eu-west-3

# Step 3 — stop all local Docker containers
docker-compose -f docker/docker-compose.dev.yml down
docker-compose -f docker/docker-compose.jenkins.yml down
docker-compose -f docker/docker-compose.sonar.yml down
docker-compose -f observability/docker-compose.observability.yml down

# Step 4 — confirm no AWS resources remain (should all return blank)
aws rds describe-db-instances \
  --query "DBInstances[*].DBInstanceIdentifier" \
  --output text --region eu-west-3

aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query "NatGateways[*].NatGatewayId" \
  --output text --region eu-west-3

# Step 5 — free Docker disk space
docker system prune -a --volumes
```

---

## 10. Common Errors and Fixes

### Jenkins: `pip3: not found`

**Cause:** Jenkins container does not have Python installed.
**Fix:** Use Docker agent in Jenkinsfile:
```groovy
agent {
    docker { image 'python:3.11-slim' }
}
```

---

### Jenkins: `Couldn't find any revision to build`

**Cause:** Jenkins looking for `master` branch but repo uses `main`.
**Fix:** In Jenkinsfile replace `git branch: 'master'` with `checkout scm`.
In Jenkins UI: Configure → Branch Specifier → change `*/master` to `*/main`.

---

### Jenkins: `Expected one of steps, stages, or parallel`

**Cause:** `input` block not wrapped in `steps`.
**Fix:**
```groovy
stage('Approve Production?') {
    steps {
        input message: "Deploy to PRODUCTION?", ok: "Yes"
    }
}
```

---

### Trivy: image has HIGH/CRITICAL CVEs

**Cause:** Outdated base image or pip package.
**Fix (pip package):** Bump version in `requirements.txt` to the "Fixed in" version Trivy shows.
**Fix (OS package):** Add `apt-get upgrade -y` to Dockerfile after the `FROM` line.
**Fix (no patch available):** Add CVE to `.trivyignore` with a comment explaining why.

---

### Terraform: `Error acquiring the state lock`

**Cause:** Previous `terraform apply` crashed and left a lock in DynamoDB.
**Fix:**
```bash
terraform force-unlock LOCK-ID
# Get LOCK-ID from the error message
```

---

### Terraform: `InvalidClientTokenId`

**Cause:** AWS CLI credentials expired or wrong region.
**Fix:**
```bash
aws sts get-caller-identity   # confirm credentials work
aws configure                 # re-enter if expired
```

---

### App: `Database connection refused`

**Cause:** RDS not yet available, wrong endpoint, or security group blocking.
**Fix:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --query "DBInstances[*].DBInstanceStatus" \
  --output text --region eu-west-3
# Must be "available" not "creating" or "modifying"

# Check secret has correct host
aws secretsmanager get-secret-value \
  --secret-id securecloud/db-credentials \
  --region eu-west-3 \
  --query SecretString --output text

# Check security group allows port 3306 from app SG
aws ec2 describe-security-groups \
  --group-names sg-db-securecloud \
  --region eu-west-3
```

---

### SonarQube: `Not authorized to analyze this project`

**Cause:** Token type is "Project Analysis Token" instead of "Global Analysis Token".
**Fix:** In SonarQube → My Account → Security → generate a new token with type **Global Analysis Token**.

---

### Docker: `version is obsolete` warning

**Cause:** `version:` field in docker-compose.yml is deprecated in newer Docker versions.
**Fix:** Remove the `version: "3.9"` line from all docker-compose files. It is optional and ignored.

---

## 11. Contacts

| Role | Name | Contact |
|---|---|---|
| Project owner / on-call | Hemanth Ponugothi | hemanthponugothi@gmail.com |
| GitHub repo | — | https://github.com/Hemanth26080/SecureCloud-Pipeline |

**Useful AWS Console links:**
- RDS: https://eu-west-3.console.aws.amazon.com/rds/home?region=eu-west-3
- Secrets Manager: https://eu-west-3.console.aws.amazon.com/secretsmanager/home?region=eu-west-3
- VPC: https://eu-west-3.console.aws.amazon.com/vpc/home?region=eu-west-3
- IAM: https://console.aws.amazon.com/iam/home

---

*Last updated: 2026-03-16 | Author: Hemanth Ponugothi*
*Review this document after every major incident or infrastructure change.*