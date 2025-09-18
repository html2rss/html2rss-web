# Security Guide for html2rss-web

## 🔒 **Security Overview**

This document outlines the security features and best practices for the html2rss-web authentication system, including the new unified auth system with public feed access.

## 🛡️ **Security Features**

### **Feed Token Security**
- **HMAC-SHA256 Signing**: All feed tokens are cryptographically signed to prevent tampering
- **URL Binding**: Tokens are bound to specific URLs and cannot be used for other sites
- **10-Year Expiry**: Tokens expire after 10 years to balance security with RSS user experience
- **Stateless Validation**: No server-side storage required, tokens are self-validating
- **Public Access**: Secure public URLs for sharing feeds without authentication headers

### **Authentication Security**
- **Bearer Token Authentication**: Uses standard HTTP Authorization headers
- **URL-Based Access Control**: Users can only access URLs they're explicitly allowed
- **Admin Override**: Admin users can access any URL with wildcard permissions (`"*"`)
- **Secret Key Protection**: HMAC signing uses a server-side secret key
- **Input Validation**: Comprehensive URL validation and XML sanitization
- **CSP Headers**: Content Security Policy headers prevent XSS attacks

## 🔧 **Production Security Checklist**

### **Before Deployment**

- [ ] **Generate Strong Secret Key**
  ```bash
  # Generate a cryptographically secure secret key
  openssl rand -hex 32
  ```

- [ ] **Generate Strong User Tokens**
  ```bash
  openssl rand -hex 32
  ```

- [ ] **Set Environment Variables**
  ```bash
  export HTML2RSS_SECRET_KEY="your-generated-secret-key-here"
  ```

- [ ] **Configure User Accounts**
  - Remove default accounts from `config/feeds.yml`
  - Add only necessary user accounts
  - Use strong, unique tokens for each user
  - Set appropriate URL restrictions

- [ ] **Review URL Restrictions**
  - Admin accounts: `["*"]` for full access
  - Regular users: Specific domains only
  - Avoid overly broad patterns like `["https://*"]`

### **After Deployment**

- [ ] **Monitor Access Logs**
  - Watch for failed authentication attempts
  - Monitor for unusual access patterns
  - Check for attempts to access disallowed URLs

- [ ] **Regular Security Updates**
  - Keep dependencies updated
  - Rotate secret keys periodically (requires regenerating all feed tokens)
  - Review and update user permissions

- [ ] **Backup Configuration**
  - Keep secure backups of `config/feeds.yml`
  - Store secret keys securely (consider using a secrets manager)

## 🚨 **Security Considerations**

### **Feed Token Exposure**
- **Risk**: Feed tokens are visible in URLs and could be logged
- **Mitigation**: 
  - Tokens are URL-bound and cannot be used for other sites
  - Tokens expire after 10 years
  - Monitor access logs for suspicious activity

### **Secret Key Management**
- **Risk**: Secret key compromise would allow token forgery
- **Mitigation**:
  - Use environment variables for secret keys
  - Rotate keys periodically
  - Never commit secret keys to version control

### **URL Access Control**
- **Risk**: Users might access unauthorized sites
- **Mitigation**:
  - Implement strict URL allowlists
  - Use specific domain patterns, not wildcards
  - Regular audit of user permissions

### **Token Tampering**
- **Risk**: Attackers might try to modify tokens
- **Mitigation**:
  - HMAC-SHA256 signatures prevent tampering
  - Any modification invalidates the token
  - Server validates signatures on every request

### **Public Feed Access**
- **Risk**: Public URLs could be shared or logged, exposing feed access
- **Mitigation**:
  - Tokens are URL-bound and cannot be used for other sites
  - 10-year expiry balances security with RSS usability
  - No sensitive data in public URLs (only feed ID and signed token)
  - URL validation prevents access to unauthorized domains

## 🔍 **Security Monitoring**

### **Log Analysis**
Monitor these patterns in your logs:
- Multiple failed authentication attempts
- Requests to disallowed URLs
- Unusual access patterns
- Token validation failures

### **Alert Thresholds**
Consider setting up alerts for:
- More than 10 failed auth attempts per minute
- Requests to blocked domains
- Invalid token attempts
- Server errors

## 🛠️ **Incident Response**

### **If Secret Key is Compromised**
1. **IMMEDIATE ACTION REQUIRED** - This is a critical security incident
2. Generate new secret key immediately:
   ```bash
   openssl rand -hex 32
   ```
3. Update `HTML2RSS_SECRET_KEY` environment variable
4. Restart the application immediately
5. **All existing feed tokens will become invalid** - this breaks service for all URLs
6. Notify all users that they need to regenerate their feeds
7. Monitor logs for any suspicious activity during the compromise period
8. Consider rotating all user tokens as an additional security measure

**⚠️ Service Impact**: All public feed URLs will stop working until users regenerate them. This is intentional and necessary for security.

### **If User Token is Compromised**
1. Remove the compromised account from `config/feeds.yml`
2. Generate new token for the user:
   ```bash
   openssl rand -hex 32
   ```
3. Update configuration and restart
4. User's existing feeds will stop working until regenerated
5. If the compromise was widespread, consider rotating the secret key as well

### **If Feed Token Causes Trouble**
1. **Identify the problematic token** from logs or reports
2. **Rotate the secret key** to invalidate ALL feed tokens:
   ```bash
   # Generate new secret key
   openssl rand -hex 32
   # Update environment variable
   export HTML2RSS_SECRET_KEY="new-secret-key-here"
   # Restart application
   docker-compose restart
   ```
3. **All feed URLs will break** - this is the only way to invalidate specific tokens
4. Notify users to regenerate their feeds
5. Monitor for any continued issues

**⚠️ Important**: There is no way to invalidate individual feed tokens without breaking all of them. This is by design for security - if a token is compromised, all tokens must be rotated.

### **Understanding Stateless Token Design**

The feed token system is intentionally stateless for security and scalability reasons:

- **No Server Storage**: Tokens are self-contained and don't require database lookups
- **Cryptographic Validation**: Each token is validated using HMAC signatures
- **URL Binding**: Tokens only work for their specific URL
- **No Revocation List**: Individual tokens cannot be revoked without affecting all tokens

**Trade-offs**:
- ✅ **Pros**: No database required, scales infinitely, no single point of failure
- ⚠️ **Cons**: Cannot revoke individual tokens, must rotate secret key to invalidate all tokens

### **Recovery Procedures After Token Rotation**

When you rotate the secret key, follow these steps to minimize service disruption:

1. **Pre-rotation Communication**
   - Notify users in advance if possible
   - Provide clear instructions for regenerating feeds
   - Set maintenance window if needed

2. **Post-rotation Support**
   - Update documentation with new feed generation process
   - Provide clear error messages for broken feeds
   - Monitor for user questions and provide support

3. **Monitoring After Rotation**
   - Watch for failed authentication attempts
   - Monitor error rates for feed access
   - Check logs for any security issues

### **If Unauthorized Access is Detected**
1. Review access logs to identify the source
2. Check if any accounts were compromised
3. Consider rotating affected tokens
4. Update URL restrictions if needed

## 📋 **Regular Security Tasks**

### **Monthly**
- Review access logs for anomalies
- Check for failed authentication attempts
- Verify user permissions are still appropriate

### **Quarterly**
- Rotate secret keys (requires regenerating all feeds)
- Review and update user accounts
- Update dependencies
- Test backup and recovery procedures

### **Annually**
- Complete security audit
- Review and update security policies
- Consider penetration testing
- Update documentation

## 🚨 **Emergency Quick Reference**

### **Secret Key Compromised - IMMEDIATE ACTION**
```bash
# 1. Generate new secret key
openssl rand -hex 32

# 2. Update environment variable
export HTML2RSS_SECRET_KEY="new-secret-key-here"

# 3. Restart application
docker-compose restart

# 4. Notify users to regenerate feeds
```

### **User Token Compromised**
```bash
# 1. Remove from config/feeds.yml
# 2. Generate new token
openssl rand -hex 32
# 3. Update config and restart
docker-compose restart
```

### **Feed Token Causing Issues**
```bash
# Rotate secret key (breaks ALL feeds)
openssl rand -hex 32
export HTML2RSS_SECRET_KEY="new-secret-key-here"
docker-compose restart
```

## 🔗 **Additional Resources**

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Ruby Security Best Practices](https://guides.rubyonrails.org/security.html)
- [HMAC Security Considerations](https://tools.ietf.org/html/rfc2104)
