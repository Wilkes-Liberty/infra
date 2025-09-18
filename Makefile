ANSIBLE=ansible-playbook -i ansible/inventory/hosts.ini

bootstrap:
\t$(ANSIBLE) ansible/playbooks/bootstrap.yml

site:
\t$(ANSIBLE) ansible/playbooks/site.yml

deploy:
\t$(ANSIBLE) ansible/playbooks/deploy-app.yml --limit app

backup-db:
\t./scripts/backup-db.sh
