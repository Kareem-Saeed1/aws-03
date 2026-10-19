# Security design

## Network permissions

| Source | Destination | Port | Purpose |
|---|---|---|---|
| Internet | ALB SG | TCP 80,443 | HTTP redirect and HTTPS application |
| ALB SG | App SG | TCP 8000 | Application and health checks |
| App SG | DB SG | TCP 5432 | Verified PostgreSQL TLS |
| App SG | External/AWS HTTPS endpoints | TCP 443 | Package retrieval, SSM, secrets, logging, S3 |
| CloudFront | Private static S3 | HTTPS | Signed OAC requests restricted by distribution ARN |
| Operator | SSM service | HTTPS | Authorized Session Manager session |

No inbound SSH rule and no EC2 public IP. RDS has no public access and no general internet route. Application-to-ALB backend traffic is HTTP within the VPC; this is **not end-to-end TLS**. Add backend TLS if your security requirements demand it.

Default VPC NACLs allow traffic; security groups enforce the table above. If implementing custom NACLs, account for their stateless behavior and ephemeral return ports for ALB-to-EC2, EC2-to-RDS, NAT and HTTPS responses. Validate both directions before tightening them.

## Credentials and IAM

- EC2 authenticates through its instance profile; IMDSv2 is required.
- RDS manages the master secret. Only the temporary bootstrap policy grants runtime instances access to it.
- The app secret contains a dedicated database login, demo login and signing key. The application retrieves it from Secrets Manager with a bounded cache.
- **Terraform state contains generated application secret values.** Keep the encrypted/versioned state bucket private with tightly scoped IAM; encryption alone does not prevent authorized state readers from seeing credentials.
- Set `enable_db_bootstrap = false` after initialization. Do not leave temporary administrative access enabled.
- Runtime database grants are limited to the demonstration table. No raw secret values appear in Launch Template user data; only secret ARNs are passed.
- Rotation of the app database password requires updating the DB role and secret coherently, and restarting the app when rotating its session signing key. Automatic coordinated app-secret rotation is not implemented.

## Application controls

HTTP Basic Authentication over HTTPS protects the shared demo. It is not a per-user authorization system. Forms use a session CSRF token. Queries use parameters; templates autoescape task titles. Responses set no-store, CSP, HSTS in AWS, nosniff, frame denial and same-origin referrer policy. Titles are limited to 200 characters; request body size is limited. The demo has no file upload or privileged administration endpoint.

The isolated local-development environment variable enables local DB connections without TLS; do not set `LOCAL_DEVELOPMENT=1` on AWS.

## WAF

Managed rule groups are a baseline against common attacks, not a guarantee of complete OWASP Top 10 protection. Rules are initially configured to block for this isolated demo. Tune exclusions only after inspecting legitimate requests. Before a real production rollout, test in Count mode where appropriate and review false positives.

The deterministic `x-lab-waf-test: block-me` rule provides harmless evidence of WAF enforcement. A 403 from that rule does not prove every managed rule is effective. Rate limit defaults to 2,000 requests per source IP per default five-minute evaluation window; account for shared NAT/proxy users before changing it.

WAF log configuration redacts Authorization and Cookie headers. Request sampling is disabled because logging redaction does not automatically redact sampled requests. Logs can still contain request paths or user-generated content: keep sensitive data out of URLs, restrict log access and review evidence before publication.

## Production hardening

Before representing this as production-ready, complete a risk review and at least:

- Replace shared Basic Authentication with an identity provider, per-user authorization and auditability.
- Confirm deployment-specific least-privilege IAM, especially CloudWatch managed policies and temporary bootstrap controls.
- Build/scan immutable AMIs or controlled artifacts; avoid reliance on internet package installation during scale-out.
- Pin/test the AMI and periodically roll out patches; the current public SSM AMI lookup intentionally follows the latest AL2023 image at planning time.
- Establish database migration/versioning and coordinated secret rotation.
- Add ALB access logs, VPC Flow Logs, appropriate CloudTrail/Security Hub/GuardDuty controls, synthetic monitoring and SSM session logging according to organizational policy.
- Complete backup restoration and RTO/RPO exercises; seven-day retention alone does not establish recovery readiness.
- Load-test connection limits, capacity, scaling thresholds and CPU-credit behavior; use larger/non-burstable classes where justified.
- Add dependency/security scanning, release approvals and an OIDC deployment role if introducing GitHub CD.
- Review backend TLS, egress restrictions, WAF tuning, log retention, data residency and DR requirements.

Sources: [AWS WAF baseline groups](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html), [WAF testing](https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-testing.html), [SSM instance permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html), [Terraform sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data).
