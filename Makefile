
REGIONS := us-east-1 eu-central-1 ap-southeast-1

.PHONY: init apply destroy patch-coredns helm-install

init:
	@for region in $(REGIONS); do \
		cd regions/$$region && terraform init && cd -; \
	done

apply:
	@for region in $(REGIONS); do \
		cd regions/$$region && terraform apply -auto-approve && cd -; \
	done

patch-coredns:
	@for region in $(REGIONS); do \
		kubectl config use-context $$region && \
		kubectl apply -f modules/eks/coredns-configmap.yaml && \
		kubectl rollout restart deployment coredns -n kube-system; \
	done

helm-install:
	helm repo add cockroachdb https://charts.cockroachdb.com/
	helm repo update
	helm upgrade --install cockroachdb cockroachdb/cockroachdb -f modules/cockroachdb/values.yaml

destroy:
	@for region in $(shell echo $(REGIONS) | awk '{for(i=NF;i>0;i--)printf $$i" "}'); do \
		cd regions/$$region && terraform destroy -auto-approve && cd -; \
	done
