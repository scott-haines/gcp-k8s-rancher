.PHONY: apply
apply:
	@terraform plan -out=tfplan && terraform apply tfplan