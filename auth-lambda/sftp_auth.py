import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Extract the username from the event
    username = event['username']
    # Construct the secret name based on the username
    secret_name = f'testsftp-{username}'

    # Initialize the AWS Secrets Manager client
    client = boto3.client('secretsmanager', region_name='us-east-1')

    try:
        # Retrieve the secret value, which contains the S3 bucket name
        get_secret_value_response = client.get_secret_value(SecretId=f'{secret_name}')
        secret = get_secret_value_response['SecretString']

        # Extract secrets
        secret_dict = json.loads(secret)
        bucket_name = secret_dict['bucket_name']
        ssh_key = secret_dict['ssh_key']
        homedirectory = secret_dict['home_directory']
        rolearn = secret_dict['role_arn']

        if not ssh_key:
            return {
                'statusCode': 400,
                'body': json.dumps(f'SSH public key not found for user: {username}')
            }

        # Construct the HomeDirectory based on the bucket name
        home_directory_mapping = json.dumps([{
                "Entry": f'/{homedirectory}',
                "Target": f'/{bucket_name}/{homedirectory}'
            }])
        
        policy = json.dumps({
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Sid': 'ListBucketItems',
                    'Effect': 'Allow',
                    'Action': [
                        's3:ListBucket',
                        's3:GetBucketLocation'
                    ],
                    'Resource': f'arn:aws:s3:::{bucket_name}'
                },
                {
                    'Sid': 'BucketPermissions',
                    'Effect': 'Allow',
                    'Action': [
                        's3:GetObjectAcl',
                        's3:GetObject',
                        's3:GetObjectVersion'
                    ],
                    'Resource': f'arn:aws:s3:::{bucket_name}/*'
                }
            ]
        }, sort_keys=True)

        return {
            'Role': f'{rolearn}',
            'PublicKeys': [f'{ssh_key}'],
            'Policy': policy,
            'HomeDirectoryType': 'LOGICAL',
            'HomeDirectoryDetails': f'{home_directory_mapping}'
        }
    
    except client.exceptions.ResourceNotFoundException:
        # If the secret doesn't exist, deny access
        return {
            'statusCode': 400,
            'body': json.dumps(f'User does not exist: {username}')
        }

    except Exception as e:
        # Handle any other exception
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error processing request: {str(e)}')
        }