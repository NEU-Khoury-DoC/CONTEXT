provider "aws" {
  region  = "us-east-1"
  profile = "font-test-superadmin"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_services" {
  name        = "ecs-services"
  description = "Allow public access to Flask API and internal MySQL access"
  vpc_id      = data.aws_vpc.default.id

  # Allow inbound HTTP to the API container
  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow internal communication between containers in the same SG
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_services.id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "monorepo-app-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "app_task" {
  family                   = "monorepo-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "mysql-db"
      image     = "637423203881.dkr.ecr.us-east-1.amazonaws.com/mysql-db:latest"
      essential = true
      environment = [
        { name = "MYSQL_ROOT_PASSWORD", value = "Th1sIs4terr1bleP4ssw0rd!" }
      ]
      portMappings = [
        {
          containerPort = 3306
          protocol      = "tcp"
        }
      ]
    },
    {
      name      = "web-api"
      image     = "637423203881.dkr.ecr.us-east-1.amazonaws.com/flask-api:latest"
      essential = true
      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST", value = "127.0.0.1" },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_USER", value = "root" },
        { name = "DB_PASSWORD", value = "Th1sIs4terr1bleP4ssw0rd!" },
        { name = "DB_NAME", value = "context" }
      ]
    }
  ])
}

resource "aws_ecs_service" "app_service" {
  name            = "monorepo-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_services.id]
    assign_public_ip = true
  }
}

output "api_url_hint" {
  value = "Your Flask API should be accessible on port 4000 of the ECS public IP"
}
