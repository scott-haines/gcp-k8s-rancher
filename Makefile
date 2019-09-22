.PHONY: apply
apply:
	@terraform plan -out=tfplan && terraform apply tfplan

.PHONY: install-kubeconfig
install-kubeconfig:
	terraform output kube_config | tee ~/.kube/config