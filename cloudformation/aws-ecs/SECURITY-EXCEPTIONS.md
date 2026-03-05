# Security Exceptions -- MCP Gateway Registry (CloudFormation)

This document records security findings from the infrastructure review, their
dispositions, and compensating controls for the CloudFormation workshop
deployment (`cloudformation/aws-ecs/`).

**Environment context:** Ephemeral AWS workshop accounts with limited lifespan.
No Route53 hosted zone or custom domain. CloudFront uses the default
`*.cloudfront.net` certificate.

---

## Finding 1: CloudFront WAF Not Enabled

**Disposition:** Accepted risk (stakeholder confirmed).

Workshop environment uses ephemeral accounts with short-lived infrastructure.
WAF cost is disproportionate to the risk profile for a non-production lab.

---

## Finding 2: ALB Listener Should Use HTTPS

**Disposition:** Exception -- no ACM certificate available without Route53.

**Architecture:**
```
Viewer --[HTTPS]--> CloudFront --[HTTP]--> ALB --[HTTP]--> ECS
```

**Compensating controls:**
- CloudFront enforces HTTPS for all viewer traffic (`ViewerProtocolPolicy:
  redirect-to-https`).
- ALB-to-origin traffic traverses within the VPC (not over the public internet).
- Auth-server uses the `X-Cloudfront-Forwarded-Proto` header (which ALB does not
  overwrite, unlike `X-Forwarded-Proto`) to build OAuth2 callback URLs. Without
  CloudFront, callback URLs default to `http://`, causing redirect URI mismatch
  at Keycloak -- effectively breaking all authenticated flows.
- When Route53 is enabled (`HasDnsConfig` condition), ALB listeners use HTTPS
  with `ELBSecurityPolicy-TLS13-1-2-2021-06` and ACM certificates.

**Why ALB HTTP cannot be changed:** The OAuth2 callback flow depends on the
current `CloudFront (HTTPS) -> ALB (HTTP)` path. Auth-server reads
`X-Cloudfront-Forwarded-Proto` to build correct HTTPS callback URLs for
Keycloak. Changing ALB to HTTPS or `OriginProtocolPolicy` to `https-only` would
break the OAuth2 redirect chain.

---

## Finding 3: IAM Policies Without Resource Constraints

**Disposition:** Scoped where possible; remaining wildcards documented.

**Code changes applied:**
- `EcsServiceLinkedRoleLambdaRole`: Split `iam:GetRole` to scoped ARN;
  `iam:CreateServiceLinkedRole` must remain `*` (AWS API requirement).
- `EcsTaskExecutionRole`: Logging resource scoped to
  `arn:aws:logs:${Region}:${AccountId}:*`.
- `DocumentDBInitLambdaRole`: `ecs:RunTask` and `ecs:DescribeTasks` scoped to
  environment-prefixed ARNs.
- `KeycloakInitLambdaRole`: Removed redundant `logs:*` inline statement
  (already covered by `AWSLambdaBasicExecutionRole` managed policy).
- `MCPServerRegistrationLambdaRole`: Same redundant `logs:*` removal.

**Remaining wildcards with justification:**
| Resource | Action | Justification |
|----------|--------|---------------|
| `EcsServiceLinkedRoleLambdaRole` | `iam:CreateServiceLinkedRole` | AWS API requires `Resource: '*'` |
| `EcsTaskRole` | `ssmmessages:*` | SSM Session Manager actions do not support resource-level permissions |
| `GrafanaTaskRole` | CloudWatch/Logs/EC2 read-only | Read-only describe/list/get actions do not support resource-level permissions |
| KMS key policies | `kms:*` / `kms:Encrypt` etc. | `Resource: '*'` in a KMS key policy means "this key" -- standard required AWS pattern |

---

## Finding 4: Security Group Allows 0.0.0.0/0 on Port 80

**Disposition:** Exception -- CloudFront managed prefix list exceeds SG quota.

The CloudFront origin-facing managed prefix list
(`com.amazonaws.global.cloudfront.origin-facing`) contains ~120+ CIDRs, which
exceeds the default security group rules-per-group quota (60 inbound rules).

**Compensating controls:**
- `IngressCidrBlocks` parameter is available to restrict source CIDRs when
  deploying to environments with known IP ranges.
- **OAuth2 flow breaks without CloudFront:** The auth-server uses a cascading
  header check (`X-Cloudfront-Forwarded-Proto` > `X-Forwarded-Proto` >
  `request.url.scheme`) to determine the original viewer protocol and build
  OAuth2 callback URLs. Requests that bypass CloudFront and hit the ALB directly
  lack the `X-Cloudfront-Forwarded-Proto: https` header, so callback URLs are
  built with `http://`. Keycloak's registered redirect URIs use HTTPS, causing
  the OAuth2 flow to fail with a redirect URI mismatch. This is not an explicit
  rejection -- unauthenticated static endpoints (e.g., health checks) remain
  accessible -- but all authenticated user flows are effectively blocked.
- Ephemeral workshop accounts with limited lifespan.

---

## Finding 5: ALB Should Drop Invalid Headers

**Disposition:** Fixed.

Added `routing.http.drop_invalid_header_fields.enabled = true` to both
`MainAlb` and `KeycloakAlb` in `compute-stack.yaml`. This drops headers with
non-RFC-7230-compliant field names. All standard and custom headers used by the
application (`X-Cloudfront-Forwarded-Proto`, `X-Forwarded-Proto`,
`Authorization`, etc.) are RFC-compliant and unaffected.

---

## Finding 6: ALB Listener Should Enforce TLS 1.2+

**Disposition:** Exception -- same root cause as Finding 2.

ALB listeners use HTTP (not HTTPS) because no ACM certificate exists without
Route53. TLS termination is handled at the CloudFront edge, which enforces
TLS 1.2+ for viewer connections. When Route53 is enabled, the conditional HTTPS
listener uses `ELBSecurityPolicy-TLS13-1-2-2021-06`.

---

## Finding 7: CloudFront Should Enforce TLS 1.2+

**Disposition:** Exception -- AWS limitation with default certificates.

The deployment uses `CloudFrontDefaultCertificate: true` (no custom domain).
AWS does not allow setting `MinimumProtocolVersion` when using the default
`*.cloudfront.net` certificate. Modern browsers and clients negotiate TLS 1.2+
by default. When Route53 is enabled, the custom certificate configuration uses
`TLSv1.2_2021` as the minimum protocol version.
