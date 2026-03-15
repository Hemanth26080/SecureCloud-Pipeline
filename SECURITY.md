# Security Policy — SecureCloud-Flask

This document describes the threat model, security controls, and vulnerability reporting process for SecureCloud-Flask. It is intended for security reviewers, hiring managers, and contributors.

---

## Threat Model (STRIDE)

STRIDE is a structured way to think about threats. For each threat category, this section lists what could go wrong, and exactly how this project defends against it.

### S — Spoofing (pretending to be someone you're not)

| Threat | Risk | Mitigation |
|---|---|---|
| Attacker impersonates EC2 instance to access Secrets Manager | HIGH | IAM role scoped to `securecloud/*` only — no other principal can assume it |
| Forged HTTP requests to Flask API | MEDIUM | AWS WAF rules (planned) + input validation on all endpoints |
| Jenkins build triggered by unauthorised user | MEDIUM | Jenkins requires authentication — admin credentials stored securely |

**Controls implemented:**
- EC2 uses IAM instance profile — no static AWS access keys anywhere in the codebase
- `trivy fs --scanners secret` runs on every build — blocks commit if keys are detected
- `.gitignore` excludes `.env`, `*.tfstate`, and `credentials` files

---

### T — Tampering (modifying data or code without authorisation)

| Threat | Risk | Mitigation |
|---|---|---|
| Attacker modifies Docker image between build and deploy | HIGH | Image tagged with Jenkins `BUILD_NUMBER` — immutable tag per build |
| Dependency supply chain attack (malicious pip package) | HIGH | Trivy scans all Python packages in image — blocks on HIGH/CRITICAL CVEs |
| Terraform state file modified to alter infrastructure | HIGH | State stored in S3 with versioning + DynamoDB lock — no direct edit possible |
| SQL injection via API endpoints | HIGH | Parameterised queries via mysql-connector — no string concatenation in SQL |
| Code committed without security review | MEDIUM | SonarQube quality gate blocks merge on 0-tolerance vulnerability policy |

**Controls implemented:**
- `requirements.txt` pins exact versions — no floating `>=` dependencies
- Trivy image scan with `--exit-code 1` — pipeline fails if HIGH/CRITICAL CVE found
- S3 backend encryption enabled — state file encrypted at rest (AES-256)
- bandit SAST scans Python code for injection patterns on every build

---

### R — Repudiation (denying that an action happened)

| Threat | Risk | Mitigation |
|---|---|---|
| Developer denies making a breaking change | MEDIUM | Git commit history + Jenkins build logs archived per build |
| No audit trail for who approved production deploy | HIGH | Jenkins `input` step records which user clicked "Approve" with timestamp |
| AWS API calls made without trace | HIGH | CloudTrail enabled — every AWS API call logged to S3 |

**Controls implemented:**
- Jenkins build logs retained — every stage output stored and linked to commit SHA
- Structured JSON logging in Flask app — every request logged with timestamp, endpoint, status
- Prometheus metrics provide historical request data — can reconstruct traffic patterns

---

### I — Information Disclosure (data leaking to unauthorised parties)

| Threat | Risk | Mitigation |
|---|---|---|
| Database password exposed in source code | CRITICAL | AWS Secrets Manager — password never in code, env files, or logs |
| AWS credentials committed to GitHub | CRITICAL | `.gitignore` blocks `.env`, `credentials` — Trivy secret scan on every build |
| RDS database publicly accessible | CRITICAL | `publicly_accessible = false` in Terraform — DB in private subnet only |
| Flask debug mode exposes stack traces | HIGH | Gunicorn runs in production mode — debug mode disabled |
| Secrets visible in Docker image layers | HIGH | Multi-stage build — secrets only injected at runtime, not in image |
| Container runs as root — full filesystem readable | MEDIUM | Non-root user (UID 1001) enforced in Dockerfile |

**Controls implemented:**
- `USE_SECRETS_MANAGER=true` in production — credentials fetched at runtime via boto3
- RDS subnet group uses only private subnets — no route to internet gateway
- Multi-stage Dockerfile — builder stage discarded, no pip cache or build tools in final image
- `.env.example` committed (safe template) — `.env` in `.gitignore` (never committed)
- Terraform outputs marked `sensitive = true` for DB endpoint

---

### D — Denial of Service (making the service unavailable)

| Threat | Risk | Mitigation |
|---|---|---|
| Flood of HTTP requests overwhelms Flask app | HIGH | Gunicorn with worker + thread limits — AWS ALB rate limiting (planned) |
| RDS connection pool exhausted | HIGH | `pool_size=5` in mysql-connector — prevents connection flooding |
| Disk fills up — app crashes | MEDIUM | Alertmanager `DiskSpaceLow` alert fires at < 10% free |
| Container OOM killed | MEDIUM | Docker memory limits configurable in Compose — ECS task limits in prod |

**Controls implemented:**
- Prometheus alert `FlaskAppDown` — fires within 1 minute of app becoming unreachable
- Prometheus alert `HighErrorRate` — fires when > 10% of requests return 5xx
- Prometheus alert `HighResponseTime` — fires when p95 latency exceeds 2 seconds
- Grafana dashboards show real-time request rate, error rate, and latency

---

### E — Elevation of Privilege (gaining more access than allowed)

| Threat | Risk | Mitigation |
|---|---|---|
| Container process escapes to host as root | HIGH | Non-root user (UID 1001) in Dockerfile — `no-new-privileges:true` in Compose |
| EC2 instance accesses unintended AWS services | HIGH | IAM policy allows only `secretsmanager:GetSecretValue` on `securecloud/*` |
| Jenkins pipeline executes arbitrary AWS commands | HIGH | Jenkins AWS credentials scoped — no IAM admin access |
| Attacker reaches DB from public subnet | CRITICAL | Security group on RDS allows port 3306 from App SG only — no 0.0.0.0/0 |

**Controls implemented:**
- `security_opt: no-new-privileges:true` in Docker Compose — container cannot gain extra Linux capabilities
- IAM policy uses resource-level restriction — `arn:aws:secretsmanager:eu-west-3:*:secret:securecloud/*`
- Security group chain: Internet → ALB (80/443) → App (5000 from ALB SG only) → DB (3306 from App SG only)
- Terraform enforces `deletion_protection = true` on RDS — cannot be deleted accidentally

---

## Security Controls Summary

### Shift-Left Security (catches issues before production)

| Tool | Stage | What It Catches |
|---|---|---|
| `flake8` | Lint | Code style issues that hide bugs |
| `bandit` | SAST | Python security anti-patterns (hardcoded passwords, shell injection, weak crypto) |
| SonarQube | SAST | Bugs, vulnerabilities, code smells — quality gate blocks merge |
| Trivy (filesystem) | Pre-build | Secrets accidentally in code or config files |
| Trivy (image) | Post-build | CVEs in OS packages and Python dependencies |

### Runtime Security

| Control | Where | What It Does |
|---|---|---|
| Non-root container user | Docker | Process runs as UID 1001 — cannot write to most of filesystem |
| Read-only root filesystem | Docker Compose | Container cannot modify its own image layers |
| No static AWS keys | EC2 | IAM instance profile used — keys cannot be stolen from environment |
| Secrets Manager | Runtime | DB password fetched fresh on startup — auto-rotated every 30 days |
| Private subnets | AWS VPC | Flask and RDS unreachable directly from internet |
| Security groups | AWS | Explicit allow-list — default deny everything |

### Continuous Verification

| Check | Frequency | Action on Failure |
|---|---|---|
| Trivy image scan | Every build | Pipeline exits 1 — image not pushed |
| SonarQube quality gate | Every build | Pipeline fails — PR blocked |
| bandit SAST | Every build | Pipeline fails |
| Prometheus health probe | Every 15 seconds | Alert fires after 1 minute down |
| Trivy CVE review | Monthly | Update `.trivyignore` or bump dependency |

---

## Known Accepted Risks

The following CVEs are suppressed in `.trivyignore` because no upstream fix is available. Each is reviewed monthly.

| CVE | Package | Reason Suppressed | Review Date | Risk Assessment |
|---|---|---|---|---|
| CVE-2026-0861 | libc-bin, libc6 (debian 13.3) | No fix available upstream as of 2026-03-15. Affects `memalign` — not called by our application code directly. | 2026-04-15 | LOW — not reachable via our code paths |

---

## What Is Not Yet Implemented

This project is a portfolio demonstration. The following controls are planned but not yet active:

| Control | Priority | Notes |
|---|---|---|
| AWS WAF on ALB | HIGH | OWASP Core Rule Set — blocks SQLi, XSS at edge |
| DAST (OWASP ZAP) | HIGH | Dynamic scan of staging app after deploy |
| mTLS between Flask and RDS | MEDIUM | TLS connection string configured, cert pinning not yet enforced |
| Container image signing | MEDIUM | Cosign / Notary for supply chain integrity |
| Runtime threat detection | MEDIUM | AWS GuardDuty or Falco for anomaly detection |
| Chaos testing | LOW | Pumba / Chaos Mesh — resilience validation |

---

## Reporting a Vulnerability

If you discover a security issue in this project:

1. **Do not open a public GitHub issue** for security vulnerabilities
2. Email: `hemanthponugothi@gmail.com`
3. Include: description, steps to reproduce, potential impact
4. Expected response: within 48 hours
5. Fix target: within 7 days for CRITICAL, 30 days for HIGH

---

## Compliance Notes

This project implements controls aligned with:

- **OWASP Top 10** — injection prevention, security misconfiguration, vulnerable components
- **CIS Docker Benchmark** — non-root user, no privileged containers, health checks
- **AWS Well-Architected Framework (Security Pillar)** — least privilege IAM, encryption at rest, VPC isolation
- **NIST SP 800-190** (Container Security) — image scanning, runtime protection, secrets management

*This is a portfolio project — it is not certified or audited against any compliance framework.*

---

*Last updated: 2026-03-16 | Author: Hemanth Ponugothi*