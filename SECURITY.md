# Security Policy

## Supported Versions

We actively support security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < Latest| :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these steps:

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

1. **Email**: Send an email to [your-email@example.com] (replace with your actual email)
2. **GitHub Security Advisory**: Use GitHub's [Private Vulnerability Reporting](https://github.com/[your-username]/gh-account-guard/security/advisories/new) feature if available

### What to Include

When reporting a vulnerability, please include:

- A clear description of the vulnerability
- Steps to reproduce the issue
- Potential impact (e.g., data exposure, unauthorized access)
- Any suggested fixes or mitigations (if you have them)
- Your contact information (if you'd like to be credited)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Depends on severity and complexity

### What We Consider Security Issues

Security issues include, but are not limited to:

- Authentication bypasses or unauthorized access
- Exposure of sensitive data (credentials, tokens, keys)
- Remote code execution vulnerabilities
- Privilege escalation issues
- Configuration issues that could lead to security breaches
- Issues with Git identity enforcement that could lead to incorrect attribution

### What We Don't Consider Security Issues

The following are **not** considered security issues:

- Missing or unclear documentation
- Feature requests
- Issues that require physical access to your machine
- Issues that require already compromised credentials
- Social engineering attacks
- Denial of service attacks that don't affect the core functionality

### Recognition

We appreciate responsible disclosure. With your permission, we would like to:

- Credit you in our security advisories
- Include you in our CHANGELOG.md (if you wish)
- Thank you publicly (if you're comfortable with that)

### Safe Harbor

We support responsible disclosure. Any activities conducted in a manner consistent with this policy will be considered authorized conduct and we will not pursue legal action against you. If legal action is initiated by a third party against you in connection with activities conducted in accordance with this policy, we will take steps to make it known that your actions were conducted in compliance with this policy.

## Security Best Practices

When using this extension:

1. **Protect your configuration file**: The config file at `~/.config/gh/account-guard.yml` contains sensitive information. Ensure it has appropriate file permissions (e.g., `chmod 600`).

2. **Review your profiles**: Regularly review your configured profiles to ensure they're correct and up-to-date.

3. **Use signing keys securely**: Store your SSH/GPG signing keys securely and never commit them to version control.

4. **Keep dependencies updated**: Keep `yq` and other dependencies up-to-date to benefit from security patches.

5. **Audit shell hooks**: If you install shell hooks, review them before adding to your shell configuration.

## Questions?

If you have questions about this security policy, please open a public GitHub issue with the `question` label.


