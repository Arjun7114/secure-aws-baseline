# Security Decisions & Threat Model

This document explains the security reasoning behind the Secure AWS Baseline project — what it protects, what it defends against, and which risks were consciously accepted. It exists because real security engineering is not "make every scanner pass"; it is making deliberate, documented trade-offs and being able to justify them.

> **Scope note:** This project provisions an internet-facing demo workload (an Apache web server serving a static page). It stores no production or sensitive data. The controls below are implemented for real and model how an equivalent production workload would be protected.

---

## 1. What we are protecting (assets)

| Asset | Description | Why it matters |
|---|---|---|
| The EC2 web server | `t3.micro` in the public subnet running Apache, reachable on 80/443 | The internet-facing entry point — the most exposed component |
| EC2 instance credentials | Temporary AWS credentials available to the instance via its IAM role | If stolen, an attacker could act as the instance inside AWS |
| The private subnet | Where backend/internal resources would live | Represents the trust boundary between "internet-facing" and "internal" |
| Network telemetry | VPC Flow Logs in an encrypted CloudWatch Log Group | Evidence needed to detect and investigate an incident |
| The Terraform state & pipeline | The code and CI/CD that defines the whole environment | Compromise here means compromise of everything downstream |

---

## 2. Who we are defending against (threat actors)

- **Opportunistic internet attackers** — automated scanners probing public IPs for open ports, weak services, and exposed storage.
- **An attacker who gains a foothold on the web server** — e.g. via an application vulnerability — and then tries to escalate or move laterally inside AWS.
- **Insecure-by-accident changes** — a developer (including future me) pushing infrastructure code that unintentionally introduces a misconfiguration.

This is a realistic threat set for an internet-facing cloud workload; it deliberately excludes nation-state / physical-access threats, which are out of scope for a baseline of this kind.

---

## 3. Attack → Control mapping

This is the core of the project's security reasoning: for each plausible attack, the specific control that mitigates it and where it is implemented.

| # | Attack scenario | Control implemented | Where |
|---|---|---|---|
| 1 | **Stolen instance credentials via SSRF** — an app-layer request-forgery bug tricks the server into leaking its AWS credentials from the metadata service (the Capital One breach pattern) | **IMDSv2 enforced** (`http_tokens = required`), which blocks the classic SSRF-to-metadata attack path | compute module |
| 2 | **Over-privileged instance** — a compromised server abuses broad AWS permissions | **Least-privilege IAM role** attached via instance profile; no `AdministratorAccess`, scoped trust policy allowing only EC2 to assume it | compute module |
| 3 | **Data theft from a stolen disk / snapshot** | **Encrypted EBS root volume** at rest | compute module |
| 4 | **Data exfiltration from a compromised host** — attacker uses the box to send stolen data anywhere | **Egress restricted to ports 80/443 only** — a compromised host cannot open outbound connections on arbitrary ports/protocols | security module |
| 5 | **Unauthorized inbound access** to admin ports (SSH/RDP) | Security group **ingress limited to HTTP/HTTPS**; no 22/3389 open to the internet | security module |
| 6 | **Lateral movement via the permissive default security group** | VPC **default security group locked to deny-all** (no ingress/egress rules) | network module |
| 7 | **Undetected intrusion** — attacker activity leaves no trace | **VPC Flow Logs (ALL traffic)** delivered to an encrypted, retained CloudWatch Log Group for investigation | network module |
| 8 | **Tampering with the log store** to hide activity | Flow-log **KMS key with rotation** + an explicit, scoped key policy; flow-log IAM role scoped to a single log group | network module |
| 9 | **Insecure infrastructure reaching production** — a bad change is merged and deployed | **CI/CD policy-as-code gate**: Checkov scans every pull request and a required status check **blocks the merge** on any violation | GitHub Actions + branch protection |
| 10 | **Public data exposure** (e.g. an accidentally public S3 bucket) | Caught by the same CI gate — validated by deliberately submitting a public bucket, which the pipeline blocked | GitHub Actions |

---

## 4. Accepted risks (conscious trade-offs)

Not every scanner finding is a bug. The following are **intentional** and are documented in code with `#checkov:skip` annotations and written justifications, rather than silently ignored.

| Finding | Decision | Justification | Compensating factor |
|---|---|---|---|
| `CKV_AWS_130` — public subnet assigns public IPs | **Accepted** | The web server is *meant* to be internet-facing; a public subnet with public IPs is required for that role | Private workloads use the separate private subnet; only the web tier is exposed |
| `CKV_AWS_260` — security group allows inbound port 80 from `0.0.0.0/0` | **Accepted** | A public web server must accept HTTP from the internet by design | Scoped to 80/443 only; all other ports closed; egress also restricted |
| `CKV2_AWS_5` — security group "not attached to a resource" | **Accepted (false positive)** | The SG *is* attached to the EC2 instance, but in a different module; the finding appears only when scanning the security module in isolation | Full-project scans confirm the attachment |

The principle: an accepted risk is only acceptable if it is **documented, justified, and paired with a compensating control** — which each of these is.

---

## 5. Defense-in-depth summary

The design layers controls so that no single failure is catastrophic:

- **Prevent (at the code stage):** the CI/CD Checkov gate stops insecure infrastructure before it can be deployed.
- **Harden (at the resource stage):** encryption, IMDSv2, least-privilege IAM, scoped security groups, locked default SG.
- **Contain (at the network stage):** public/private subnet separation, restricted egress limiting what a compromised host can do.
- **Detect (at the runtime stage):** VPC Flow Logs provide the telemetry needed to investigate an incident.

---

## 6. Known gaps / future work

Being honest about what this baseline does *not* yet cover is itself part of good security engineering:

- **Post-deployment detection** (GuardDuty, Security Hub, AWS Config) is not yet enabled — the current focus is shift-left prevention. This is the natural next phase.
- **Federated CI credentials (OIDC)**: the pipeline should use short-lived OIDC-based AWS credentials rather than any long-lived keys — a planned hardening step.
- **WAF / rate limiting** on the public web tier is not implemented.
- **Secrets management** (e.g. Secrets Manager with rotation) is not needed by the current demo workload but would be required for a real application.
