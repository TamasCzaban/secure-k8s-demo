# secure-k8s-demo

A security-focused Kubernetes cluster on AWS, built as a practical showcase of cloud infrastructure security controls. All infrastructure is defined as code — no manual console clicks.

**Stack:** Terraform · k3s · EC2 · GuardDuty · CloudTrail · S3 · K8s RBAC · NetworkPolicy

---

## What this demonstrates

| Layer | Control | Detail |
|-------|---------|--------|
| Network | Security group least-privilege | SSH (22) and k3s API (6443) restricted to a single operator CIDR — no `0.0.0.0/0` |
| Network | K8s NetworkPolicy | Default-deny on `dev` namespace; only TCP 80 ingress and DNS/HTTPS egress permitted |
| IAM | Scoped EC2 role | No wildcard `Action` or `Resource` — only `ec2:DescribeInstances` and scoped CloudWatch Logs |
| IAM | K8s RBAC | `app-sa` ServiceAccount bound to a Role that allows `get`/`list` on pods only; `delete`, secrets access all denied |
| Runtime | Non-root container | nginx runs as uid 101 (`runAsNonRoot: true`, `runAsUser: 101`), capabilities dropped, privilege escalation blocked |
| Audit | CloudTrail | Management events logged to an encrypted, versioned, public-access-blocked S3 bucket |
| Threat detection | GuardDuty | Detector configured via Terraform; pending account activation (see [#1](../../issues/1)) |

---

## Architecture

```
Your IP (/32)
    │
    ▼
[Security Group]  SSH:22, API:6443 — operator CIDR only
    │
    ▼
[EC2 t3.micro]  Amazon Linux 2023 · IAM role (scoped)
    │
    ▼
[k3s]  Single-node Kubernetes (v1.35)
    │
    ▼
[Namespace: dev]
    ├── ServiceAccount: app-sa  (automount disabled)
    ├── Role: app-reader        (get/list pods only)
    ├── NetworkPolicy: deny-all-except-http
    └── Deployment: nginx:1.27-alpine (uid 101, caps dropped)
```

---

## Repository layout

```
.
├── terraform/          # All AWS infrastructure
│   ├── main.tf         # VPC, subnet, IGW, security group, EC2
│   ├── iam.tf          # EC2 role + scoped inline policy
│   ├── s3.tf           # CloudTrail bucket (encrypted, versioned, no public access)
│   ├── cloudtrail.tf   # Trail writing to S3
│   ├── guardduty.tf    # GuardDuty detector (pending account activation)
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── k8s/                # Kubernetes manifests
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   ├── rolebinding.yaml
│   ├── deployment.yaml
│   └── network_policy.yaml
├── bootstrap/
│   ├── install_k3s.sh      # Baked into EC2 user-data
│   └── apply_manifests.sh  # Applies k8s/ to the live cluster
└── ssh/
    └── operator.pub        # ED25519 public key (private key gitignored)
```

---

## Reproducing this environment

### Prerequisites

- Terraform >= 1.6
- AWS CLI v2, configured with an IAM user that has `AdministratorAccess`
- An ED25519 SSH key pair at `ssh/operator` / `ssh/operator.pub`

### 1. Bootstrap

```bash
cd terraform
terraform init
terraform apply
```

The EC2 instance runs `bootstrap/install_k3s.sh` via user-data automatically.

### 2. Verify k3s

```bash
ssh -i ssh/operator ec2-user@<EC2_PUBLIC_IP>
sudo systemctl status k3s
sudo kubectl get nodes
```

### 3. Apply K8s manifests

```bash
scp -i ssh/operator -r k8s/ ec2-user@<EC2_PUBLIC_IP>:~/
ssh -i ssh/operator ec2-user@<EC2_PUBLIC_IP> "sudo bash ~/bootstrap/apply_manifests.sh"
```

### 4. Verify RBAC

```bash
# On the EC2 node:
sudo kubectl -n dev auth can-i get pods    --as=system:serviceaccount:dev:app-sa  # yes
sudo kubectl -n dev auth can-i delete pods --as=system:serviceaccount:dev:app-sa  # no
sudo kubectl -n dev auth can-i get secrets --as=system:serviceaccount:dev:app-sa  # no
```

---

## Security decisions

**Security group over SSH bastion** — single-node demo; operator CIDR restriction gives equivalent isolation without the operational overhead of a bastion host.

**k3s over EKS** — free tier, no managed control plane costs. The security controls (RBAC, NetworkPolicy, non-root pods) are identical to EKS at the manifest level.

**No wildcard IAM** — the EC2 instance role uses explicit `Action` and scoped `Resource` ARNs. Demonstrates the principle of least privilege at the cloud IAM layer, mirroring the K8s RBAC approach.

**emptyDir for nginx writable paths** — nginx:alpine needs `/var/cache/nginx` and `/var/run` to be writable. Rather than relaxing the security context, tmpfs-backed `emptyDir` volumes are mounted at those paths so the root filesystem stays effectively read-only.

---

## Live infrastructure

| Resource | Value |
|----------|-------|
| Region | eu-north-1 (Stockholm) |
| EC2 instance | `i-09048028f445acd1b` |
| VPC | `vpc-071582a053f0835b3` |
| CloudTrail bucket | `secure-k8s-cloudtrail-eu-north-1-875034362662` |
| k3s version | v1.35.5+k3s1 |
