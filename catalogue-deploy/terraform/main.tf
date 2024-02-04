resource "aws_lb_target_group" "catalogue" {
  name     = "${local.name}-${var.tags.Component}" # roboshop-dev-app-alb
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  deregistration_delay = 60 # Complete pending requests within this time and terminate
  health_check {
    path = "/health"
    port = 8080
    healthy_threshold = 2
    unhealthy_threshold = 3
    timeout = 5
    interval = 10
    matcher = "200-299"  
  }
}

# Listener rule for Catalogue
resource "aws_lb_listener_rule" "catalogue" {
  listener_arn = data.aws_ssm_parameter.app_alb_listener_arn.value
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogue.arn
  }

  condition {
    host_header {
      # catalogue.app-dev.domain.com
      values = ["${var.tags.Component}.app-${var.environment}.${var.zone_name}"]
    }
  }
}

# Create catalogue instance
module "catalogue" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${local.name}-${var.tags.Component}-ami" # roboshop-dev-app-alb-ami
  ami = data.aws_ami.centos8.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.catalogue_sg_id.value]
  subnet_id              = element(split(",",data.aws_ssm_parameter.private_subnet_ids.value),0)
  iam_instance_profile = "ansible-tf-shell"

  tags = merge(
    var.common_tags,
    var.tags
  )
}

# Provision using Shell and Ansible roles
resource "null_resource" "catalogue" {
  triggers = {
    instance_id = module.catalogue.id
  }

  # Bootstrap script will be run on the Catalogue instance
  connection {
    host = module.catalogue.private_ip
    type     = "ssh"
    user     = "centos"
    password = "DevOps321"
  }

  provisioner "file" {
  source      = "bootstrap.sh"
  destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the inventory
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh catalogue dev ${var.app_version}"
    ]
  }
}

# Stop Catalogue instance
resource "aws_ec2_instance_state" "catalogue" {
  instance_id = module.catalogue.id
  state       = "stopped"
  depends_on = [ null_resource.catalogue ]
}

# Create AMI of Catalogue from instance
resource "aws_ami_from_instance" "catalogue" {
  name               = "${local.name}-${var.tags.Component}-${local.current_time}"
  source_instance_id = module.catalogue.id
  depends_on = [ aws_ec2_instance_state.catalogue ]
}

# Terminate Catalogue instance
resource "null_resource" "catalogue_delete" {
  triggers = {
    instance_id = module.catalogue.id
  }
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.catalogue.id}"
  }
  depends_on = [ aws_ami_from_instance.catalogue ]
}

# Create Launch Template for Catalogue
resource "aws_launch_template" "catalogue" {
  name = "${local.name}-${var.tags.Component}"
  image_id = aws_ami_from_instance.catalogue.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  update_default_version = true
  vpc_security_group_ids = [data.aws_ssm_parameter.catalogue_sg_id.value]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.name}-${var.tags.Component}"
    }
  }
}

# Create auto-scaling group
resource "aws_autoscaling_group" "catalogue" {
  name                      = "${local.name}-${var.tags.Component}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2
  vpc_zone_identifier       = split(",",data.aws_ssm_parameter.private_subnet_ids.value)
  target_group_arns = [aws_lb_target_group.catalogue.arn]

  launch_template {
    id      = aws_launch_template.catalogue.id
    version = aws_launch_template.catalogue.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"] # Any changes at instance level triggers new ami creation
  }
  
  tag {
    key                 = "Name"
    value               = "${local.name}-${var.tags.Component}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}



# Create auto-scaling policy
resource "aws_autoscaling_policy" "catalogue" {
  autoscaling_group_name = aws_autoscaling_group.catalogue.name
  name                   = "${local.name}-${var.tags.Component}"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 5.0 # The value is for testing puropose
  }
}
