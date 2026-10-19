# Operations and troubleshooting

## Routine checks

Check the CloudWatch dashboard, app/bootstrap logs, WAF logs, ASG activities, target health, RDS events and budget notifications. Confirm that `bootstrap_access_enabled` stays false. Add real synthetic monitoring before using this outside a lab.

## Common failures

| Symptom | Likely checks |
|---|---|
| ACM validation waits | Hosted zone is public; registrar/delegation points to its nameservers; validation CNAME exists |
| EC2 does not appear in SSM | Instance role attached; SSM agent active; NAT route and HTTPS egress; DNS resolution |
| App target unhealthy | `/var/log/cloud-init-output.log`; failed dependency download; `systemctl status webapp`; port 8000 SG; IAM propagation |
| `/health` succeeds but `/ready` is 503 | DB initialization not done; runtime grants; app secret; DB SG; CA bundle; RDS failover |
| Bootstrap AccessDenied | `enable_db_bootstrap` must be true only for initialization; verify correct instance role and allow propagation |
| Static CSS missing | CloudFront deployed; static DNS/certificate; S3 policy OAC ARN; content hash in `static_css_url` |
| Unexpected WAF 403 | Inspect WAF logs and matching rule; do not globally disable security to work around one false positive |
| No email | SNS subscription unconfirmed; spam folder; actual alarm actions not triggered |
| Scaling not observed | ASG average CPU, current/max capacity, warmup, detailed monitoring, CPU credits and selected policy mode |
| RDS class rejected | Confirm engine/version/class support in the chosen Region |
| Terraform backend AccessDenied | Bucket Region and profile; state-key and lockfile permissions |
| Destroy blocked | Disable ALB/RDS deletion protection first; empty all object versions in the two project data buckets |

Useful commands inside an EC2 Session Manager session:

```bash
sudo systemctl status webapp
sudo journalctl -u webapp --since '15 minutes ago'
sudo tail -n 80 /var/log/cloud-init-output.log
curl --fail http://127.0.0.1:8000/health
curl --fail http://127.0.0.1:8000/ready
```

Do not print `/etc/webapp.env` or secrets into public evidence. This file contains ARNs/configuration rather than raw passwords, but still reveals environment details.

## Application updates

Edit code or CSS, run tests and review the Terraform plan. The archive content hash changes the release S3 key and Launch Template user data. Terraform updates the ASG Launch Template version and triggers rolling instance refresh. New CSS has a new content-addressed path. Database migrations are not automated; for schema changes, use a compatible expand/contract plan.

The release archive uses an explicit file allowlist in `infra/storage.tf`. Add new application source files to that allowlist when needed. Keep `.venv`, `.env`, build output and secrets outside release sources; `.gitignore` does not by itself control Terraform packaging.

## Rollback

Revert the source to the last known good Git commit, run tests, inspect the plan and apply. This generates/restores that release configuration and rolls instances. Coordinate rollback with any DB schema changes. Do not blindly roll back unrelated Terraform infrastructure changes. Previous S3 versions are retained, but a tested operational release process is still required.

## Credentials and patching

Rotate the app secret only with coordinated database role updates; session-signing-key rotation also requires process restart and invalidates sessions. Review dependency update PRs and provider lock-file changes. Apply tested AL2023 image updates through the Launch Template/rolling refresh. Consider replacing bootstrap package installation with a tested immutable AMI for production.

Source: [EC2 Auto Scaling instance refresh](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html).
