import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('MyDynamoDBTable')

def lambda_handler(event, context):
    try:
        if event['httpMethod'] == 'GET':
            response = table.scan()
            return {
                'statusCode': 200,
                'body': json.dumps(response['Items'])
            }
        elif event['httpMethod'] == 'POST':
            item = json.loads(event['body'])
            table.put_item(Item=item)
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Item created'})
            }
    except ClientError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
