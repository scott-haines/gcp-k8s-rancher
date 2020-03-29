.PHONY: service-account remove-service-account preflight-check

service-account:
	@gcloud iam service-accounts create gcp-k8s-rancher \
    	--display-name "GCP-K8S-RANCHER"
	@gcloud iam service-accounts keys create secrets/gcp-k8s-rancher-key.json \
  		--iam-account gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.networkAdmin
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.instanceAdmin.v1
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.securityAdmin
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.serviceAccountAdmin
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.serviceAccountKeyAdmin
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.securityAdmin
	@gcloud projects add-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/container.admin

remove-service-account:
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/container.admin
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.securityAdmin
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.serviceAccountKeyAdmin
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/iam.serviceAccountAdmin
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.securityAdmin
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
  		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.instanceAdmin.v1
	@gcloud projects remove-iam-policy-binding $${TF_VAR_PROJECT_ID} \
		--member serviceAccount:gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com \
  		--role roles/compute.networkAdmin
	@gcloud --quiet iam service-accounts delete gcp-k8s-rancher@$${TF_VAR_PROJECT_ID}.iam.gserviceaccount.com
	@rm secrets/gcp-k8s-rancher-key.json

preflight-check:
	@echo checking versions of key tools ---------------
	@./makefile-helpers/preflight-semver-check.sh 251.0.0 $(shell gcloud version --format="value('Google Cloud SDK')") gcloud
	@./makefile-helpers/preflight-semver-check.sh 0.12.18 $(shell terraform version | grep Terraform | awk -F "v" '{print $$NF}') terraform
	
	@echo checking for exported variables --------------
	@./makefile-helpers/preflight-exports-check.sh TF_VAR_PROJECT_ID

	@echo checking gcloud service apis -----------------
	@./makefile-helpers/preflight-service-check.sh cloudresourcemanager.googleapis.com
	@./makefile-helpers/preflight-service-check.sh compute.googleapis.com
	@./makefile-helpers/preflight-service-check.sh container.googleapis.com
	@./makefile-helpers/preflight-service-check.sh iam.googleapis.com