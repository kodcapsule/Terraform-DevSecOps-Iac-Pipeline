# Enterprise DevSecOps Pipeline: Secure Infrastructure as Code with Terraform & CI/CD Automation

[Secure IaC pipeline architecture diagram](./images/IaC-Pipeline.png)



##  Project Overview 

This project demonstrates the design and implementation of a production-grade, security-first CI/CD pipeline for Infrastructure as Code (IaC) using Terraform and GitHub Actions on AWS. The project  integrates DevSecOps practices at every every stage of infrastructure provisioning, from local development environments to cloud deployment using a shift-left security approach to catch vulnerabilities early in the infrastructure provisioning lifecycle.

---

## 3. Project Architecture Overview

```
DevOps/Developer local environment
  └── Pre-commit Hooks (Gitleaks, lint, format)
         │
         ▼
GitHub Repository (main branch)
  └── GitHub Actions CI/CD Pipeline
         │
         ├── Stage 1 (Parallel)
         │     ├── Terraform fmt / validate / tflint
         │     ├── Static Code Analysis — SAST (Checkov / tfsec)
         │     └── Dependency / Module Scanning
         │
         ├── Stage 2
         │     └── Terraform Plan (OIDC Auth → AWS)
         │
         └── Stage 3
               └── Terraform Apply → AWS (VPC + EKS)
                     └── Remote State → S3 (encrypted, versioned)
```

---

## Full Project Outline

### Phase 1 — Local Development Security (Shift-Left)
In this first phase, to  ensure that security is part of the development process from the very start , shift-left security mindset pre-commit hooks were 
installed and congiured for local development environments using the pre-commit framewor.
Goal: prevent insecure or broken code from ever reaching the remote repo and evntually the CI/CD pipeline

- Pre-commit framework setup for automated local checks
- Gitleaks integration for hardcoded secrets detection
- Terraform formatting (`terraform fmt`) and linting (`tflint`)
- Goal: prevent insecure or broken code from ever reaching the remote repo

### Phase 2 — Authentication & Zero-Trust Access
- Configured OpenID Connect (OIDC) between GitHub Actions and AWS
- Eliminated long-lived AWS access keys from GitHub Secrets
- Used short-lived, scoped credentials via IAM Identity Provider
- Reference: Zero-Trust CI/CD with OIDC

### Phase 3 — Remote State Management
- Created and configured a secure S3 backend for Terraform state
- Enabled S3 bucket versioning for state history and rollback
- Enabled AES-256 server-side encryption for state files
- Blocked all public access to the state bucket
- Used native S3 state locking (`use_lockfile = true`) — no DynamoDB required

### Phase 4 — CI/CD Pipeline (GitHub Actions)

**Workflow 1: Secrets Scanning**
- Tool: Gitleaks
- Triggers: push, pull_request, scheduled daily at 4 AM
- Scans entire git history for hardcoded credentials, API keys, tokens

**Workflow 2: Main IaC Pipeline (3 Parallel Stages)**
- Stage 1a — Formatting, Linting & Validation: `terraform fmt`, `terraform validate`, `tflint`
- Stage 1b — Static Code Analysis (SAST): Checkov or tfsec for misconfiguration detection
- Stage 1c — Dependency/Module Scanning: checks for outdated or vulnerable Terraform modules
- Stage 2 — Terraform Plan: authenticated via OIDC, plan output reviewed before apply
- Stage 3 — Terraform Apply: deploys VPC and EKS cluster to AWS

### Phase 5 — Infrastructure Provisioned (Terraform HCL)
- AWS VPC with proper network segmentation
- Amazon EKS cluster
- Infrastructure defined 100% as code (HCL)
- Remote backend state with encryption and versioning

---

## 5. Tech Stack & Tools

| Category | Tool / Service |
|---|---|
| IaC Language | Terraform (HCL) |
| CI/CD Platform | GitHub Actions |
| Cloud Provider | AWS |
| Authentication | OIDC (GitHub → AWS) |
| State Backend | AWS S3 (encrypted + versioned) |
| Secrets Scanning | Gitleaks |
| SAST / Misconfiguration | Checkov / tfsec |
| Linting | tflint |
| Pre-commit | pre-commit framework |
| Policy as Code | Open Policy Agent (OPA) |
| Infrastructure | AWS VPC, Amazon EKS |

---

## 6. Key DevSecOps Concepts Demonstrated

- **Shift-Left Security** — security checks run locally before code is committed
- **Zero-Trust Authentication** — OIDC replaces static credentials entirely
- **Policy as Code** — OPA policies enforce compliance rules in the pipeline
- **Immutable Infrastructure** — all changes go through the pipeline, no manual cloud console edits
- **Least Privilege** — scoped IAM roles, no long-lived admin keys
- **Secrets Management** — Gitleaks at both local and CI/CD levels
- **State Security** — encrypted, versioned, locked remote state

---

## 7. README Structure (GitHub)

Your GitHub README should follow this structure for maximum impact:

```
# terraform-devsecops-iac-pipeline

[Banner image / architecture diagram]

## Overview
[2–3 sentence summary of what the project does and why it matters]

## Architecture
[Pipeline diagram or architecture image]

## Prerequisites
[List — GitHub account, AWS account, tools to install]

## Project Structure
[Folder/file tree with descriptions]

## Setup Guide
  ### 1. Local Environment Setup
  ### 2. Configure OIDC (GitHub → AWS)
  ### 3. Create Remote S3 Backend
  ### 4. Configure GitHub Actions Workflows
  ### 5. Deploy Infrastructure

## Pipeline Stages
[Description of each stage with screenshot]

## Security Controls
[Table or list of all security measures implemented]

## Lessons Learned
[2–3 honest reflections — what worked, what you'd improve]

## References & Resources
[Links to tools, AWS docs, articles you referenced]
```

---

## 8. LinkedIn Project Entry

**Title:**
Enterprise DevSecOps Pipeline: Secure IaC CI/CD with Terraform & GitHub Actions

**Description (copy-paste ready):**

> Built a production-grade, security-first CI/CD pipeline for Infrastructure as Code using Terraform and GitHub Actions on AWS. The pipeline enforces DevSecOps best practices across every stage — from local development to cloud deployment.
>
> Key highlights:
> • Eliminated static AWS credentials using OIDC-based zero-trust authentication between GitHub Actions and AWS
> • Implemented shift-left security with Gitleaks (secrets scanning), tflint (linting), and Checkov/tfsec (SAST) running in parallel pipeline stages
> • Configured encrypted, versioned, and locked Terraform remote state on AWS S3
> • Enforced Policy as Code using Open Policy Agent (OPA) within the pipeline
> • Provisioned AWS VPC and EKS cluster 100% as code via Terraform
>
> Stack: Terraform · GitHub Actions · AWS (VPC, EKS, S3, IAM) · Gitleaks · Checkov · tfsec · tflint · OIDC · OPA

---

## 9. What to Add to Strengthen the Project

These additions will make it stand out even more in a portfolio:

1. **Architecture diagram** — A visual diagram of the full pipeline (tools like Lucidchart, draw.io, or Excalidraw work well)
2. **Pipeline screenshots** — Capture GitHub Actions runs showing each stage passing (green checks)
3. **Cost estimate** — Add a `COST.md` showing approximate AWS cost for the infrastructure
4. **Destruction workflow** — Add a `terraform destroy` workflow for teardown to show full lifecycle management
5. **CHANGELOG.md** — Document what you built in each iteration
6. **Branch protection rules** — Screenshot showing that main branch requires pipeline to pass before merge
7. **Terraform module structure** — Refactor `infra/` into reusable modules (vpc/, eks/, backend/) to show modularity

---

## 10. Talking Points for Interviews

- *"Why OIDC instead of AWS access keys?"* — Short-lived, automatically rotated credentials; zero secrets stored in GitHub; follows zero-trust principles
- *"What does shift-left security mean in this project?"* — Security checks run on the developer's machine before a single line reaches the repo, not just at the deployment stage
- *"How do you prevent state file corruption?"* — S3 versioning for history, native S3 state locking to prevent concurrent applies, encryption at rest
- *"What would you improve?"* — Adding drift detection (Terraform Cloud or a scheduled plan-only workflow), Sentinel or OPA policies for compliance guardrails, and notification alerts on pipeline failures

---

*Documentation prepared for portfolio use — GitHub & LinkedIn*
