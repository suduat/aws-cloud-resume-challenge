import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Cloudresume-test")

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))

    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Content-Type": "application/json"
    }

    # Handle preflight
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": headers,
            "body": ""
        }

    try:
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

    except ClientError as e:
        print("DynamoDB error:", str(e))
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Database error"})
        }

    except Exception as e:
        print("General error:", str(e))
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
