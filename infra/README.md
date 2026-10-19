# Terraform infrastructure

The main configuration deploys the web application into an existing AWS account and public Route 53 hosted zone. The separate `bootstrap/` configuration creates an S3 state bucket.

| File | Resources and configuration |
| --- | --- |
| `network.tf` | VPC, subnets, routes, internet gateway, NAT gateways and S3 endpoint |
| `security.tf` | Security groups, IAM and instance permissions |
| `compute.tf` | Launch Template, Auto Scaling and scaling policies |
| `database.tf` | RDS PostgreSQL, subnet group and database parameters |
| `edge.tf` | ALB, listeners, certificates, CloudFront and DNS |
| `waf.tf` | Regional WAF web ACL and managed rules |
| `monitoring.tf` | Logs, dashboard, alarms, notifications and budget |
| `storage.tf` | Application assets, release packaging and secrets |
| `variables.tf` | Inputs and validation rules |
| `outputs.tf` | Deployment endpoints and resource identifiers |
| `templates/user-data.sh.tftpl` | EC2 application installation and service configuration |

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and `backend.hcl.example` to `backend.hcl`. Set your Region, domain, hosted-zone ID, alert email and state bucket. Both local configuration files are ignored by Git.

The ALB certificate is created in the workload Region. CloudFront uses an aliased AWS provider in `us-east-1` for its certificate. Do not remove that provider alias.

## Deployment

Follow [DEPLOYMENT.md](../docs/DEPLOYMENT.md). It covers backend setup, plan review, deployment, database initialization and removal of temporary bootstrap permissions.

The state contains sensitive values. Keep backend access restricted and never commit state or saved plans. Commit `.terraform.lock.hcl` after reviewing provider updates.

## Cleanup

Deletion protection and retained data require deliberate cleanup. Use [COSTS-AND-CLEANUP.md](../docs/COSTS-AND-CLEANUP.md) rather than deleting individual resources from the console.
