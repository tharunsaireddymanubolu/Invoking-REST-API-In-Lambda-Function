# Invoking-REST-API-In-Lambda-Function

Upon Object Creation In S3 Bucket, Lambda will invokes the REST API to Post an object in BynamoDb

Steps:

1. Create S3 Bucket
   *when an json file is uploaded in S3 Bucket Lambda function will trigger
2. Create REST API In Api Gateway
   *API will post the Data uploadted in S3 to DynamoDB table
3. Create DynamoDb
4. Create Lambda Function
   *Create Lambda Function to Invoke API which will post data into the DynamoDb Table
5. Create IAM Roles
   *S3 ReadAccess Role for Lambda Function
   *Dynamodb Full Access Role is Created for REST API
