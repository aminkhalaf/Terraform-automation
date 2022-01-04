# This command (sudo usermod -aG docker ec2-user) will add docker to group and run it without sudo command

#!/bin/bash
sudo yum update -y %% sudo yum install -y docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user
docker run -p 8080:80 nginx
