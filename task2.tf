
provider "aws" {
    region = "ap-south-1"    
}
resource "aws_vpc" "shyamvpc"{
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"
    tags = {
        Name = "shyamvpc"
    }
}

resource "aws_subnet" "firstsubnet" {
    vpc_id = "${aws_vpc.shyamvpc.id}"
    cidr_block = "192.168.0.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "ap-south-1a"
    tags = {
        Name = "firstsubnet"
    }
}

resource "aws_security_group" "shyamsg" {

                name        = "shyamsg"
                vpc_id      = "${aws_vpc.shyamvpc.id}"

                ingress {
                  from_port   = 80
                  to_port     = 80
                  protocol    = "tcp"
                  cidr_blocks = [ "0.0.0.0/0"]
                }
                ingress {
                  from_port   = 2049
                  to_port     = 2049
                  protocol    = "tcp"
                  cidr_blocks = [ "0.0.0.0/0"]
                }
                ingress {
                  from_port   = 22
                  to_port     = 22
                  protocol    = "tcp"
                  cidr_blocks = [ "0.0.0.0/0"]
                }
                egress {
                  from_port   = 0
                  to_port     = 0
                  protocol    = "-1"
                  cidr_blocks = ["0.0.0.0/0"]
                }
                tags = {
                  Name = "shyamsg"
                }
}

resource "aws_efs_file_system" "shyamefs" {
                
            creation_token = "shyamefs"
                tags = {
                  Name = "shyamefs"
                }
}


resource "aws_efs_mount_target" "shyamefsmount" {
            file_system_id = "${aws_efs_file_system.shyamefs.id}"
            subnet_id = "${aws_subnet.firstsubnet.id}"
            security_groups = [aws_security_group.shyamsg.id]
}



resource "aws_internet_gateway" "getwy"{
    vpc_id = "${aws_vpc.shyamvpc.id}"
    tags = {
        Name = "getwy1"  
    }
}

resource "aws_route_table" "shyamrttb" {
    vpc_id = "${aws_vpc.shyamvpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.getwy.id}"
    }
    tags = {
        Name = "shyamrttb"
    }
}

resource "aws_route_table_association" "artas" {
    subnet_id = "${aws_subnet.firstsubnet.id}"
    route_table_id = "${aws_route_table.shyamrttb.id}"
}

resource "aws_instance" "shyaminstance" {
        ami             =  "ami-052c08d70def0ac62"
        instance_type   =  "t2.micro"
        key_name        =  "EFS_task"
        subnet_id     = "${aws_subnet.firstsubnet.id}"
        security_groups = ["${aws_security_group.shyamsg.id}"]

    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("C:/Users/DELL/Downloads/EFS_task.pem")
        host     = aws_instance.shyaminstance.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo yum install amazon-efs-utils -y",
            "sudo yum install httpd  php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
            "sudo setenforce 0",
            "sudo yum -y install nfs-utils"
        ]
    }

    tags = {
        Name = "shyaminstance"
    }
}

resource "null_resource" "mount"  {
    depends_on = [aws_efs_mount_target.shyamefsmount]
        connection {
            type     = "ssh"
            user     = "ec2-user"
            private_key = file("C:/Users/DELL/Downloads/EFS_task.pem")
            host     = aws_instance.shyaminstance.public_ip
        }
        provisioner "remote-exec" {
            inline = [
                "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.shyamefs.id}.efs.ap-south-1.amazonaws.com:/ /var/www/html",
                "sudo rm -rf /var/www/html/*",
                "sudo git  clone  https://github.com/shyamwin/CloudTaskwithEFS.git  /var/www/html/",
                "sudo sed -i 's/url/${aws_cloudfront_distribution.myfront.domain_name}/g' /var/www/html/index.html"
            ]
        }
}

resource "null_resource" "git_copy"  {
      provisioner "local-exec" {
        command = "git clone https://github.com/shyamwin/CloudTaskwithEFS.git  C:/Users/DELL/Desktop/Test1" 
        }
    }
resource "null_resource" "writing_ip"  {
        provisioner "local-exec" {
            command = "echo  ${aws_instance.shyaminstance.public_ip} > public_ip.txt"
          }
      }

resource "aws_s3_bucket" "shyams3bucket" {
        bucket = "shyamstorage"
        acl    = "private"

        tags = {
          Name        = "shyamstorage"
        }
}
locals {
    s3_origin_id = "S3storage"
}

resource "aws_s3_bucket_object" "object" {
    bucket = "${aws_s3_bucket.shyams3bucket.id}"
    key    = "EFS_task"
    source = "C:/Users/DELL/Desktop/TASK2_CLOUD/sir.jpeg"
    acl    = "public-read"
}

resource "aws_cloudfront_distribution" "myfront" {
    origin {
        domain_name = "${aws_s3_bucket.shyams3bucket.bucket_regional_domain_name}"
        origin_id   = "${local.s3_origin_id}"

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
    enabled = true
    default_cache_behavior {

               allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
               cached_methods   = ["GET", "HEAD"]
               target_origin_id = "${local.s3_origin_id}"

       forwarded_values {

             query_string = false

       cookies {
                forward = "none"
               }
          }

                viewer_protocol_policy = "allow-all"
                min_ttl                = 0
                default_ttl            = 3600
                max_ttl                = 86400

      }
        restrictions {
               geo_restriction {
                 restriction_type = "none"
                }
           }
       viewer_certificate {
             cloudfront_default_certificate = true
             }
      }

resource "null_resource" "local-exec"  {
        depends_on = [
            null_resource.mount,
        ]
        provisioner "local-exec" {
            command = "start chrome  ${aws_instance.shyaminstance.public_ip}"
        }
}
