# Issue: Session Cookie `Secure` Flag Not Set When Using CloudFront → ALB → ECS Architecture

## Summary

The v1.0.7 session cookie security feature doesn't work correctly when deployed with CloudFront terminating TLS in front of an ALB with HTTP listeners.

## Problem

In v1.0.7, the auth-server checks `x-forwarded-proto` to determine if the original request was HTTPS before setting the `Secure` flag on session cookies (`auth_server/server.py` lines 1798-1803):

```python
x_forwarded_proto = request.headers.get("x-forwarded-proto", "")
is_https = x_forwarded_proto == "https" or request.url.scheme == "https"
cookie_secure = cookie_secure_config and is_https
```

However, when deployed with **CloudFront → ALB (HTTP listener) → ECS**, the ALB **always overwrites** the `x-forwarded-proto` header with its own value based on the ALB listener protocol. Since the ALB listener is HTTP (CloudFront terminates TLS), the header becomes `x-forwarded-proto: http` regardless of what CloudFront sent.

## Evidence

Auth-server log output:
```
Auth server setting session cookie: secure=False (config=True, is_https=False), 
samesite=lax, domain=not set, x-forwarded-proto=http, request_scheme=http
```

Even though:
- User accessed via HTTPS through CloudFront
- `SESSION_COOKIE_SECURE=true` is configured
- CloudFront sends `X-Forwarded-Proto: https` custom header

## Root Cause

AWS ALB behavior: ALB sets `x-forwarded-proto`, `x-forwarded-for`, and `x-forwarded-port` headers based on its own listener configuration, overwriting any incoming values. This is [documented AWS behavior](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/x-forwarded-headers.html) and cannot be disabled.

## Recommended Fix

Add support for a CloudFront-specific custom header that ALB won't overwrite. In `auth_server/server.py`:

```python
# Check if HTTPS is terminated at load balancer
# Support both standard x-forwarded-proto and CloudFront custom header
# (ALB overwrites x-forwarded-proto, so CloudFront deployments need a custom header)
x_forwarded_proto = request.headers.get("x-forwarded-proto", "")
cloudfront_proto = request.headers.get("x-cloudfront-forwarded-proto", "")
is_https = (
    cloudfront_proto == "https" or 
    x_forwarded_proto == "https" or 
    request.url.scheme == "https"
)
```

Then CloudFront origins can be configured with custom header:
```yaml
OriginCustomHeaders:
  - HeaderName: X-Cloudfront-Forwarded-Proto
    HeaderValue: https
```

## Alternative Solutions

1. **HTTPS listener on ALB** - Requires ACM certificate on ALB, more complex setup, additional cost
2. **Environment variable override** - Add `FORCE_HTTPS_COOKIES=true` to bypass the header check entirely (less secure, doesn't validate actual HTTPS)

## Affected Deployments

Any deployment using:
- CloudFront (or other CDN) for TLS termination
- ALB with HTTP listener forwarding to ECS/containers
- The v1.0.7 session cookie security feature (`SESSION_COOKIE_SECURE=true`)

## Architecture Diagram

```
User (HTTPS) → CloudFront (TLS termination) → ALB (HTTP) → ECS Container
                     │                            │
                     │ Sets custom header:        │ Overwrites with:
                     │ X-Forwarded-Proto: https   │ x-forwarded-proto: http
                     │                            │
                     └────────────────────────────┘
                              Header lost!
```

## Workaround (Until Fix is Released)

For CloudFormation deployments, the workaround is to:
1. Add HTTPS listener on ALB with ACM certificate
2. Or accept that cookies won't have `Secure` flag (not recommended for production)
