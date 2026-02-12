import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Cloudresume-test')

def lambda_handler(event, context):
    # Simple CORS headers - just the asterisk
    cors_headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
    }
    
    # Handle OPTIONS preflight
    http_method = event.get('requestContext', {}).get('http', {}).get('method', '')
    
    if http_method == 'OPTIONS':
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": ""
        }
    
    try:
        # Get current views
        response = table.get_item(Key={'id': '0'})
        
        if 'Item' not in response:
            views = 1
        else:
            views = int(response['Item'].get('views', 0)) + 1
        
        # Update views
        table.put_item(
            Item={
                'id': '0',
                'views': views
            }
        )
        
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps({"views": views})
        }
        
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": "Database error"})
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": str(e)})
        }