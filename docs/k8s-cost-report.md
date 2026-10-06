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

---

## Stage 2 — Right-Sizing

**Status: Complete**

### Objective

Reduce unnecessary CPU and memory resource reservations based on the measured behavior of the controlled workload while maintaining application reliability.

### Measured Workload

Additional controlled measurements were collected before applying the new resource configuration.

The four application pods showed approximately:

- CPU: 12–22m per pod across repeated samples
- Combined CPU: approximately 65–81m
- Memory: approximately 3Mi per pod
- Combined memory: approximately 12Mi

These measurements were used to determine a smaller resource allocation with safety headroom for the controlled NGINX benchmark.

### Right-Sized Resource Configuration

The application resource configuration was changed from:

| Resource | Baseline | Right-Sized |
|---|---:|---:|
| CPU Request | 250m | 50m |
| Memory Request | 256Mi | 32Mi |
| CPU Limit | 500m | 200m |
| Memory Limit | 512Mi | 64Mi |

For 4 replicas, the total requested resources changed from:

| Resource | Baseline | Right-Sized |
|---|---:|---:|
| CPU Request | 1000m | 200m |
| Memory Request | 1024Mi | 128Mi |

This represents an 80% reduction in both CPU and memory resource requests for the application workload.

> Important: The 80% reduction applies to Kubernetes resource requests for the application pods. It does not represent an 80% reduction in AWS infrastructure cost because the cluster continued to run two worker nodes during this stage.

### Deployment

The right-sized workload was applied using the updated Kubernetes deployment manifest.

The deployment continued running four application replicas.

The rollout completed successfully without deployment availability issues.

### Sustained-Load Validation

The right-sized workload was validated using the controlled load-generator workload.

Observed results included:

- Application replicas: 4/4 available
- Application pod status: Running
- Application pod restarts: 0
- OOMKills observed: 0
- Combined application CPU usage: approximately 65–81m during sampled load
- Combined application memory usage: approximately 12Mi
- Worker nodes remained available and schedulable

The validation indicates that the reduced resource requests and limits were sufficient for the controlled NGINX benchmark.

### Reliability Result

The right-sizing change did not introduce observed workload instability during the controlled test.

The workload maintained:

- 4/4 application replicas
- 0 pod restarts
- No observed OOMKills
- Successful deployment rollout
- Stable node availability

### Bin-Packing Experiment

After right-sizing, the application resource requests were sufficiently reduced to investigate whether the four application replicas could be concentrated onto a single worker node.

The two worker nodes had approximately:

- Allocatable CPU: 1930m per node
- Allocatable memory: approximately 1468Mi per node

The application itself requested only:

- CPU: 200m total
- Memory: 128Mi total

A controlled scheduling test was performed by temporarily constraining the application workload to one worker node.

### Bin-Packing Result

The single-node placement test was **not feasible under the current EKS configuration**.

When the deployment was constrained to one worker node:

- Existing replicas remained on their original nodes during the rolling update.
- Two replacement replicas became Pending.
- The constrained node could not accommodate the complete replacement workload together with the existing Kubernetes system workloads and scheduling requirements.
- The deployment exceeded its progress deadline.

The scheduling constraint was subsequently removed and the deployment was successfully restored to its normal configuration.

### Bin-Packing Conclusion

The test demonstrates that right-sizing improved the application's resource-request efficiency, but the current two-node EKS configuration cannot safely be reduced to one worker node based on this experiment alone.

Therefore, the project does **not** claim a node-count reduction during Stage 2.

Instead, the result establishes an infrastructure constraint that will be addressed through dynamic node autoscaling in the later optimization stage.

### Right-Sizing Risks

The selected values are based on the controlled NGINX benchmark and should not automatically be applied to an unrelated production workload.

Potential risks include:

- Higher-than-observed production traffic
- CPU bursts above the measured workload
- Memory growth over time
- Increased concurrency
- Different application behavior
- OOMKills if memory limits are too low
- CPU throttling if CPU limits are too restrictive

For production workloads, resource recommendations should be based on representative historical usage and monitored over an appropriate period.

### Stage 2 Conclusion

Stage 2 successfully reduced unnecessary Kubernetes resource reservations while maintaining workload reliability during the controlled benchmark.

The application resource requests were reduced by 80% for both CPU and memory without observed OOMKills or pod restarts.

The bin-packing experiment demonstrated that the application could not safely be consolidated onto one worker node under the current EKS system-workload and capacity constraints.

The optimized resource configuration establishes the foundation for the next stage: workload and node autoscaling.

---

## Stage 3 — Autoscaling

**Status: Planned**

Stage 3 will introduce workload and infrastructure autoscaling.

Planned components:

- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA) evaluation
- Karpenter for dynamic node provisioning and scale-down

The stage will demonstrate application scale-out and scale-in based on demand and evaluate whether worker-node capacity can dynamically adjust to workload requirements.

---

## Stage 4 — Spot Capacity

**Status: Planned**

Suitable workloads will be evaluated for Amazon EC2 Spot capacity.

Critical workloads will retain appropriate On-Demand capacity.

The implementation will evaluate:

- Spot node provisioning
- Workload scheduling
- Interruption handling
- Node drain behavior
- Pod rescheduling
- Reliability during interruption
- Cost savings compared with On-Demand capacity

---

## Stage 5 — Cost and Reliability Measurement

**Status: Planned**

The final stage will compare the baseline and optimized environments.

The final report will include:

- Node count
- CPU requests
- Memory requests
- CPU utilization
- Memory utilization
- Application replicas
- Infrastructure cost
- Estimated savings
- Pod availability
- Pod restarts
- OOMKills
- Cost visibility by namespace/workload
- Cost/regression monitoring

Exact AWS billing data will be captured under controlled benchmark conditions rather than estimated from assumptions.

---

## Final Reliability Principle

Cost optimization will only be considered successful when resource efficiency improves without introducing unacceptable workload instability.

All optimization stages will therefore consider:

- Resource utilization
- Scheduling efficiency
- Pod availability
- Pod restarts
- OOMKills
- Application behavior
- Node availability
- Autoscaling behavior