# Get your RDS endpoint first
export DB_ENDPOINT=$(aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='securecloud-mysql-staging'].Endpoint.Address" \
  --output text \
  --region us-east-1)

echo "DB endpoint: $DB_ENDPOINT"

# Create the secret
aws secretsmanager create-secret \
  --name "securecloud/db-credentials" \
  --description "MySQL credentials for SecureCloud-Flask" \
  --secret-string "{
    \"username\": \"admin\",
    \"password\": \"CHANGE-THIS-TO-STRONG-PASSWORD\",
    \"host\": \"$DB_ENDPOINT\",
    \"dbname\": \"flaskdb\",
    \"port\": \"3306\"
  }" \
  --region us-east-1

echo "Secret created!"

aws secretsmanager rotate-secret \
  --secret-id "securecloud/db-credentials" \
  --rotation-rules AutomaticallyAfterDays=30 \
  --region us-east-1