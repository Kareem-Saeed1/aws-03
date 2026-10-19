# Deployment runbook

Run from the repository root. Review the account, DNS names and costs first. No commands in this package have been applied to an AWS account during preparation.

## 1. Verify identity and region

Authenticate using the approved AWS profile, then:

```bash
export AWS_PROFILE=lab
export AWS_DEFAULT_REGION=eu-west-1
aws sts get-caller-identity
terraform version
```

Stop if the returned account is not your intended lab account. The region in `terraform.tfvars` must match the intended workload Region.

## 2. Bootstrap remote state

Choose your own globally unique private bucket name. This small stack uses local state initially; keep its local state secure and backed up outside Git.

```bash
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap plan \
  -var='aws_region=eu-west-1' \
  -var='state_bucket_name=REPLACE-WITH-UNIQUE-STATE-BUCKET' \
  -out=bootstrap.tfplan
terraform -chdir=infra/bootstrap apply bootstrap.tfplan
```

The bucket has versioning, encryption, public-access blocking and deletion protection through Terraform `prevent_destroy`. The main stack uses S3-native lockfiles. Do not put credentials in backend files. If your organization already provides a compliant state bucket, use that instead and skip creating a second one.

## 3. Configure this environment

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
cp infra/backend.hcl.example infra/backend.hcl
```

Edit both files locally. Required fields: AWS Region, domain name, hosted-zone ID, email and state bucket. Keep `enable_db_bootstrap = true` for the initial database initialization only. The existing Route 53 hosted zone must already resolve publicly; otherwise ACM DNS validation can wait indefinitely.

The default CIDRs are derived from `10.40.0.0/16`. Changing CIDR input after deployment can force network replacements. Use unused DNS names; Terraform should not overwrite other applications' records.

## 4. Initialize, review and apply

```bash
terraform -chdir=infra init -backend-config=backend.hcl
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=deployment.tfplan
terraform -chdir=infra apply deployment.tfplan
terraform -chdir=infra output
```

Review any replacement/deletion actions. The plan contains sensitive material and is excluded from Git. Deployment duration depends on RDS, CloudFront, ACM and service quotas. Terraform creates application/static artifacts automatically from `app/`.

EC2 user data installs the application, starts Gunicorn and ships logs. Dependencies need outbound HTTPS through NAT. The application does **not** connect with the database administrator credentials. Initially `/health` is alive, but `/ready` and the main page return 503 until step 5 initializes the runtime database role/table.

## 5. Initialize the database once

List the ASG instances:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$(terraform -chdir=infra output -raw autoscaling_group_name)" \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text
```

Open Systems Manager > Session Manager and connect to one application instance, or use `aws ssm start-session --target INSTANCE_ID`. Wait for `/opt/webapp/init_db.py` to exist and the application service to be installed.

Run the following **inside that EC2 session**:

```bash
sudo bash
set -a
source /etc/webapp.env
set +a
cd /opt/webapp
/opt/webapp/.venv/bin/python init_db.py
exit
```

The script retrieves the admin and application secrets without printing them, creates the table and restricted runtime role, and grants only database CONNECT, schema USAGE, table SELECT/INSERT and sequence USAGE/SELECT. The script is repeatable for this schema and uses an advisory transaction lock. It is not a general migration framework.

Now return to your laptop and change this value in `infra/terraform.tfvars`:

```hcl
enable_db_bootstrap = false
```

Apply the permission removal:

```bash
terraform -chdir=infra plan -out=revoke-bootstrap.tfplan
terraform -chdir=infra apply revoke-bootstrap.tfplan
terraform -chdir=infra output bootstrap_access_enabled
```

The output must be `false`. The database admin secret ARN remains in instance configuration, but the EC2 role can no longer read its value. Confirm that re-running the initializer is denied after IAM propagation; normal application access should continue. Do not publish session logs containing secrets.

## 6. Retrieve the demo login privately

In AWS Secrets Manager, open the secret identified by the `app_secret_arn` output. Retrieve `username` and `password` for the browser's Basic Authentication prompt. This same secret also contains DB and session values: do not copy the whole secret to a ticket, screenshot or README.

Navigate to `application_url`. Create a task and verify it remains after refreshing. The CSS URL is returned as `static_css_url`. Credentials are for a shared learning demo only; use an identity provider before production.

## 7. Activate alerts and verify

Confirm the SNS subscription email. Open the CloudWatch dashboard named by `dashboard_name` and run:

```bash
python scripts/smoke-test.py \
  --app-url "$(terraform -chdir=infra output -raw application_url)" \
  --static-url "$(terraform -chdir=infra output -raw static_css_url)"
```

The script prompts for the demo credentials. Continue with [TESTING.md](TESTING.md), collect real screenshots and complete the evidence record. HTTP status checks are only a starting point; they do not certify resilience or security.

## 8. Record deployment evidence

Follow [GITHUB-UPLOAD.md](GITHUB-UPLOAD.md) to submit sanitized evidence and documentation updates. Review `git diff --cached` before pushing. Keep the README deployment status accurate.

Sources: [AWS two-AZ reference](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html), [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3), [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html).
