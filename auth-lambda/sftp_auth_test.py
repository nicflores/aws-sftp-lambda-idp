import json
import boto3
import pytest
from moto import mock_aws

@pytest.fixture
def ssm_boto():
    ssm = boto3.client('secretsmanager', region_name='us-east-1')
    return ssm

@mock_aws
def test_lambda_handler(ssm_boto):
    # Create a mock secret
    username = 'testuser'
    bucket_name = 'testbucket'
    secret_name = f'testsftp-{username}'
    ssm_boto.create_secret(
        Name=secret_name,
        SecretString=json.dumps({
            'bucket_name': bucket_name,
            'ssh_key': "testsshkey"
        }))

    # Import your lambda handler function
    from sftp_auth import lambda_handler

    # Simulate the event object that AWS Lambda would pass to the handler
    event = {'username': username}
    context = {}

    expected_policy = json.dumps({
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

    expected_homedirectorydetails = json.dumps([{
        "Entry": '/smrd-product',
        "Target": f'/{bucket_name}/smrd-product'
    }])

    result = lambda_handler(event, context)

    assert json.dumps(json.loads(result['HomeDirectoryDetails'])) == expected_homedirectorydetails
    assert json.dumps(json.loads(result['Policy']), sort_keys=True) == expected_policy