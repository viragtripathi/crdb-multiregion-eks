# CockroachDB Multi-Region Deployment on EKS

Deploy a secure, highly available CockroachDB cluster across three AWS regions using Amazon EKS, CoreDNS for multi-region DNS, Helm for orchestration, Prometheus/Grafana for observability, and S3 for automated backups. This setup follows best practices for quorum-based distributed systems.

---

### Directory Structure
/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── dns/
│   └── cockroachdb/
│       ├── values.yaml
│       ├── test-client.yaml
│       ├── monitoring/
│       │   ├── prometheus.yaml
│       │   └── grafana.yaml
│       └── backup/
│           └── schedule.yaml
├── regions/
│   ├── us-east-1/
│   │   └── main.tf
│   ├── eu-central-1/
│   │   └── main.tf
│   └── ap-southeast-1/
│       └── main.tf
├── .github/
│   └── workflows/
│       └── deploy.yml
├── Makefile
├── README.md
└── terraform.tfvars

---

### Sample Region Config (regions/eu-central-1/main.tf)
```hcl
module "vpc" {
  source = "../../modules/vpc"
  region = "eu-central-1"
  cidr_block = "10.1.0.0/16"
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  azs = ["eu-central-1a", "eu-central-1b"]
}
```

### terraform.tfvars
```hcl
region = "us-east-1"
```

### CoreDNS ConfigMap (modules/eks/coredns-configmap.yaml)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
  labels:
    eks.amazonaws.com/component: coredns
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
    kubernetes.io/cluster-service: "true"
data:
  Corefile: |
    .:53 {
        errors
        health
        rewrite name suffix us-east-1.cluster.local. dns-lb-us.cluster.local.
        rewrite name suffix eu-central-1.cluster.local. dns-lb-eu.cluster.local.
        rewrite name suffix ap-southeast-1.cluster.local. dns-lb-apac.cluster.local.
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

---
### Makefile

You can use:
- `make init` – initialize all Terraform regions
- `make apply` – deploy all infrastructure
- `make patch-coredns` – update CoreDNS in all clusters
- `make helm-install` – deploy CockroachDB Helm chart
- `make destroy` – destroy infrastructure in reverse order

Replace `<ACCOUNT_ID>` with your AWS account ID in the GitHub Actions workflow.

---

## Additional Helm Setup and Testing

### Helm Chart
We use the latest [CockroachDB Helm chart](https://github.com/cockroachdb/helm-charts/blob/master/cockroachdb-parent/charts/cockroachdb/README.md) with self-signed certificates:

Helm values file: `modules/cockroachdb/values.yaml`

Image version: `cockroachdb/cockroach:v25.1.6`

### Secrets
If using custom TLS instead of self-signed, you must create a Kubernetes secret per region:
```bash
kubectl create secret generic cockroachdb.node --from-file=certs/ -n default
```
Include:
- ca.crt
- node.crt
- node.key
- ui.crt (optional)
- ui.key (optional)

### Test Deployment
A simple test client Pod is included:
```yaml
# modules/cockroachdb/test-client.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-sql-client
spec:
  containers:
  - name: client
    image: cockroachdb/cockroach:v25.1.6
    command: ["sleep"]
    args: ["3600"]
```
Deploy and connect using:
```bash
kubectl apply -f modules/cockroachdb/test-client.yaml
kubectl exec -it test-sql-client -- ./cockroach sql --url="postgresql://root@<CRDB-LB-HOST>:26257/defaultdb?sslmode=disable"
```
(Replace `<CRDB-LB-HOST>` with your region-specific LoadBalancer address.)

You can now validate SQL queries and multi-region connectivity.

---

## DNS and CI/CD Extensions

### Validate DNS Setup
You can verify cross-region DNS resolution by executing inside a pod:
```bash
kubectl exec -it test-sql-client -- nslookup cockroachdb.<other-region>.svc.cluster.local
```
Ensure CoreDNS has correct rewrite and forwarding rules and the DNS record exists in Route53.

### CI/CD Enhancements
Extend `.github/workflows/deploy.yml` with the following steps after Terraform:
```yaml
- name: Deploy CockroachDB via Helm
  run: |
    helm repo add cockroachdb https://charts.cockroachdb.com/
    helm repo update
    helm upgrade --install cockroachdb cockroachdb/cockroachdb -f modules/cockroachdb/values.yaml
```
Optionally, add DNS validation or `kubectl wait` logic to ensure Helm release readiness.

---

## Monitoring Integration

### Prometheus & Grafana
Sample manifests are provided under `modules/cockroachdb/monitoring/`:
- `prometheus.yaml`: basic Prometheus deployment scraping CockroachDB metrics
- `grafana.yaml`: Grafana with CockroachDB dashboards preloaded

Deploy with:
```bash
kubectl apply -f modules/cockroachdb/monitoring/prometheus.yaml
kubectl apply -f modules/cockroachdb/monitoring/grafana.yaml
```

Ensure CockroachDB is configured to expose metrics via `/_status/vars`.

---

## Backup Automation

### CronJob for Backups
Example scheduled backup defined in `modules/cockroachdb/backup/schedule.yaml`:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: crdb-backup
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: cockroachdb/cockroach:v25.1.6
            command: ["/cockroach"]
            args: ["sql", "--execute=BACKUP TO 's3://your-bucket-name/backup?AWS_ACCESS_KEY_ID=xxx&AWS_SECRET_ACCESS_KEY=yyy'"]
          restartPolicy: OnFailure
```

Replace the S3 path and credentials as needed. Ensure IAM roles and Kubernetes secrets for access.
