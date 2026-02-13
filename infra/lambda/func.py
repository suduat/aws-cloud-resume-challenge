import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Cloudresume-test')

def lambda_handler(event, context):

    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    }

    try:
        # Get HTTP method safely
        method = event.get("requestContext", {}).get("http", {}).get("method")
        if not method:
            method = event.get("requestContext", {}).get("method")

        if method == "OPTIONS":
            return {
                "statusCode": 200,
                "headers": headers,
                "body": ""
            }

        response = table.get_item(Key={"id": "0"})
        views = int(response.get("Item", {}).get("views", 0)) + 1

        table.put_item(
            Item={
                "id": "0",
                "views": views
            }
        )

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"views": views})
        }

    except Exception as e:
        print("ERROR:", str(e))
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
