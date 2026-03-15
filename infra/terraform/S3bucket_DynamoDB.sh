# Get your account ID first
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your account ID: $AWS_ACCOUNT_ID"

# Create S3 bucket for Terraform state
aws s3 mb s3://securecloud-terraform-state-$AWS_ACCOUNT_ID \
    --region us-east-1

# Enable versioning (lets you roll back state)
aws s3api put-bucket-versioning \
    --bucket securecloud-terraform-state-$AWS_ACCOUNT_ID \
    --versioning-configuration Status=Enabled

# Enable encryption on the bucket
aws s3api put-bucket-encryption \
    --bucket securecloud-terraform-state-$AWS_ACCOUNT_ID \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

echo "Done! Bucket: securecloud-terraform-state-$AWS_ACCOUNT_ID"