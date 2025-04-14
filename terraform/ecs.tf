resource "aws_ecs_cluster" "flask_xray_cluster" {
  name = "${local.prefix}-flask-xray-cluster" # replace "your-name" with your identifier
}

resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "/ecs/${local.prefix}-flask-xray-taskdef"
  retention_in_days = 7 # or whatever retention you want
}

resource "aws_ecs_task_definition" "flask_xray_taskdef" {
  family                   = "${local.prefix}-flask-xray-taskdef"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_xray_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_xray_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.prefix}-flask-app"
      image     = "255945442255.dkr.ecr.us-east-1.amazonaws.com/norman-flask-xray-repo:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "${local.prefix}-flask-xray-service"
        }
      ]
      secrets = [
        {
          name      = "MY_APP_CONFIG"
          valueFrom = "arn:aws:ssm:us-east-1:255945442255:parameter/norman-ce9/config"
        },
        {
          name      = "MY_DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:us-east-1:255945442255:secret:norman-ce9/db_password-zdcqbk"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.prefix}-flask-xray-taskdef"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "flask"
        }
      }
    },
    {
      name      = "xray-sidecar"
      image     = "amazon/aws-xray-daemon"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_task_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "xray"
        }
      }
    }
  ])
}

resource "aws_security_group" "flask_sg" {
  name        = "${local.prefix}-flask-sg"
  description = "Allow inbound traffic to Flask app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "flask_service" {
  name            = "${local.prefix}-flask-service"
  cluster         = aws_ecs_cluster.flask_xray_cluster.id
  task_definition = aws_ecs_task_definition.flask_xray_taskdef.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.flask_sg.id]
  }

  deployment_controller {
    type = "ECS"
  }

  scheduling_strategy = "REPLICA"

  depends_on = [aws_iam_role.ecs_xray_task_execution_role]
}
