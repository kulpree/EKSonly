/*output "address" {
    value = "${aws_elb.web.dns_name}"
  }


  resource "aws_elb" "web" {
    name = "terraform-example-elb"
  
    subnets         = ["${aws_subnet.service_subnet.id}"]
    security_groups = ["${aws_security_group.reinvent_sg.id}"]
  
    listener {
      instance_port     = 80
      instance_protocol = "http"
      lb_port           = 80
      lb_protocol       = "http"
    }
  }
  */
  resource "aws_instance" "consul_client" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_security_group_ids = [aws_security_group.reinvent_sg.id]
    iam_instance_profile   = aws_iam_instance_profile.consul.name
    subnet_id = aws_subnet.service_subnet.id
    associate_public_ip_address = true
    #user_data = data.template_file.consul_client_init.rendered
    tags = local.common_tags
    depends_on = [aws_internet_gateway.igw]
  }
  
  data "aws_ami" "ubuntu" {
    owners = ["self"]
  
    most_recent = true
  
    filter {
      name   = "name"
      values = ["HRS1-*"]
    }
  
    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }



resource "aws_iam_instance_profile" "consul" {
  name = "consul-${random_string.env.result}"
  role = aws_iam_role.consul.name
}

resource "aws_iam_role" "consul" {
  name = "consul-${random_string.env.result}" 

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "consul" {
  name = "consul-${random_string.env.result}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "consul" {
  role       = aws_iam_role.consul.name
  policy_arn = aws_iam_policy.consul.arn
}

output "aws_consul_iam_role_arn" {
  value = aws_iam_role.consul.arn
}

output "aws_consul_iam_instance_profile_name" {
  value = aws_iam_instance_profile.consul.name
}

