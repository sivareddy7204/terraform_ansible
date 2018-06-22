variable INSTANCE_PASSWORD {}
variable INSTANCE_USERNAME {}
# Default security group to access the instances via WinRM over HTTP and HTTPS
resource "aws_security_group" "ec21" {
  name        = "terraform_ansible20"
  description = "Used in the terraform"

  # WinRM access from anywhere
  ingress {
    from_port   = 3365
    to_port     = 6000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



provider "aws" {
  region     = "us-east-1"
}



resource "aws_instance" "ec2" {
  ami = "ami-f0df538f"
  instance_type = "t2.micro"
  key_name = "demo"
  security_groups= ["terraform_ansible20"]
  user_data = <<EOF
<powershell>
net user ${var.INSTANCE_USERNAME} '${var.INSTANCE_PASSWORD}' /add /y
net localgroup administrators ${var.INSTANCE_USERNAME} /add
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow
net stop winrm
sc.exe config winrm start=auto
net start winrm
</powershell>
EOF





  provisioner "file" {
    source = "ansible.ps1"
    destination = "C:/ansible.ps1"
  
}

provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:/ansible.ps1 "
    ]
  }

  connection {
    type = "winrm"
    timeout = "10m"
    user = "${var.INSTANCE_USERNAME}"
    password = "${var.INSTANCE_PASSWORD}"
  }


}







data "template_file" "inventory" {
    template = "${file("inventory.tpl")}"

    vars {
        backend_ip = "${aws_instance.ec2.public_ip}"
    }
}

resource "null_resource" "update_inventory" {

    triggers {
        template = "${data.template_file.inventory.rendered}"
    }

    provisioner "local-exec" {
        command = "echo '${data.template_file.inventory.rendered}' > hosts"
    }
}	



output "ip"{

value="${aws_instance.ec2.public_ip}"

}


output "id"{

value="${aws_instance.ec2.id}"

}


