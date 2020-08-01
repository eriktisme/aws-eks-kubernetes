.PHONY: tf-init
tf-init:
	docker-compose run --rm terraform init

.PHONY: tf-fmt
tf-fmt:
	docker-compose run --rm terraform fmt -recursive

.PHONY: tf-validate
tf-validate:
	docker-compose run --rm terraform validate

.PHONY: tf-plan
tf-plan:
	docker-compose run --rm terraform plan

.PHONY: tf-apply
tf-apply:
	docker-compose run --rm terraform apply


.PHONY: tf-apply-approve
tf-apply-approve:
	docker-compose run --rm terraform apply -auto-approve

.PHONY: tf-destroy
tf-destroy:
	docker-compose run --rm terraform destroy

.PHONY: tf-workspace-staging
tf-workspace-staging:
	docker-compose run --rm terraform workspace select staging || docker-compose run --rm terraform workspace new staging

.PHONY: tf-workspace-default
tf-workspace-default:
	docker-compose run --rm terraform workspace select default

.PHONY: kubectl-get--namespaces
kubectl-get-namespaces:
	docker-compose run --rm kubectl get all --all-namespaces

.PHONY: kubectl-get-all-nodes
kubectl-get-nodes:
	docker-compose run --rm kubectl get nodes
