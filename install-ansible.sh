#!/bin/sh
sudo yum update -y            && \
sudo yum install -y ansible   && \

sudo systemctl start ansible  && \
sudo systemctl enable ansible
