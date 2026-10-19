# Package validation record

Prepared: **19 October 2026**. This record covers checks performed while preparing the source package, not AWS deployment certification.

| Check | Result | Scope |
|---|---|---|
| Application unit tests | PASS — 10 tests | Authentication, Unicode credentials, CSRF, parameterized writes, title length, output escaping, CSP asset path, liveness and readiness |
| Terraform formatting | PASS | `terraform fmt -check -recursive infra` |
| Terraform HCL parse | PASS — 12 .tf files | Python HCL parser; syntax only |
| Terraform provider initialization | PASS | Main and bootstrap configurations, backend disabled; provider checksums recorded |
| Terraform provider/schema validation | BLOCKED | This preparation environment disallows local Unix sockets needed by the provider processes |
| Shell syntax | PASS | Helper shell scripts and bootstrap template with sample substitutions |
| Template variable references | PASS | All eight user-data placeholders match Terraform input keys |
| Markdown local links | PASS | Repository-relative targets present |
| Diagram | PASS | PNG visually reviewed; SVG and editable draw.io XML generated; native AWS stencil identifiers, attached labels/connectors and container hierarchy checked; preview uses official AWS artwork |
| AWS plan/apply | NOT RUN | No AWS credentials or target account supplied |
| PostgreSQL integration/role grants | NOT RUN | Requires actual database deployment |
| Live scaling, failover, CDN, WAF and alert tests | NOT RUN | Follow TESTING.md |

## Runtime used for local checks

- Terraform CLI: 1.11.4.
- Python: 3.12 in the preparation environment; the EC2 bootstrap and GitHub workflow use Python 3.11.
- Application dependencies: exact versions in `app/requirements.txt`.
- Providers resolved: AWS 6.69.1, Archive 2.8.1, Random 3.9.1.

The local provider process error was `listen unix ...: socket: operation not permitted`. No privilege escalation or live deployment was attempted to work around it. The GitHub validation workflow runs the normal provider/schema validation in its runner after upload; review that result before deployment.

**Passing local tests is not proof that AWS IAM, quotas, regional class availability, DNS validation, RDS bootstrap or application networking will succeed in your account.** A clean Terraform plan and the documented live acceptance tests remain required.
