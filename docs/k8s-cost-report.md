# Kubernetes Cost Optimization Report

---

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

The optimized resource configuration establishes the foundation for workload and node autoscaling.

---

## Stage 3 — Pod and Node Autoscaling

**Status: Complete**

### Objective

Introduce automatic workload and node scaling so that application capacity increases during demand and unnecessary worker capacity is removed during low-demand periods.

Stage 3 implemented:

- Horizontal Pod Autoscaler (HPA)
- VPA evaluation/recommendation approach
- Cluster Autoscaler for worker-node scaling

### HPA Configuration

The application was configured with an HPA using the Kubernetes `autoscaling/v2` API.

Configuration:

| Setting | Value |
|---|---:|
| Target Deployment | cost-baseline-app |
| Minimum replicas | 2 |
| Maximum replicas | 6 |
| CPU target | 60% |
| Scale-up stabilization | 0 seconds |
| Scale-down stabilization | 60 seconds |

The HPA was configured to scale the application based on CPU utilization relative to the right-sized CPU requests.

### HPA Scale-Out Evidence

A controlled load test was used to increase application CPU demand.

The HPA successfully increased application capacity:

**3 replicas → 5 replicas**

Observed HPA output included:

```text
NAME                REFERENCE                      TARGETS        MINPODS   MAXPODS   REPLICAS
cost-baseline-hpa   Deployment/cost-baseline-app   cpu: 52%/60%   2         6         5
The workload therefore demonstrated automatic pod scale-out when demand increased.
HPA Scale-In Evidence
During the lower-demand phase, the HPA reduced application replicas.
An earlier controlled observation showed:
cpu: 54%/60%   REPLICAS: 3

The workload therefore demonstrated both HPA scale-out and scale-in behavior rather than remaining permanently at peak replica capacity.
VPA Evaluation
Vertical Pod Autoscaler was evaluated as part of the autoscaling design.
The EKS cluster did not have the VPA CustomResourceDefinition installed, so VPA was not enabled as an automatic controller.
For this project, VPA is treated as a recommendation-based future optimization mechanism rather than an automatic scaling mechanism.
Recommended operating model:
- Use VPA in recommendation/Off mode to analyze historical resource usage.
- Review recommendations before applying new requests and limits.
- Avoid automatically changing requests while HPA is simultaneously using CPU utilization based on those requests.
- Apply validated recommendations through controlled deployment changes.
This approach avoids introducing competing automatic resource adjustments between HPA and VPA.
Cluster Autoscaler
Cluster Autoscaler was selected instead of Karpenter for the node-autoscaling implementation.
The EKS managed node group was configured with:
- Node group: baseline-workers
- Initial desired nodes: 2
- Minimum nodes: 2
- Maximum nodes: 4
- Instance type: t3.small
- Capacity type: On-Demand
Cluster Autoscaler was installed using Helm with AWS autodiscovery for the eks-cost-optimization cluster.
An IAM OIDC provider and dedicated IAM service account were configured to allow Cluster Autoscaler to interact with the AWS Auto Scaling API.
Cluster Autoscaler Scale-Out Evidence
Under increased workload and scheduling pressure, the worker-node count increased automatically.
Observed node state changed from:
2 nodes → 3 nodes
The third EKS worker node successfully joined the cluster and reached Ready status.
Example observed state:
NAME                                            STATUS
ip-192-168-28-222.ap-south-1.compute.internal   Ready
ip-192-168-53-200.ap-south-1.compute.internal   Ready
<new worker node>                               Ready

This demonstrates that Cluster Autoscaler successfully provisioned additional worker capacity when the existing capacity was insufficient.
Cluster Autoscaler Scale-In Evidence
After the controlled load was removed and the application workload was returned to the lower-demand state, the additional worker capacity was no longer required.
The cluster automatically returned to:
3 nodes → 2 nodes
Observed final node state:
NAME                                            STATUS
ip-192-168-28-222.ap-south-1.compute.internal   Ready
ip-192-168-53-200.ap-south-1.compute.internal   Ready

This demonstrates automatic node scale-down during reduced demand.
Autoscaling Behavior Summary
Optimization	Scale-Out	Scale-In	Result
HPA	3 → 5 pods	4 → 3 pods	Complete
Cluster Autoscaler	2 → 3 nodes	3 → 2 nodes	Complete
VPA	Recommendation approach	Not automatic	Evaluated


The cluster therefore demonstrated the intended pattern:
Off-peak: fewer replicas and 2 worker nodes
Peak: more application replicas and 3 worker nodes
Reliability During Autoscaling
The autoscaling tests were performed using the controlled NGINX workload.
Observed reliability characteristics during the implemented stages included:
- Application pods remained schedulable.
- HPA successfully created additional replicas.
- Additional worker capacity joined the cluster successfully.
- Worker nodes reached Ready status.
- Node capacity was removed after the workload decreased.
- No OOMKills were observed during the right-sizing validation.
- No application restart issue was observed during the controlled autoscaling workflow.
The benchmark was controlled and does not represent production traffic or a production availability guarantee.
Cost Optimization Impact
The combination of right-sizing and autoscaling improves cost efficiency in two separate ways.
Right-sizing reduces the amount of CPU and memory capacity reserved by each application pod. This gives the Kubernetes scheduler more flexibility to place workloads efficiently.
HPA prevents the application from permanently running peak replica counts when demand is low.
Cluster Autoscaler prevents the cluster from permanently running peak worker capacity when workloads do not require it.
Together:
Right-sizing → better bin-packing → less reserved capacity
HPA → fewer pods during low demand
Cluster Autoscaler → fewer worker nodes during low demand
This reduces infrastructure waste while retaining the ability to scale when demand increases.
Stage 3 Conclusion
Stage 3 successfully implemented and demonstrated pod and node autoscaling.
The HPA scaled the application from 3 to 5 replicas during increased demand and demonstrated scale-in during reduced demand.
Cluster Autoscaler scaled worker capacity from 2 to 3 nodes during increased scheduling pressure and subsequently reduced the cluster from 3 to 2 nodes when the additional capacity was no longer required.
VPA was evaluated and intentionally not enabled in automatic update mode because the project already uses HPA and resource-request-based CPU scaling.
Stage 3 therefore establishes automatic demand-based scaling while maintaining the right-sized resource configuration from Stage 2.
Stage 4 — Spot Capacity
Status: Planned
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
Stage 5 — Cost and Reliability Measurement
Status: Planned
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
Final Reliability Principle
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