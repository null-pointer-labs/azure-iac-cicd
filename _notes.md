Add user to:
- Storage Blob Data Contributor

# Create SA:
az storage container create --name tfstate --account-name egubibackendsa

terraform init -backend-config=backend.hcl