# Kubernetes Cost Optimization on Amazon EKS

A practical Kubernetes cost optimization project on Amazon EKS focused on **resource right-sizing, bin-packing, horizontal pod autoscaling, node autoscaling, cost visibility, regression detection, and Spot capacity** while maintaining workload reliability.

---

## Project Status

| Stage | Area | Status |
|---|---|---|
| Stage 1 | Baseline Waste Measurement | ✅ Complete |
| Stage 2 | Right-Sizing & Bin-Packing | ✅ Complete |
| Stage 3 | Autoscaling | ✅ Complete |
| Stage 4 | Spot Optimization | ✅ Complete |
| Stage 5 | Cost Measurement & Reporting | ✅ Complete |

---

## Objective

The objective of this project was to identify and reduce unnecessary Kubernetes infrastructure cost while maintaining application reliability and workload availability.

The project evaluates:

- CPU and memory request/limit optimization
- Kubernetes bin-packing
- Horizontal Pod Autoscaling (HPA)
- Vertical Pod Autoscaling (VPA) evaluation
- Cluster Autoscaler
- Amazon EC2 Spot capacity
- Spot interruption handling
- Workload rescheduling
- Namespace/workload cost visibility
- Cost regression detection
- Before/after infrastructure cost comparison

The implementation was performed on a personal Amazon EKS test environment using controlled workloads.

---

# Architecture

```text
                             Amazon EKS
                                  |
                 +----------------+----------------+
                 |                                 |
          On-Demand Node Group                Spot Node Group
           baseline-workers                    spot-workers
                 |                                 |
            t3.small nodes                    t3a.small
                 |                                 |
        +--------+--------+                 Spot Workloads
        |                 |
   System Pods       Applications
                          |
                   cost-baseline-app
                          |
                    +-----+-----+
                    |           |
                   HPA        Service
                    |
                2–6 replicas
                    |
                    v
             Cluster Autoscaler
                    |
              Node scale-out/in

        Cost Visibility Layer
                    |
        +-----------+-----------+
        |                       |
     Prometheus              OpenCost
        |                       |
        +-----------+-----------+
                    |
       Namespace / Workload Cost
                    |
          Cost Regression Check


#Environment
Component	Configuration
Cloud	Amazon Web Services
Kubernetes	Amazon EKS
Region	ap-south-1
Kubernetes Version	1.36
Baseline Node Type	t3.small
Spot Node Type	t3a.small
Baseline Capacity	On-Demand
Spot Capacity	EC2 Spot
Container Runtime	containerd
Package Manager	Helm
Infrastructure Tool	eksctl
Monitoring	Kubernetes Metrics Server + Prometheus
Cost Visibility	OpenCost
Autoscaling	HPA + Cluster Autoscaler
Spot Handling	AWS Node Termination Handler


Repository Structure
eks-kubernetes-cost-optimization/
│
├── README.md
│
├── autoscaling/
│   ├── hpa/
│   │   └── hpa.yaml
│   │
│   └── cluster-autoscaler-policy.json
│
├── right-sizing/
│   └── baseline-workload.yaml
│
├── spot/
│   └── spot-workload.yaml
│
└── docs/
    ├── k8s-cost-report.md
    ├── research.md
    ├── runbook.md
    ├── cost-regression-check.ps1
    └── screenshots/

Stage 1 — Baseline Waste Measurement
Status
✅ Complete
The first stage established a baseline for:
- Resource requests
- Actual workload usage
- Node utilization
- Scaling behavior
- Reliability
- Scheduling efficiency
Baseline Workload
A controlled NGINX workload was deployed in the cost-baseline namespace.
Initial configuration:
replicas: 4

requests:
  cpu: 250m
  memory: 256Mi

limits:
  cpu: 500m
  memory: 512Mi

The workload was intentionally configured with relatively high resource requests to demonstrate the effect of over-requesting.
Baseline Measurements
During controlled load testing, the four application pods showed approximately:
CPU usage:
~65–81m total across 4 application pods

Memory usage:
~12Mi total across 4 application pods

Original requested capacity:
CPU:
4 × 250m = 1000m

Memory:
4 × 256Mi = 1024Mi

This demonstrated significant unused requested capacity.
Node Utilization
During the baseline load test:
Node 1:
CPU    ~39%
Memory ~55%

Node 2:
CPU    ~11%
Memory ~54%

The cluster initially used two t3.small On-Demand worker nodes.
Scaling Baseline
At the beginning of the project:
HPA:                 Not configured
VPA:                 Not configured
Cluster Autoscaler:  Not configured
Karpenter:           Not configured
Spot:                Not configured

Worker nodes:
2 fixed On-Demand nodes

Reliability Baseline
The baseline workload maintained:
4/4 replicas available
0 observed application restarts
No OOMKills
System pods healthy

Stage 1 Conclusion
The baseline demonstrated that the workload was requesting substantially more CPU and memory than it actually consumed.
This provided the basis for resource right-sizing and improved bin-packing.
Stage 2 — Right-Sizing and Bin-Packing
Status
✅ Complete
Stage 2 reduced CPU and memory requests and limits using the observed workload behavior from Stage 1.
Right-Sized Configuration
The application was changed to:
requests:
  cpu: 50m
  memory: 32Mi

limits:
  cpu: 200m
  memory: 64Mi

The deployment remained at:
4 replicas

Before vs After
Resource	Before	After
CPU request / pod	250m	50m
Memory request / pod	256Mi	32Mi
CPU limit / pod	500m	200m
Memory limit / pod	512Mi	64Mi
Total CPU request	1000m	200m
Total memory request	1024Mi	128Mi


Request footprint reduction:
CPU request:     80%
Memory request:  87.5%

Reliability After Right-Sizing
After applying the new resources:
4/4 replicas available
0 observed restarts
No OOMKills
All application pods Running

The workload remained stable under the controlled benchmark.
Bin-Packing Experiment
A controlled scheduling experiment was performed to evaluate whether all application replicas could be concentrated onto one worker node.
The experiment demonstrated that placing all replicas on a single node was not feasible under the current EKS system workload and node-capacity constraints.
The deployment was restored to normal scheduling afterward.
Important Cost Observation
Reducing Kubernetes requests does not automatically reduce AWS cost if the number of EC2 worker nodes remains unchanged.
Right-sizing primarily improves:
- Pod density
- Bin-packing
- Scheduling efficiency
- Capacity utilization
- Ability to delay or avoid node scale-out
The largest infrastructure savings occur when right-sizing allows the cluster to run fewer nodes.
Stage 2 Conclusion
Right-sizing successfully reduced the workload's requested CPU and memory footprint while maintaining reliability.
The optimized configuration became the foundation for autoscaling.
Stage 3 — Autoscaling
Status
✅ Complete
Stage 3 introduced:
- Horizontal Pod Autoscaler
- VPA evaluation
- Cluster Autoscaler
- Automatic node scale-out
- Automatic node scale-in
HPA
The Horizontal Pod Autoscaler was configured for the application.
Configuration:
Minimum replicas: 2
Maximum replicas: 6
CPU target:       60%

The HPA uses CPU utilization to automatically adjust application replica count.
HPA Scale-Out
During increased workload demand:
3 replicas → 5 replicas

This demonstrated automatic pod scale-out when CPU utilization increased.
HPA Scale-In
After additional workload was removed:
4 replicas → 3 replicas

This demonstrated HPA scale-in behavior.
VPA Evaluation
Vertical Pod Autoscaler was evaluated as part of the project.
The cluster did not have the VPA CRD installed, so VPA was not enabled for automatic resource mutation.
The project uses:
VPA:
Recommendation/evaluation only

Automatic mutation:
Disabled

This avoids unnecessary interaction between VPA and HPA.
VPA can be useful for long-term resource recommendations and right-sizing, while HPA is used for horizontal scaling based on workload demand.
Cluster Autoscaler
Cluster Autoscaler was selected instead of Karpenter because the project already uses a managed EKS node group.
Baseline node group:
Name:
baseline-workers

Instance type:
t3.small

Capacity:
On-Demand

Minimum:
2 nodes

Maximum:
4 nodes

Cluster Autoscaler was installed using Helm with AWS IAM integration.
The required IAM policy and IAM service account were created for Auto Scaling and EC2 capacity management.
Node Scale-Out
Additional workload was introduced to create scheduling pressure.
Observed transition:
2 nodes → 3 nodes

This demonstrated automatic node scale-out when additional capacity was required.
Node Scale-In
After the additional workload was removed and application replicas were reduced:
3 nodes → 2 nodes

This demonstrated automatic node scale-in when additional capacity was no longer required.
Autoscaling Cost Impact
Cluster Autoscaler prevents the cluster from permanently maintaining peak capacity.
Normal demand
     ↓
Fewer nodes

High demand
     ↓
Additional nodes

Demand decreases
     ↓
Unused nodes removed

This improves infrastructure utilization and reduces unnecessary worker-node cost during periods of lower demand.
Stage 4 — Spot Optimization
Status
✅ Complete
Stage 4 introduced Amazon EC2 Spot capacity for workloads that can tolerate interruption while keeping primary baseline capacity on On-Demand instances.
Spot Node Group
A dedicated Spot managed node group was created:
Name:
spot-workers

Capacity type:
SPOT

Instance types:
t3.small
t3a.small

Initial nodes:
1

Minimum:
1

Maximum:
2

The actual Spot node used during testing was t3a.small.
On-Demand Baseline
The existing baseline-workers node group remained On-Demand.
This provides stable capacity for:
- Kubernetes system workloads
- Critical application workloads
- Workloads that cannot tolerate interruption
- Baseline capacity
The project therefore uses a mixed capacity model:
On-Demand
    |
    +-- Critical workloads
    +-- System capacity
    +-- Baseline capacity

Spot
    |
    +-- Interruption-tolerant workloads

Spot Workload
A dedicated demonstration workload was created:
Namespace:
cost-baseline

Deployment:
spot-demo-app

Replicas:
2

The deployment uses preferred node affinity for:
eks.amazonaws.com/capacityType=SPOT

This allows the workload to prefer Spot capacity while remaining schedulable on On-Demand capacity when required.
Spot Resource Configuration
The Spot workload uses the right-sized resources:
requests:
  cpu: 50m
  memory: 32Mi

limits:
  cpu: 200m
  memory: 64Mi

This combines:
Right-sizing
      +
Spot capacity
      =
Lower capacity cost with efficient resource usage

Spot Interruption Handling
AWS Node Termination Handler was installed with:
- Spot interruption draining
- Rebalance monitoring
- Scheduled event draining
The handler operated in IMDS mode.
Spot Interruption Simulation
A controlled interruption scenario was simulated by draining the Spot node.
Spot node
    ↓
Cordoned
    ↓
Drained
    ↓
Pods evicted
    ↓
Pods rescheduled
    ↓
On-Demand nodes

The two Spot workload replicas were automatically rescheduled onto available On-Demand nodes.
Reliability result:
spot-demo-app replica 1 → Running
spot-demo-app replica 2 → Running

Restarts:
0 observed

Final status:
2/2 Running

The test did not use an external continuous request probe, so this project does not claim a measured zero-second downtime window.
Spot Cost Analysis
Observed t3a.small Spot prices in ap-south-1 during testing included approximately:
$0.0055/hour
$0.0061/hour
$0.0067/hour

Spot pricing varies by:
- Availability Zone
- Instance type
- Time
- Capacity availability
Therefore, Spot savings are variable rather than a fixed percentage.
Equivalent Peak Capacity Comparison
Official On-Demand pricing used for the comparison:
t3.small On-Demand:
$0.0224/hour

t3a.small On-Demand:
$0.0123/hour

For an equivalent three-node peak capacity:
Baseline:
3 × t3.small On-Demand
= $0.0672/hour

Optimized:
2 × t3.small On-Demand
+ 1 × t3a.small Spot
= $0.0503/hour

Observed saving at the latest captured Spot price:
$0.0672 - $0.0503
= $0.0169/hour

Approximate saving:
25.1%

This is an equivalent-capacity Spot comparison, not a claim that the entire AWS account or cluster bill decreased by exactly 25.1%.
Spot Workload Selection
Suitable workloads include:
- Stateless applications
- Batch jobs
- CI/CD workers
- Development workloads
- Test workloads
- Asynchronous processing
- Fault-tolerant workloads
Critical workloads remain on On-Demand capacity because Spot instances can be interrupted.
Stage 5 — Cost Measurement and Reporting
Status
✅ Complete
Stage 5 completed:
- Cost visibility
- Namespace-level cost allocation
- Workload-level cost allocation
- Cost regression detection
- Deliberate regression testing
- Final before/after cost comparison
- Reliability summary
- Final Kubernetes cost report
Cost Visibility
Prometheus was deployed as the metrics source.
OpenCost was deployed for Kubernetes cost allocation.
OpenCost was queried through its allocation API for:
Namespace
Workload

This provided visibility into CPU and memory requests, usage, efficiency and estimated resource cost.
Example namespace-level observation:
cost-baseline:
CPU request: approximately 0.2 cores
CPU cost:    approximately $0.00053
RAM request: approximately 128Mi
RAM cost:    approximately $0.00004
Total sample cost: approximately $0.00057

These values are short controlled-window allocation samples and should not be interpreted as the complete AWS invoice.
Cost Regression Detection
A PowerShell regression check was added:
docs/cost-regression-check.ps1

The check detects CPU request regression against the optimized baseline.
Optimized value:
50m CPU request per pod

Regression threshold:
75m CPU request per pod

The script reports:
PASS
WARNING
or
ALERT

depending on the current resource configuration.
Deliberate Regression Test
The optimized workload was deliberately changed:
50m → 100m CPU request

The regression script detected:
ALERT: CPU request regression detected!

Current request 100m exceeds threshold 75m.

This can reduce bin-packing efficiency and increase node cost.

The workload was then restored to the optimized:
50m CPU request

This demonstrated that the project can detect resource-request creep before it silently increases scheduling and capacity requirements.
Final Cost and Efficiency Summary
Resource Efficiency
Metric	Baseline	Optimized
CPU request / pod	250m	50m
Memory request / pod	256Mi	32Mi
CPU limit / pod	500m	200m
Memory limit / pod	512Mi	64Mi
Total CPU request	1000m	200m
Total memory request	1024Mi	128Mi


Reduction:
CPU request:
80%

Memory request:
87.5%

These percentages describe Kubernetes requested-capacity reduction, not direct AWS billing reduction.
Autoscaling Efficiency
Demonstrated:
HPA:
3 → 5 replicas during increased demand

HPA:
4 → 3 replicas after demand decreased

Cluster Autoscaler:
2 → 3 nodes during scheduling pressure

Cluster Autoscaler:
3 → 2 nodes after demand decreased

This avoids maintaining peak application and node capacity continuously.
Spot Capacity Efficiency
At the latest captured Spot price:
3 × t3.small On-Demand:
$0.0672/hour

2 × t3.small On-Demand
+ 1 × t3a.small Spot:
$0.0503/hour

Difference:
$0.0169/hour

Equivalent-capacity saving:
~25.1%

The comparison isolates Spot capacity savings. It is not presented as a full AWS billing-period saving.
Reliability Summary
Test	Result
Baseline application	✅ Stable
Right-sized application	✅ Stable
HPA scale-out	✅ Demonstrated
HPA scale-in	✅ Demonstrated
Cluster Autoscaler scale-out	✅ Demonstrated
Cluster Autoscaler scale-in	✅ Demonstrated
Spot workload scheduling	✅ Demonstrated
Spot node drain	✅ Demonstrated
Spot workload rescheduling	✅ Demonstrated
OOMKill after right-sizing	✅ None observed
Application restart during Spot test	✅ None observed
Cost regression detection	✅ Triggered deliberately
Final cost report	✅ Complete


Key Findings
1. Right-sizing reduces wasted requested capacity
The application CPU request was reduced:
250m → 50m per pod

Memory request was reduced:
256Mi → 32Mi per pod

while maintaining reliability under the controlled benchmark.
2. HPA matches application capacity to demand
HPA automatically increased and decreased application replicas based on CPU utilization.
This prevents permanently running the maximum number of application replicas.
3. Cluster Autoscaler matches worker capacity to scheduling demand
Cluster Autoscaler demonstrated:
2 → 3 nodes

during increased demand and:
3 → 2 nodes

after demand decreased.
4. Spot reduces compute cost for suitable workloads
Spot capacity was used for an interruption-tolerant workload while critical baseline capacity remained On-Demand.
5. Spot interruptions must be handled
AWS Node Termination Handler and Kubernetes rescheduling allowed the test workload to survive a controlled Spot node drain.
6. Cost regression can come from resource requests
A workload can become more expensive even without a corresponding traffic increase if:
- CPU requests creep upward
- Memory requests creep upward
- Replica counts remain unnecessarily high
- HPA settings are incorrect
- Nodes fail to scale in
- Spot workloads fall back to On-Demand
- Scheduling becomes inefficient
Cost Optimization Strategy
The project combines multiple optimization techniques instead of relying on a single mechanism.
                 Kubernetes Cost Optimization
                            |
        +-------------------+-------------------+
        |                   |                   |
   Right-Sizing            HPA            Node Scaling
        |                   |                   |
        v                   v                   v
 Lower requests        Match pods to      Match nodes to
 and limits            workload demand    cluster demand
        |                   |                   |
        +-------------------+-------------------+
                            |
                            v
                      Better density
                            |
                            v
                       Lower waste
                            |
                            v
                       Spot capacity
                            |
                            v
                    Lower compute cost

Reliability Controls
Cost optimization was performed without intentionally sacrificing workload reliability.
Controls used:
- Kubernetes resource requests
- Resource limits
- HPA minimum replicas
- HPA maximum replicas
- On-Demand baseline capacity
- Spot interruption handling
- Pod rescheduling
- Controlled benchmark workloads
- No automatic VPA mutation
- Cost regression detection
- Controlled testing before and after optimization
VPA vs HPA vs Cluster Autoscaler vs Karpenter
Technology	Primary Function	Project Decision
HPA	Adjust pod replicas	✅ Implemented
VPA	Adjust pod resource recommendations/requests	📝 Evaluated
Cluster Autoscaler	Adjust node count	✅ Implemented
Karpenter	Provision right-sized nodes dynamically	📝 Compared, not implemented


Project Decision
HPA was used for application-level scaling.
Cluster Autoscaler was used for node-level scaling because the project already used an EKS managed node group.
VPA was kept as recommendation/evaluation only.
Karpenter was evaluated as an alternative but was not introduced into the test environment because it would add another node provisioning model without being necessary to demonstrate the required node autoscaling behavior.
Trade-Offs
Right-Sizing
Benefit:
- Lower requested capacity
- Better bin-packing
- Less scheduling waste
Risk:
- Requests that are too low can cause contention or instability
Decision:
Use measured workload behavior plus safety headroom rather than aggressively matching the lowest observed usage.
HPA
Benefit:
- Automatically matches application replica count to demand
Risk:
- Poor thresholds can cause slow scaling or unnecessary replica churn
Decision:
Use a bounded replica range of 2–6 with a 60% CPU target.
Cluster Autoscaler
Benefit:
- Removes unnecessary worker capacity
Risk:
- Node provisioning and termination are slower than pod scaling
Decision:
Use HPA for pod-level demand and Cluster Autoscaler for infrastructure-level demand.
Spot
Benefit:
- Lower compute cost
Risk:
- Instances can be interrupted
Decision:
Use Spot for interruption-tolerant workloads and retain On-Demand capacity for critical/system workloads.
Hardest Workload to Optimize Safely
The hardest workload to optimize safely was the baseline application under the EKS system-capacity constraint.
The right-sized application itself tolerated the resource reduction successfully, but the bin-packing experiment demonstrated that aggressively concentrating all application replicas onto a single small worker node was not safe under the existing EKS system workload.
This established an important operational boundary:
Optimize workload requests aggressively enough to improve density, but do not force node consolidation beyond the capacity required by Kubernetes system components and reliability requirements.

Evidence and Documentation
Detailed implementation results:
docs/k8s-cost-report.md

Research and technology comparison:
docs/research.md

Operational troubleshooting and cost regression guidance:
docs/runbook.md

Cost regression check:
docs/cost-regression-check.ps1

Screenshots and supporting evidence:
docs/screenshots/

Cleanup
The project uses a personal AWS test environment.
After final review and evidence capture, temporary AWS resources should be removed to avoid unnecessary charges.
Resources to review before cleanup:
- EKS cluster
- On-Demand node group
- Spot node group
- Load generators
- Test workloads
- HPA
- Cluster Autoscaler
- Prometheus
- OpenCost
- AWS Node Termination Handler
- AWS IAM policies/service accounts
- Helm releases
Example cluster cleanup:
eksctl delete cluster `
  --name eks-cost-optimization `
  --region ap-south-1

Only execute cleanup after all required screenshots, reports and evidence have been captured.
Project Completion
Stage 1  ✅ Complete
Stage 2  ✅ Complete
Stage 3  ✅ Complete
Stage 4  ✅ Complete
Stage 5  ✅ Complete

Final Outcome
The project successfully demonstrated a complete Kubernetes cost optimization workflow:
Baseline
   ↓
Measure Waste
   ↓
Right-Size Requests/Limits
   ↓
Improve Bin-Packing
   ↓
HPA Pod Scaling
   ↓
Cluster Autoscaler Node Scaling
   ↓
Introduce Spot Capacity
   ↓
Handle Spot Interruption
   ↓
Measure Namespace/Workload Cost
   ↓
Detect Cost Regression
   ↓
Compare Optimized Capacity
   ↓
Produce Final Cost Report

The final implementation reduced the controlled workload's requested CPU by 80% and memory by 87.5%, demonstrated dynamic pod and node scaling, introduced Spot capacity for suitable workloads, successfully handled a controlled Spot interruption, and implemented cost visibility and regression detection.
The equivalent three-node peak-capacity comparison showed approximately 25.1% Spot capacity savings at the latest observed Spot price. This is intentionally presented as a capacity comparison rather than a claim about the total AWS billing account.
Author
Sakib Sheikh
DevOps / Cloud Engineering Project
Technologies
- AWS
- Amazon EKS
- Kubernetes
- Docker
- Helm
- Linux
- Terraform
- eksctl
- Git
- GitHub
- Prometheus
- OpenCost
- HPA
- Cluster Autoscaler
- EC2 Spot
- AWS Node Termination Handler
