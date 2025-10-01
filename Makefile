ANSIBLE=ansible-playbook -i ansible/inventory/hosts.ini

bootstrap:
	$(ANSIBLE) ansible/playbooks/bootstrap.yml

site:
	$(ANSIBLE) ansible/playbooks/site.yml

deploy:
	$(ANSIBLE) ansible/playbooks/deploy-app.yml --limit app

backup-db:
	./scripts/backup-db.sh
