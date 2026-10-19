# Costs and cleanup

## Cost planning

This is not a free-tier-only design. Calculate costs in your chosen Region before deployment. The configured USD 200 budget is **account-wide**, not project-filtered, and alerts at 80% of actual spend. It does not stop resources or guarantee billing notifications arrive before a charge occurs.

| Cost driver | Baseline / effect |
|---|---|
| EC2 | Two running instances, EBS and detailed monitoring; extra capacity during scaling/refresh |
| NAT | Two zonal NAT gateways, hourly and processed-data charges |
| Public IPv4 | NAT EIPs and internet-facing load-balancer addressing can incur charges |
| ALB | Hours and capacity units |
| RDS | Multi-AZ database, storage, backup retention and snapshots |
| CloudFront / S3 | Requests, transfer, objects and version history |
| WAF | Web ACL, rules and request processing |
| CloudWatch | Logs, dashboard, alarms and metrics |
| Other | Secrets Manager, Route 53 and notifications as applicable |

Use the [AWS Pricing Calculator](https://calculator.aws/) and your account's billing reports. Costs are workload-, Region- and date-dependent; no unverified monthly estimate is included.

A cheaper single-NAT or single-AZ database variation changes availability and would not meet this project's stated HA baseline. For a short exercise, collect evidence and delete the lab when finished rather than claiming reduced-availability settings are equivalent.

## Cleanup procedure

1. Export the documentation and sanitized test evidence. Decide whether any lab data/snapshots must be retained.
2. Set `enable_db_bootstrap = false` and `deletion_protection = false` in tfvars; plan and apply the change.
3. Record the `artifact_bucket`, `static_bucket` and `db_identifier` outputs locally.
4. Use the S3 console **Empty** operation on only the two project application buckets. Delete all versions and delete markers; a simple `aws s3 rm --recursive` is insufficient for a versioned bucket. Verify the names carefully. **Do not empty the Terraform state bucket.**
5. Run a reviewed destroy plan:

```bash
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

6. RDS is configured to take a final snapshot. If that final snapshot identifier already exists from a previous deployment, use a unique identifier in `database.tf` before destruction. Verify the snapshot completed and decide whether to retain/delete it. Retained snapshots continue to incur costs.
7. Check for remaining NAT gateways, EIPs, EC2 instances, ALB, RDS, CloudFront, project log groups, S3 buckets/versions and snapshots. Some service-created log groups or retained backups may outlive the stack. App secret deletion has a seven-day recovery window.
8. Keep the state bucket and bootstrap state secured for audit/recovery. Its `prevent_destroy` deliberately blocks accidental deletion. Remove it only under a separate reviewed retention decision after the main stack is gone.
9. Update the README to state the infrastructure was removed after testing and keep the evidence links.

Destroying the lab deletes live application data. Final snapshots/state are sensitive even when the application is removed.
