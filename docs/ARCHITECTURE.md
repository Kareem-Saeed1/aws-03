# Architecture decisions

## Network layout

Default Region: `eu-west-1` in the example input; actual AZ names are selected from the first two available AZs returned by AWS.

| Tier | AZ A CIDR | AZ B CIDR | Default route | Exposure |
|---|---|---|---|---|
| Public | 10.40.0.0/24 | 10.40.1.0/24 | Internet Gateway | ALB and zonal NAT only |
| Application | 10.40.10.0/24 | 10.40.11.0/24 | Same-AZ NAT | Private EC2, no public IP |
| Database | 10.40.20.0/24 | 10.40.21.0/24 | None | Private RDS subnet group |

Public subnets do not automatically assign public addresses to arbitrary EC2 instances. The internet-facing ALB and NAT gateways manage their own public connectivity. The S3 gateway endpoint is associated with application route tables. SSM, Secrets Manager, CloudWatch, package downloads and certificate bundle retrieval use outbound HTTPS through NAT.

Default NACLs are retained; tier isolation is enforced by security groups. This choice is explicit rather than claiming custom NACL hardening. Review `SECURITY.md` before adding stateless subnet filters.

## Application traffic

- Route 53 `app` alias → ALB, with Evaluate Target Health enabled.
- ALB HTTP :80 → redirect to HTTPS :443.
- HTTPS listener → host-header match → application target group HTTP :8000.
- Listener default returns 404 for unknown hosts.
- WAF is attached to the ALB; it is not a separate appliance or subnet hop.
- `/health` checks process liveness for target registration and ASG health.
- `/ready` verifies access to the runtime database table; use it for end-to-end verification.

Using liveness for ALB/ASG avoids replacing healthy application instances just because the shared database temporarily fails over. The application returns 503 during a DB outage. A production design should add an authenticated synthetic transaction monitor and tune readiness/health semantics to its requirements.

## Static traffic

Route 53 `static` alias → CloudFront → private S3 regional REST origin with OAC. There is no S3 website endpoint and no public S3 read policy. Versioned asset paths use a content hash; immutable caching does not require invalidation for a new release. Only GET and HEAD are enabled. The CloudFront certificate is in `us-east-1`; the ALB certificate is in the workload Region.

The static distribution has no application authentication because CSS is public content. Application pages and database operations bypass CloudFront by design and return `Cache-Control: no-store`. Do not place sensitive files in `app/static`.

## Database

This is an **RDS Multi-AZ DB instance deployment**, not a three-instance Multi-AZ DB cluster. One standby is used for failover; it does not serve application reads. Primary and standby AZ positions in the diagram are illustrative and can swap on failover. The application uses the RDS endpoint, not fixed database IPs. Each request creates a fresh, short-timeout connection; future requests reconnect after DNS/failover recovery. There is no transparent retry of writes, avoiding accidental duplicate submissions.

TLS uses `verify-full` with the RDS CA bundle. The dedicated runtime role has SELECT/INSERT rights on the single table, not schema creation or administrative rights. A temporary EC2 IAM policy permits one-time administrative initialization, then must be removed.

## Availability and scale

The ASG spans two private subnets, targets two instances and enables rolling instance refresh on Launch Template changes. Distribution across AZs is best effort subject to capacity. Default CPU target is 50%; it is a starting exercise value, not production sizing. Step scaling is a separate switchable mode so both methods can be learned without competing policies.

`desired_capacity` is ignored for normal Terraform drift reconciliation so Terraform does not reset a scaling decision. Max capacity remains managed. Rolling refresh is configured to maintain 100% healthy capacity and may temporarily require additional quota/capacity. Minimum two instances alone does not establish a tested availability SLA.

## Operational boundaries

No multi-Region DR, cross-account security architecture, CloudTrail organization trail, customer SSO, deployment pipeline, VPC flow logs, ALB access-log bucket or restore certification is included. The example has app/bootstrap/WAF logs and alarms; expand observability and resilience for the production requirements.

Route 53 health evaluation does not supply a second failover endpoint. Regional ALB and ASG resilience handles this project's instance/AZ distribution. Regional disaster recovery is outside scope.

Sources: [AWS VPC reference](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html), [RDS Multi-AZ](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html), [CloudFront OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html), [Route 53 alias health](https://docs.aws.amazon.com/Route53/latest/APIReference/API_AliasTarget.html).
