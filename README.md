# Scalable Web Application on AWS

[Architecture](#architecture) · [Deployment guide](docs/DEPLOYMENT.md) · [Testing](docs/TESTING.md) · [Operations](docs/OPERATIONS.md)

A two-Availability-Zone web application built with Terraform, private EC2 instances, an Application Load Balancer and PostgreSQL on Amazon RDS. Auto Scaling manages application capacity; CloudFront serves static assets from a private S3 bucket.

This repository contains the infrastructure, a small Flask task board, an editable AWS architecture diagram and the runbooks needed to deploy and test the solution.

**Status:** source and documentation are available. AWS deployment and live acceptance tests are pending. Local validation results and remaining checks are recorded in [VALIDATION.md](docs/VALIDATION.md).

## Contents

- [Solution overview](#solution-overview)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Build and test](#build-and-test)
- [Deploy to AWS](#deploy-to-aws)
- [Repository structure](#repository-structure)
- [Operations and security](#operations-and-security)
- [Project deliverables](#project-deliverables)
- [Contributing](#contributing)
- [References](#references)
- [License](#license)

## Solution overview

The application lets an authenticated user add and view tasks. Records are stored in PostgreSQL, so application instances can be replaced without losing data. A shared demo login keeps the sample small; production use requires an appropriate identity provider and the hardening work described in [the security guide](docs/SECURITY.md#production-hardening).

| Area | Implementation |
| --- | --- |
| Network | VPC with public, private application and private database subnets in two AZs |
| Compute | EC2 Launch Template and Auto Scaling group; two instances initially, maximum four |
| Routing | Public ALB with HTTPS, HTTP-to-HTTPS redirect and a host-based listener rule |
| Scaling | CPU target tracking, with an optional step-scaling exercise |
| Database | PostgreSQL RDS Multi-AZ DB instance, encrypted storage, TLS and seven-day backups |
| Application protection | Regional WAF web ACL with Common, Known Bad Inputs and SQLi managed rule groups |
| Static content | CloudFront with Origin Access Control and a private S3 origin |
| DNS | Route 53 aliases: application hostname to ALB; static hostname to CloudFront |
| Administration | Systems Manager Session Manager; no bastion or inbound SSH |
| Monitoring | CloudWatch logs, dashboard and alarms, with SNS notifications |
| Automation | Terraform infrastructure and a GitHub Actions validation workflow |

## Architecture

![Scalable web application architecture across two AWS Availability Zones](docs/architecture/architecture.png)

[Full-size diagram](docs/architecture/architecture.png) · [Editable draw.io file](docs/architecture/architecture.drawio) · [Vector version](docs/architecture/architecture.svg)

The draw.io file uses native AWS shapes and editable connections. The exported diagram uses official AWS artwork; see [icon attribution](docs/architecture/AWS-ICON-ATTRIBUTION.md).

### Request flow

1. Route 53 resolves the application hostname to the internet-facing ALB.
2. The ALB terminates HTTPS and applies its associated WAF web ACL.
3. A host-based listener rule forwards requests to private EC2 instances on port 8000.
4. The application connects to the RDS endpoint using verified TLS and a restricted database role.
5. Browsers retrieve CSS through the static hostname. CloudFront caches these versioned assets and accesses S3 through OAC.
6. EC2 instances reach AWS APIs and package repositories through the NAT gateway in their AZ. An S3 gateway endpoint handles S3 access.

CloudFront serves static content only. Application requests go directly to the ALB, preserving the separate application and static DNS paths. The RDS standby supports failover and does not serve application reads.

See [architecture decisions](docs/ARCHITECTURE.md) for subnet CIDRs, routing, health checks, scaling behavior and the scope of the design.

## Getting started

### Prerequisites

- An AWS account and a deployment role with the permissions listed in [PREREQUISITES.md](docs/PREREQUISITES.md).
- An existing public Route 53 hosted zone with working DNS delegation.
- Two unused hostnames, such as `app.example.com` and `static.example.com`.
- Terraform 1.11 or later, below 2.0; AWS CLI v2; Git; Python 3.11 or later.
- An email address for SNS notifications.
- Available service quotas and an agreed budget for the deployment.

The example configuration uses `eu-west-1`. This project does not create an AWS Organization, landing zone, registered domain or hosted zone.

### Clone the repository

```bash
git clone https://github.com/Kareem-Saeed1/aws-03.git
cd aws-03
```

## Build and test

Run the application tests from the repository root. These tests use fakes and do not require AWS credentials or a running database.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r app/requirements.txt -r tests/requirements.txt
python -m pytest -q tests
```

On Windows PowerShell, activate the environment with `.venv\Scripts\Activate.ps1`.

Validate both Terraform configurations without connecting to the remote state backend:

```bash
terraform fmt -check -recursive infra
terraform -chdir=infra init -backend=false -input=false
terraform -chdir=infra validate
terraform -chdir=infra/bootstrap init -backend=false -input=false
terraform -chdir=infra/bootstrap validate
```

[GitHub Actions](https://github.com/Kareem-Saeed1/aws-03/actions) runs these checks on pushes to `main` and pull requests. The workflow has no AWS credentials and does not deploy resources.

## Deploy to AWS

Follow the [deployment runbook](docs/DEPLOYMENT.md) for the complete commands and verification steps.

1. Authenticate to AWS and confirm the target account and Region.
2. Create the Terraform state bucket using `infra/bootstrap`, or use an approved existing backend.
3. Copy `infra/terraform.tfvars.example` and `infra/backend.hcl.example` to their local configuration filenames and supply your values.
4. Initialize Terraform, review the plan and apply it.
5. Use Session Manager to initialize the database table and restricted runtime role.
6. Set `enable_db_bootstrap = false` and apply again to remove temporary access to the administrator secret.
7. Retrieve the demo login privately, confirm the SNS subscription and complete the [acceptance tests](docs/TESTING.md).

NAT gateways, the ALB and RDS incur charges while idle. Use the [AWS Pricing Calculator](https://calculator.aws/) for the selected Region. The default USD 200 monthly budget is an alert threshold, not an estimate or spending cap. Follow [costs and cleanup](docs/COSTS-AND-CLEANUP.md) when the exercise is complete.

## Repository structure

| Directory or file | Purpose |
| --- | --- |
| [`app/`](app/) | Flask application, database initialization, templates and static assets |
| [`infra/`](infra/) | Terraform for networking, compute, database, edge services and monitoring |
| [`infra/bootstrap/`](infra/bootstrap/) | One-time setup of the Terraform state bucket |
| [`scripts/`](scripts/) | Smoke tests, database initialization helper and bounded CPU-load exercise |
| [`tests/`](tests/) | Application unit tests |
| [`docs/`](docs/) | Deployment, architecture, security, testing and operational guides |
| [`docs/architecture/`](docs/architecture/) | PNG, SVG and editable draw.io diagrams |
| [`docs/evidence/`](docs/evidence/) | Acceptance-test results template and evidence instructions |
| [`.github/`](.github/) | Validation workflow, issue forms and pull request template |

## Operations and security

- [Security controls and production hardening](docs/SECURITY.md)
- [Monitoring, troubleshooting and rollback](docs/OPERATIONS.md)
- [Acceptance tests and evidence](docs/TESTING.md)
- [Cost management and cleanup](docs/COSTS-AND-CLEANUP.md)

EC2 and RDS have no public IP addresses. Security groups restrict traffic between tiers; default network ACLs are retained. Database credentials are read from Secrets Manager through the instance role. Terraform state contains sensitive values and must remain private.

Do not commit credentials, real `.tfvars` files, backend configuration, Terraform plans or state. Provider lock files are included deliberately. See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Project deliverables

| Deliverable | Location / status |
| --- | --- |
| Solution architecture | [Diagram and editable source](docs/architecture/) |
| Project repository | [Kareem-Saeed1/aws-03](https://github.com/Kareem-Saeed1/aws-03) |
| Application and infrastructure | [`app/`](app/) and [`infra/`](infra/) |
| Deployment and operating documentation | [`docs/`](docs/) |
| AWS deployment evidence | Pending; record actual results under [`docs/evidence/`](docs/evidence/) |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Include the reason for the change and the checks you ran. Keep diagrams and runbooks in sync with infrastructure changes.

## References

- [AWS: VPC with servers in private subnets and NAT](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html)
- [AWS: RDS Multi-AZ DB instance deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)
- [AWS: Restricting access to an S3 origin with CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [AWS architecture icons](https://aws.amazon.com/architecture/icons/)
- [AWS Solutions repository used as the documentation reference](https://github.com/aws-solutions/dynamic-image-transformation-for-amazon-cloudfront/)

Additional technical references are listed in [REFERENCES.md](docs/REFERENCES.md). This is an independent project; it is not an AWS Solutions release.

## License

The project code is available under the [MIT License](LICENSE). AWS artwork is subject to its own terms; see [NOTICE](NOTICE).
