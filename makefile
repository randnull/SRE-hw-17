create_test:
	ansible-playbook --vault-id test@prompt -i inventory/testing.yml nginx_install.yml 
create_prod:
	ansible-playbook --vault-id prod@prompt -i inventory/production.yml nginx_install.yml 