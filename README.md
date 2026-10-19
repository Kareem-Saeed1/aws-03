# Scalable Web Application on AWS

An EC2-based web application running across two Availability Zones. Terraform provisions the infrastructure, with Auto Scaling for application capacity and RDS Multi-AZ for the database.

The sample application is a small task board built with Flask and PostgreSQL.

## Architecture

![AWS solution architecture](docs/architecture/architecture.png)

[View full size](docs/architecture/architecture.png) · [Edit in draw.io](docs/architecture/architecture.drawio)

- **Networking:** public, private application and private database subnets in each AZ, with one NAT gateway per AZ.
- **Application:** an ALB routes HTTPS traffic to private EC2 instances managed by an Auto Scaling group.
- **Database:** RDS PostgreSQL with a Multi-AZ standby and automated backups.
- **Static assets:** CloudFront serves content from a private S3 bucket.
- **Security and access:** WAF, security groups, Secrets Manager and Session Manager.
- **Monitoring:** CloudWatch logs, alarms and SNS notifications.

Route 53 points the application hostname to the ALB and the static hostname to CloudFront. [Architecture details](docs/ARCHITECTURE.md).

## Getting started

You will need an AWS account, a public Route 53 hosted zone, Terraform 1.11+, AWS CLI v2 and Python 3.11+.

```bash
git clone https://github.com/Kareem-Saeed1/aws-03.git
cd aws-03
cp infra/terraform.tfvars.example infra/terraform.tfvars
cp infra/backend.hcl.example infra/backend.hcl
```

Add your Region, domain, hosted-zone ID, notification email and state-bucket name. Then follow the [deployment guide](docs/DEPLOYMENT.md) to create the backend, deploy the infrastructure and initialize the database.

AWS resources incur charges while running. Keep credentials, Terraform state and local configuration files out of Git.

## Tests

Run in a Python virtual environment:

```bash
python -m pip install -r app/requirements.txt -r tests/requirements.txt
python -m pytest -q tests
terraform fmt -check -recursive infra
```

GitHub Actions runs the application tests and Terraform validation. It does not deploy to AWS.

**Project status:** source and documentation are ready; AWS deployment and live testing are pending.

## Project files

| Folder | Contents |
| --- | --- |
| `app/` | Application, templates and static assets |
| `infra/` | Terraform and backend bootstrap configuration |
| `scripts/` | Smoke tests and deployment helpers |
| `tests/` | Application unit tests |
| `docs/` | Architecture, deployment, operations and testing guides |

## Documentation

[Prerequisites](docs/PREREQUISITES.md) · [Deployment](docs/DEPLOYMENT.md) · [Testing](docs/TESTING.md) · [Operations](docs/OPERATIONS.md) · [Security](docs/SECURITY.md) · [Cleanup](docs/COSTS-AND-CLEANUP.md)

For changes, see [CONTRIBUTING.md](CONTRIBUTING.md). Technical sources are listed in [REFERENCES.md](docs/REFERENCES.md), including the [AWS Solutions example](https://github.com/aws-solutions/dynamic-image-transformation-for-amazon-cloudfront/) used as a documentation reference.

## License

[MIT](LICENSE). AWS icons retain their original terms; see [NOTICE](NOTICE).
