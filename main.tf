provider "aws" {
  region = "us-east-1" # ou outra região de sua preferência
}

resource "aws_dynamodb_table" "my_table" {
  name           = "MyDynamoDBTable"  # Nome da tabela no DynamoDB
  billing_mode   = "PAY_PER_REQUEST"  # Modo de pagamento; paga por cada requisição, útil para camadas gratuitas
  hash_key       = "id"               # Chave primária da tabela (campo obrigatório)

  attribute {
    name = "id"                       # Nome do atributo da chave primária
    type = "S"                        # Tipo do atributo; "S" significa "String"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_dynamodb_role"  # Nome da role IAM
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",       # Permissão para a Lambda "assumir" essa role
        "Principal": {
          "Service": "lambda.amazonaws.com" # Define que a role é assumida pelo serviço Lambda
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name            # Nome da role que receberá a política
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" # Política pré-definida que concede acesso total ao DynamoDB
}

resource "aws_lambda_function" "my_lambda" {
  filename         = "${path.module}/lambda_function.zip"  # Caminho do arquivo ZIP com o código da função Lambda
  function_name    = "MyLambdaFunction"                    # Nome da função Lambda
  role             = aws_iam_role.lambda_role.arn          # ARN da role IAM que a função Lambda usará
  handler          = "main.lambda_handler"                 # Handler que aponta para a função principal no código Python
  runtime          = "python3.9"                           # Runtime para executar o código Python
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip") # Hash do arquivo para detectar alterações

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.my_table.name  # Variável de ambiente que armazena o nome da tabela DynamoDB
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_dynamodb_policy] # Define dependência da role com política anexada
}

resource "aws_apigatewayv2_api" "my_api" {
  name          = "MyAPIGateway"   # Nome da API
  protocol_type = "HTTP"           # Tipo de protocolo (HTTP para API RESTful)
}
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.my_api.id       # ID da API Gateway
  integration_type   = "AWS_PROXY"                          # Tipo de integração AWS_PROXY para Lambda
  integration_uri    = aws_lambda_function.my_lambda.invoke_arn # URI para invocar a função Lambda
  payload_format_version = "2.0"                            # Versão do formato do payload
}
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.my_api.id   # ID da API Gateway
  route_key = "ANY /{proxy+}"                  # Define qualquer método HTTP para a rota com proxy
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}" # Aponta para a integração com o Lambda
}
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"                     # Identificador da política
  action        = "lambda:InvokeFunction"                     # Permissão para invocar a função Lambda
  function_name = aws_lambda_function.my_lambda.function_name # Nome da função Lambda
  principal     = "apigateway.amazonaws.com"                  # Permite que o API Gateway execute a função
  source_arn    = "${aws_apigatewayv2_api.my_api.execution_arn}/*/*" # ARN da API Gateway
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.my_api.id   # ID da API Gateway
  name        = "$default"                       # Nome do stage
  auto_deploy = true                            
}

