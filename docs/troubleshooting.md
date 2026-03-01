## 🐛 Troubleshooting

### **"Access Denied" on CloudFront**
- Ensure S3 bucket policy allows CloudFront OAC
- Check that public access is blocked on S3
- Verify CloudFront origin is set to OAC (not legacy OAI)

### **Visitor counter not updating**
- Check Lambda function logs in CloudWatch
- Verify API Gateway integration with Lambda
- Test Lambda Function URL directly
- Check CORS configuration

### **Certificate issues**
- ACM certificate MUST be in us-east-1 for CloudFront
- Ensure DNS validation is complete in Route53
- Check certificate status is "Issued"

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more details.