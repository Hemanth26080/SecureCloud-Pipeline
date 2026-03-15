import os
import json
import boto3
import mysql.connector
from mysql.connector import pooling

def get_secret():
    """Fetch DB credentials from AWS Secrets Manager (never hardcode passwords!)"""
    secret_name = os.environ.get("DB_SECRET_NAME", "securecloud/db-credentials")
    region = os.environ.get("AWS_REGION", "eu-west-3")

    client = boto3.client("secretsmanager", region_name=region)
    secret = client.get_secret_value(SecretId=secret_name)
    return json.loads(secret["SecretString"])

def get_db_pool():
    """Create a connection pool (reuses connections instead of opening new ones)"""
    # In dev, use env vars directly. In prod, use Secrets Manager.
    if os.environ.get("USE_SECRETS_MANAGER", "false") == "true":
        creds = get_secret()
    else:
        creds = {
            "username": os.environ.get("DB_USER", "flask_user"),
            "password": os.environ.get("DB_PASSWORD", "changeme"),
            "host":     os.environ.get("DB_HOST", "localhost"),
            "dbname":   os.environ.get("DB_NAME", "flaskdb"),
        }

    pool = pooling.MySQLConnectionPool(
        pool_name="securecloud",
        pool_size=5,
        host=creds["host"],
        user=creds["username"],
        password=creds["password"],
        database=creds["dbname"],
        ssl_ca="/etc/ssl/certs/ca-certificates.crt",  # Encrypted connection
        ssl_verify_cert=True,
    )
    return pool
