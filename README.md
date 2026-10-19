# Scalable Web Application on AWS

A small Flask application hosted on private EC2 instances across two Availability Zones. An Application Load Balancer handles incoming traffic, Auto Scaling manages capacity, and RDS PostgreSQL stores the data.

## Architecture

![AWS architecture](docs/architecture/architecture.png)

[Editable draw.io diagram](docs/architecture/architecture.drawio)

CloudFront serves static files from S3. WAF protects application requests, Session Manager provides instance access, and CloudWatch sends alerts through SNS.

## Setup

Clone the repository and follow the [deployment guide](docs/DEPLOYMENT.md). You’ll need an AWS account, a Route 53 hosted zone, Terraform and the AWS CLI.

The code is ready to deploy. Deployment and live testing are still pending.

## Tests

GitHub Actions checks the application and Terraform configuration. See the [testing guide](docs/TESTING.md) for deployment checks.

## Files

- `app/` — sample application
- `infra/` — Terraform configuration
- `docs/` — setup, operations and cleanup guides
- `tests/` and `scripts/` — tests and helpers

## References

[AWS VPC example](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html) · [Technical references](docs/REFERENCES.md)

[MIT License](LICENSE) · [AWS icon attribution](NOTICE)
