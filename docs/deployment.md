## 🚢 Deployment
## CI/CD Pipeline

```
Push to main
     │
     ▼
┌─────────────────┐
│  GitHub Actions │
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────────┐
    ▼         ▼        ▼            ▼
  Test    Terraform  Deploy    Integration
  Lambda    Plan     Infra       Test
    │         │        │            │
    └─────────┴────────┴────────────┘
                  │
                  ▼
         ✅ Deployed to AWS
```
### **Automated (GitHub Actions)**
Push to `main` branch triggers automatic deployment:
1. Run unit tests
2. Terraform validate & plan
3. Terraform apply (on main only)
4. Run integration tests
5. Invalidate CloudFront cache

### **Manual Deployment**
```bash
# Backend infrastructure
cd terraform
terraform init
terraform apply

# Frontend
cd html5up-strata
aws s3 sync . s3://[bucket-name] --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id [DISTRIBUTION_ID] \
  --paths "/*"
```