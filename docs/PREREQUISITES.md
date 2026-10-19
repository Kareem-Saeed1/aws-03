# Prerequisites and access

## Customer / learner inputs

| Input | Example | Required action |
|---|---|---|
| AWS account | Your lab account | Confirm billing, account ownership and deployment authorization |
| AWS Region | `eu-west-1` | Confirm two AZs and EC2/RDS class availability |
| Hosted zone | `example.com` | Existing public Route 53 zone with nameservers delegated correctly |
| Hostnames | `app.example.com`, `static.example.com` | Ensure both are unused |
| Notification email | Your email | Confirm SNS subscription after deployment |
| State bucket | Globally unique name | Create via the bootstrap Terraform stack |
| Cost ceiling | Your agreed budget | Estimate resources and enable billing access/alerts |
| Repository | `aws-scalable-webapp` | Create an empty public GitHub repository |

## Access matrix

| Identity | Required capability | Scope / notes |
|---|---|---|
| Infrastructure deployer | Create/update/delete VPC, subnets, routes, NAT/EIP, EC2 templates, ASGs, ALB, RDS, S3, CloudFront, WAF, logs, alarms, SNS, Secrets Manager and Budgets | Use a dedicated lab account and temporary credentials; organizational SCPs and permissions boundaries still apply |
| Infrastructure deployer | Create/pass instance roles, attach required policies, create service-linked roles if absent | Restrict `iam:PassRole` to the project EC2 role; review IAM changes in the plan |
| Infrastructure deployer | Read public SSM AMI parameter; create ACM certificates and DNS records | ACM operations needed in workload Region and `us-east-1`; Route 53 changes only in the supplied zone |
| State backend user | List bucket; get/put state; get/put/delete `.tflock` | Restrict to this stack's state and lock keys |
| Operator | SSM Start/Resume/TerminateSession; EC2 describe; view logs/alarms | Restrict sessions to project-tagged EC2 instances |
| Operator performing bootstrap | SSM session with sudo and temporary DB-bootstrap policy | Remove temporary admin-secret read permission immediately after initialization |
| Operator retrieving demo login | Secrets Manager GetSecretValue for project app secret | Never store credentials in README or screenshots |
| EC2 runtime | SSM core, CloudWatch agent, GetObject for release path, GetSecretValue for app secret | No root keys or static AWS keys |
| GitHub validation workflow | Repository contents read | No AWS access; no deployment role needed |

These are capability requirements, not a claimed universal least-privilege IAM policy. Resource creation, service-linked roles and existing account controls affect the final policy. Ask the account administrator to scope a deployment role to this lab. No root login is needed for Terraform.

## Local tools

Install Git, AWS CLI v2, Terraform 1.11+, Python 3.11+ and the Session Manager plugin if using CLI sessions. Commands in the guide use Bash (Linux/macOS/WSL/Git Bash); the application and Terraform are not tied to a particular laptop OS.

Authenticate with your approved temporary-credential method. For IAM Identity Center, configure and log in to the appropriate profile, then verify:

```bash
aws configure sso --profile lab
aws sso login --profile lab
export AWS_PROFILE=lab
aws sts get-caller-identity
```

Verify Region-specific PostgreSQL options before applying:

```bash
aws rds describe-orderable-db-instance-options \
  --engine postgres --db-instance-class db.t3.micro \
  --region eu-west-1 --query 'OrderableDBInstanceOptions[].EngineVersion'
```

Select a supported instance class and PostgreSQL major version. Regional availability can change; the example values are configurable.

Sources: [SSM prerequisites](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html), [S3 backend permissions](https://developer.hashicorp.com/terraform/language/backend/s3), [CloudFront certificate requirements](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html).
