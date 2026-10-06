# Kubernetes Cost Optimization Report

## Stage 1 — Baseline Waste Analysis

### Environment

- Platform: Amazon EKS
- Region: ap-south-1
- Kubernetes Version: 1.36
- Worker Nodes: 2 × t3.small On-Demand
- Node Scaling: Fixed at 2 nodes
- Application Namespace: cost-baseline
- Application: cost-baseline-app
- Replicas: 4
- Container Image: nginx:1.27-alpine
- HPA: Not configured
- VPA: Not configured
- Cluster Autoscaler: Not configured
- Karpenter: Not configured
- Spot Instances: Not configured

### Baseline Resource Configuration

Each application pod requested:

- CPU: 250m
- Memory: 256Mi

Each application pod had limits:

- CPU: 500m
- Memory: 512Mi

For 4 replicas, total application requests were:

- CPU: 1000m
- Memory: 1024Mi

### Observed Application Usage

During the controlled load test, application pods showed approximately:

- CPU: 14–22m per pod
- Memory: 3Mi per pod

Combined application usage was approximately:

- CPU: 69–79m
- Memory: 12Mi

Compared with the configured requests, this represented approximately:

- CPU request utilization: 7–8%
- Memory request utilization: ~1.2%

Therefore, the workload was significantly over-requested under this controlled benchmark.

> Note: `kubectl top` provides sampled/rounded metrics. These measurements should not be interpreted as exact zero usage or as production-safe right-sizing values. Additional representative measurements are required before applying final requests/limits.

### Node Utilization During Load Test

During the controlled load test:

- Node 1: approximately 39% CPU / 55% memory
- Node 2: approximately 11% CPU / 54% memory

The results show that CPU had substantial spare capacity, while memory utilization was comparatively higher because of Kubernetes system components and workload placement.

### Scaling Baseline

The deployment remained fixed at 4 replicas.

No Horizontal Pod Autoscaler or node autoscaling mechanism was configured.

Therefore:

- Replicas did not automatically scale with demand.
- Worker capacity remained fixed at 2 nodes.
- Off-peak capacity could not automatically scale down.
- Peak demand could not automatically increase application replicas or worker capacity.

### Reliability Baseline

At the end of the baseline test:

- Application replicas available: 4/4
- Application pod restarts: 0
- Application pod status: Running
- Kubernetes system components: Healthy

The baseline therefore provides a stable reliability reference for subsequent optimization stages.

### Cost Optimization Findings

The baseline demonstrates significant potential resource-request waste, particularly CPU.

The application requested 1000m CPU while the controlled workload consumed approximately 69–79m CPU.

This excessive reservation can reduce Kubernetes bin-packing efficiency because the scheduler places pods according to their resource requests rather than their instantaneous CPU consumption.

The next optimization stage will use measured workload behavior to reduce requests/limits while maintaining reliability and avoiding OOMKills or performance degradation.

### Baseline Infrastructure Condition

The benchmark started with:

- 2 × t3.small On-Demand worker nodes
- Fixed desired/min/max node count of 2
- 4 application replicas
- No pod autoscaling
- No node autoscaling
- No Spot capacity

Exact AWS billing cost will be captured separately using the AWS billing/cost data under controlled benchmark conditions rather than estimated from assumptions.

## Stage 2 — Right-Sizing

Status: Pending