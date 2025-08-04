data "aws_ssm_parameter" "ec2_key" {
  name            = "/expense/ec2/siva"
  with_decryption = true
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "example" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3a.medium"
  key_name               = "siva"
  vpc_security_group_ids = ["sg-0247c6b65a012e5f2"]
  subnet_id              = "subnet-0f91105ac5e421ff1"
  iam_instance_profile = "test-prometheus"
  tags                   = { Name = "testing" }

}

resource "null_resource" "user_data_exec" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = data.aws_ssm_parameter.ec2_key.value
    host        = aws_instance.example.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install ansible git -y",
      "sudo rm -rf /opt/ansible-roles",
      "sudo git clone https://github.com/konka-devops-lab/ansible-roles.git /opt/ansible-roles",
      "cd /opt/ansible-roles",
      "ansible-playbook -i 127.0.0.1, playbooks/prometheus.yml -c local"
    ]
  }

  depends_on = [aws_instance.example]
  triggers = {
    always_run = timestamp()
  }
}

output "public_ip" {
  value = aws_instance.example.public_ip
}