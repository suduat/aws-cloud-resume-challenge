### **Setup**
```bash
# Clone repository
git clone https://github.com/suduat/aws-cloud-resume-challenge.git
cd aws-cloud-resume

# Install Python dependencies
pip install -r requirements.txt

# Run tests locally
cd lambda
pytest tests/ -v

# Initialize Terraform
cd terraform
terraform init
terraform plan
```