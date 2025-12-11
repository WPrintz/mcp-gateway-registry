# SSM Parameter Store Security Review

## Summary

During the CloudFormation port of the MCP Gateway infrastructure, we identified that sensitive credentials (database passwords, admin credentials) are being stored in SSM Parameter Store as **plaintext String type** rather than **SecureString type**. This is a security concern that should be addressed in both the Terraform and CloudFormation implementations.

## Current State

### What We Found

The following SSM parameters contain sensitive data but are stored as `String` type:

| Parameter Path | Contains | Current Type | Should Be |
|----------------|----------|--------------|-----------|
| `/keycloak/admin` | Admin username | String | SecureString |
| `/keycloak/admin_password` | Admin password | String | **SecureString** |
| `/keycloak/database/url` | DB connection string | String | SecureString |
| `/keycloak/database/username` | DB username | String | SecureString |
| `/keycloak/database/password` | DB password | String | **SecureString** |

### Security Impact

1. **Plaintext in AWS Console** - String parameters are visible in plaintext in the AWS Console, CloudTrail logs, and API responses
2. **No encryption at rest** - String parameters are not encrypted with KMS
3. **Broader access** - Anyone with `ssm:GetParameter` permission can read the values without needing KMS decrypt permissions
4. **Compliance risk** - May not meet security compliance requirements (SOC2, PCI-DSS, etc.)

## Terraform Code Reference

In `terraform/keycloak-ssm.tf` (or similar), the parameters are likely defined as:

```hcl
resource "aws_ssm_parameter" "keycloak_admin_password" {
  name  = "/keycloak/admin_password"
  type  = "String"  # <-- This should be "SecureString"
  value = var.keycloak_admin_password
}
```

## Recommended Fix

### Option 1: Use SecureString (Recommended)

```hcl
resource "aws_ssm_parameter" "keycloak_admin_password" {
  name   = "/keycloak/admin_password"
  type   = "SecureString"
  value  = var.keycloak_admin_password
  key_id = aws_kms_key.ssm_key.id  # Optional: use custom KMS key
}
```

**Pros:**
- Free (no additional cost over String type)
- Encrypted at rest with KMS
- Requires `kms:Decrypt` permission to read
- Better audit trail

**Cons:**
- Requires KMS key management (or use default `aws/ssm` key)

### Option 2: Migrate to Secrets Manager

```hcl
resource "aws_secretsmanager_secret" "keycloak_credentials" {
  name = "mcp-gateway/keycloak/credentials"
}

resource "aws_secretsmanager_secret_version" "keycloak_credentials" {
  secret_id = aws_secretsmanager_secret.keycloak_credentials.id
  secret_string = jsonencode({
    admin_username = var.keycloak_admin
    admin_password = var.keycloak_admin_password
    db_username    = var.keycloak_db_username
    db_password    = var.keycloak_db_password
  })
}
```

**Pros:**
- Automatic rotation support
- Cross-account sharing
- Fine-grained access policies
- Native integration with RDS, ECS, Lambda

**Cons:**
- Cost: ~$0.40/secret/month + $0.05 per 10,000 API calls
- More complex to set up

## CloudFormation Workaround

CloudFormation's `AWS::SSM::Parameter` resource doesn't support `Type: SecureString` with dynamic values. We implemented a Lambda custom resource to work around this:

```yaml
SsmSecureStringLambda:
  Type: AWS::Lambda::Function
  # Creates SecureString parameters via AWS SDK

KeycloakAdminPasswordParameter:
  Type: Custom::SsmSecureString
  Properties:
    ServiceToken: !GetAtt SsmSecureStringLambda.Arn
    ParameterName: /keycloak/admin_password
    ParameterValue: !Ref KeycloakAdminPassword
    ParameterType: SecureString
```

## Questions for Discussion

1. Was `String` type intentional (e.g., for simplicity in workshops) or an oversight?
2. Should we standardize on SSM SecureString or Secrets Manager for all sensitive data?
3. Do we need a custom KMS key, or is the default `aws/ssm` key acceptable?
4. Should we add a pre-commit hook or CI check to prevent `type = "String"` for parameters matching `/password|secret|key|credential/i`?

## Action Items

- [ ] Review Terraform SSM parameter definitions
- [ ] Change `type = "String"` to `type = "SecureString"` for sensitive parameters
- [ ] Update ECS task definitions if needed (SecureString works the same way with `valueFrom`)
- [ ] Consider adding Terraform validation to prevent plaintext secrets
- [ ] Update documentation

## References

- [AWS SSM Parameter Store SecureString](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-securestring.html)
- [Terraform aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)
- [ECS Secrets from SSM](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-parameters.html)

---

*Document created during CloudFormation port - December 2025*
