.PHONY: env-plan env-up env-down clean-env-files clean-terraform-files

env-plan:
	terraform init
	terraform fmt
	terraform plan

env-up:	
	terraform apply --auto-approve
	terraform output -raw ec2_user_private_key > ec2-user-private-key.pem
	terraform output -raw ansible_private_key > ansible-private-key.pem
	chmod 400 ec2-user-private-key.pem
	chmod 400 ansible-private-key.pem
	printf "#!/bin/sh\n\n" > ssh-to-ansible.sh
	printf "ssh -i ec2-user-private-key.pem ec2-user@" >> ssh-to-ansible.sh
	terraform output -raw ansible_public_ip >> ssh-to-ansible.sh
	chmod 750 ssh-to-ansible.sh
	printf "[defaults]\ninventory = inventory\n" > ansible.cfg
	printf "private_key_file = /home/ec2-user/ansible-private-key.pem" >> ansible.cfg
	printf "[nodes]\n" > inventory
	terraform output -raw wordpress_public_ip >> inventory
	printf "#!/bin/sh\n\n" > scp-ansible-config.sh
	printf "scp -q -o StrictHostKeyChecking=no -i ec2-user-private-key.pem ansible.cfg ec2-user@" >> scp-ansible-config.sh
	terraform output -raw ansible_public_ip >> scp-ansible-config.sh
	printf ":/home/ec2-user/\n" >> scp-ansible-config.sh
	printf "scp -q -o StrictHostKeyChecking=no -i ec2-user-private-key.pem ansible-private-key.pem ec2-user@" >> scp-ansible-config.sh
	terraform output -raw ansible_public_ip >> scp-ansible-config.sh
	printf ":/home/ec2-user/\n" >> scp-ansible-config.sh
	printf "scp -q -o StrictHostKeyChecking=no -i ec2-user-private-key.pem wp-config.php.j2 ec2-user@" >> scp-ansible-config.sh
	terraform output -raw ansible_public_ip >> scp-ansible-config.sh
	printf ":/home/ec2-user/\n" >> scp-ansible-config.sh
	chmod 750 scp-ansible-config.sh
	./scp-ansible-config.sh

clean-env-files:
	rm -rf ec2-user-private-key.pem ansible-private-key.pem ansible.cfg inventory ssh.sh scp-ansible-config.sh

env-down:
	terraform destroy --auto-approve
	make clean-env-files

clean-terraform-files:
	rm -rf .terraform.lock.hcl
