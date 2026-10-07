# Kubernetes Cost Optimization on Amazon EKS

A practical Kubernetes cost optimization project on Amazon EKS focused on resource right-sizing, bin-packing, horizontal pod autoscaling, node autoscaling, and Spot capacity while maintaining workload reliability.

---

## Project Status

| Stage | Area | Status |
|---|---|---|
| Stage 1 | Baseline Waste Measurement | ✅ Complete |
| Stage 2 | Right-Sizing & Bin-Packing | ✅ Complete |
| Stage 3 | Autoscaling | ✅ Complete |
| Stage 4 | Spot Optimization | ✅ Complete |
| Stage 5 | Cost Measurement & Reporting | 🚧 In Progress |

---

## Objective

The objective of this project is to identify and reduce unnecessary Kubernetes infrastructure cost while maintaining application reliability and workload availability.

The project evaluates:

- CPU and memory request/limit optimization
- Kubernetes bin-packing
- Horizontal Pod Autoscaling (HPA)
- Vertical Pod Autoscaling (VPA) evaluation
- Cluster Autoscaler
- Amazon EC2 Spot capacity
- Spot interruption handling
- Workload rescheduling
- Cost measurement and visibility
- Cost regression detection

The implementation is performed on a personal Amazon EKS test environment using controlled workloads.

---

# Architecture

```text
                         Amazon EKS
                            │
             ┌──────────────┴──────────────┐
             │                             │
       On-Demand Node Group           Spot Node Group
       baseline-workers                 spot-workers
             │                             │
       t3.small nodes                  t3a.small
             │                             │
       ┌─────┴─────┐                  Spot Workloads
       │           │
   System Pods   Applications
                     │
             cost-baseline-app
                     │
             ┌───────┴───────┐
             │               │
             HPA             Service
             │
        2–6 replicas
             │
             ▼
      Cluster Autoscaler
             │
       Node scale-out/in
Environment
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
Monitoring	Kubernetes Metrics Server


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
    │
    └── screenshots/

Stage 1 — Baseline Waste Measurement
Status
✅ Complete
The first stage established a baseline for resource requests, actual workload usage, node utilization, scaling behavior, and reliability.
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
During controlled load testing, the application pods showed approximately:
CPU usage:
~65–81m total across 4 application pods

Memory usage:
~12Mi total across 4 application pods

The original requests were:
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

The cluster was running two t3.small On-Demand nodes.
Scaling Baseline
At the beginning of the project:
HPA:                  Not configured
VPA:                  Not configured
Cluster Autoscaler:   Not configured
Karpenter:            Not configured
Spot:                 Not configured

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
This provided the basis for Stage 2 resource right-sizing.
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


The workload request footprint was reduced by approximately:
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
The experiment demonstrated that placing all replicas on a single node was not feasible under the current EKS system workload and node capacity constraints.
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
The optimized resource configuration was then used as the foundation for autoscaling.
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
During increased workload demand, the HPA increased application capacity.
Observed behavior included:
3 replicas → 5 replicas

This demonstrated automatic pod scale-out when CPU utilization increased.
HPA Scale-In
After the additional workload was removed, the HPA reduced the number of application replicas.
Observed behavior included:
4 replicas → 3 replicas

The HPA therefore demonstrated both scale-out and scale-in behavior.
VPA Evaluation
Vertical Pod Autoscaler was evaluated as part of the project.
The cluster did not have the VPA CRD installed.
VPA was therefore not enabled for automatic resource mutation.
The project uses the following approach:
VPA:
Recommendation/evaluation only
Automatic mutation:
Disabled

This avoids introducing unnecessary interaction between VPA and HPA.
VPA can be useful for long-term resource recommendation and right-sizing, while HPA is used for horizontal scaling based on demand.
Cluster Autoscaler
Cluster Autoscaler was selected instead of Karpenter for this implementation because the project already uses a managed EKS node group.
The baseline node group:
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

Cluster Autoscaler Configuration
Cluster Autoscaler was installed using Helm with AWS IAM integration.
An IAM policy was created with permissions required for:
Auto Scaling group discovery
Auto Scaling group description
EC2 instance information
Scaling activities
Desired capacity changes
Instance termination

An IAM service account was created for the Cluster Autoscaler.
Node Scale-Out
Additional workload was introduced to create scheduling pressure.
The cluster automatically increased capacity.
Observed transition:
2 nodes → 3 nodes

This demonstrated automatic node scale-out when additional capacity was required.
Node Scale-In
After the additional workload was removed, the application replicas were reduced and excess load generators were deleted.
The Cluster Autoscaler subsequently reduced worker capacity.
Observed transition:
3 nodes → 2 nodes

This demonstrated automatic node scale-in when the additional capacity was no longer required.
Autoscaling Cost Impact
Cluster Autoscaler prevents the cluster from permanently maintaining peak capacity.
Instead of keeping additional worker nodes running continuously:
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
Stage 3 Architecture
                   Application Demand
                          │
                          ▼
                     ┌────────┐
                     │  HPA   │
                     └────┬───┘
                          │
                    Pod replicas
                          │
                          ▼
                 Scheduling pressure
                          │
                          ▼
              ┌─────────────────────┐
              │ Cluster Autoscaler  │
              └──────────┬──────────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         Scale Out              Scale In
         Nodes +1               Nodes -1

Stage 4 — Spot Optimization
Status
✅ Complete
Stage 4 introduced Amazon EC2 Spot capacity for workloads that can tolerate interruption while keeping the primary worker capacity on On-Demand instances.
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

The actual Spot node used during testing was:
t3a.small

On-Demand Baseline
The existing baseline-workers node group remained On-Demand.
This provides a stable capacity layer for:
- Kubernetes system workloads
- Critical application workloads
- Workloads that cannot tolerate interruption
The project therefore uses a mixed capacity model:
On-Demand
    │
    ├── Critical workloads
    ├── System capacity
    └── Baseline capacity

Spot
    │
    └── Interruption-tolerant workloads

Spot Workload
A dedicated demonstration workload was created:
Namespace:
cost-baseline

Deployment:
spot-demo-app

Replicas:
2

The deployment uses:
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:

with a preference for:
eks.amazonaws.com/capacityType=SPOT

This allows the workload to prefer Spot capacity while remaining schedulable on On-Demand capacity if required.
Spot Resource Configuration
The Spot workload uses the same right-sized resources:
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
AWS Node Termination Handler was installed.
The configuration enables:
Spot interruption draining
Rebalance monitoring
Scheduled event draining

The Node Termination Handler operates in IMDS mode.
Spot Interruption Simulation
A controlled interruption scenario was simulated by draining the Spot node.
The Spot node was:
Cordoned
↓
Drained
↓
Pods evicted
↓
Pods rescheduled

The two Spot workload replicas were automatically rescheduled onto the available On-Demand nodes.
Reliability Result
After the simulated Spot node interruption:
spot-demo-app replica 1 → Running
spot-demo-app replica 2 → Running

Restarts:
0 observed

Final status:
2/2 Running

This demonstrated that the workload survived the node interruption and was rescheduled onto remaining capacity.
The test did not use an external continuous request probe, so it does not claim a measured zero-second downtime window.
Spot Cost Analysis
AWS Spot price history was captured for the t3a.small instance type in ap-south-1.
Observed Spot prices during the test included approximately:
$0.0055/hour
$0.0061/hour
$0.0067/hour

Spot pricing changes by:
- Availability Zone
- Instance type
- Time
- Capacity availability
Therefore, Spot savings should be treated as variable rather than a fixed percentage.
The project compares Spot capacity against the equivalent On-Demand capacity for the same workload.
Spot Workload Selection
Suitable workloads for Spot include:
- Stateless applications
- Batch jobs
- CI/CD workers
- Development workloads
- Test workloads
- Asynchronous processing
- Fault-tolerant workloads
Critical workloads remain on On-Demand capacity because Spot instances can be interrupted.
Stage 4 Architecture
                       EKS Cluster
                           │
             ┌─────────────┴─────────────┐
             │                           │
       On-Demand                     Spot
       baseline-workers              spot-workers
             │                           │
             │                     spot-demo-app
             │                           │
       Critical/System              Preferred
       workloads                      Spot
             │                           │
             └─────────────┬─────────────┘
                           │
                  Spot interruption
                           │
                           ▼
                Node Termination Handler
                           │
                           ▼
                       Drain node
                           │
                           ▼
                    Pod rescheduling
                           │
                           ▼
                    On-Demand nodes

Overall Optimization Strategy
The project combines multiple Kubernetes cost optimization techniques instead of relying on a single optimization mechanism.
                Kubernetes Cost Optimization
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
   Right-Sizing           HPA             Node Scaling
       │                   │                   │
       ▼                   ▼                   ▼
Lower requests       Match pods to      Match nodes to
and limits           workload demand    cluster demand
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                           ▼
                     Better density
                           │
                           ▼
                    Lower waste
                           │
                           ▼
                     Spot capacity
                           │
                           ▼
                  Lower compute cost

Reliability Controls
Cost optimization is performed without intentionally sacrificing workload reliability.
Controls used in the project include:
- Kubernetes resource requests
- Resource limits
- HPA minimum replicas
- HPA maximum replicas
- On-Demand baseline capacity
- Spot interruption handling
- Pod rescheduling
- Controlled testing
- No automatic VPA mutation
- Controlled benchmark workloads
Stage 5 — Cost Measurement and Reporting
Status
🚧 In Progress
Stage 5 is the final measurement and reporting stage.
The remaining work includes:
- Final before/after cost comparison
- Cost visibility by namespace
- Cost visibility by workload
- Cost regression detection
- Cost alarm implementation
- Deliberate regression test
- Final optimization report
- Final savings summary
Planned Cost Comparison
The final report will compare:
Baseline:
2 × On-Demand t3.small

vs.

Optimized:
Right-sized workloads
+
HPA
+
Cluster Autoscaler
+
Spot workloads

The report will distinguish between:
1. Resource-request optimization
2. Node-capacity optimization
3. Spot savings
4. Actual infrastructure cost impact
This is important because reducing Kubernetes requests alone does not necessarily reduce AWS billing unless it also reduces required node capacity.
Planned Cost Visibility
Stage 5 will provide cost visibility at:
Cluster
   │
   ├── Namespace
   │      │
   │      ├── Deployment
   │      ├── Workload
   │      └── Pods
   │
   └── Node capacity

The goal is to identify which namespaces and workloads consume the largest share of available compute capacity.
Cost Regression Detection
A cost regression check will be introduced to detect situations such as:
Traffic:
No significant increase

but

Cluster cost:
Significant increase

Potential causes include:
- Over-requested CPU
- Over-requested memory
- Excess replicas
- HPA configuration problems
- Nodes remaining idle
- Failed scale-in
- Unexpected On-Demand capacity
- Spot fallback to On-Demand
- Scheduling inefficiency
Planned Regression Test
The regression mechanism will be deliberately triggered using a controlled test condition.
The test will demonstrate:
Normal baseline
      ↓
Cost threshold
      ↓
Controlled increase
      ↓
Regression detected
      ↓
Alarm / alert generated

The test will be performed only on the personal EKS test environment.
Final Cost Report
The final report will contain:
1. Baseline infrastructure
2. Optimized infrastructure
3. Resource request reduction
4. Node utilization
5. HPA scaling behavior
6. Cluster Autoscaler behavior
7. Spot usage
8. Spot interruption result
9. Spot savings
10. Namespace/workload cost visibility
11. Cost regression detection
12. Reliability results
13. Final cost comparison
14. Optimization recommendations

Reliability Summary
The completed stages have demonstrated:
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
Cost regression alarm	🚧 Stage 5
Final cost report	🚧 Stage 5


Key Findings So Far
1. Right-sizing significantly reduced requested capacity
The application CPU request was reduced from:
250m → 50m per pod

Memory request was reduced from:
256Mi → 32Mi per pod

while maintaining the controlled workload's reliability.
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
Node Termination Handler and Kubernetes rescheduling allowed the test workload to survive a controlled Spot node drain.
Cost Optimization Principles
This project follows several important Kubernetes cost principles:
Avoid excessive requests
Requests influence Kubernetes scheduling and therefore influence how much cluster capacity is required.
Right-size before scaling
Scaling an incorrectly sized workload can multiply wasted capacity.
Use HPA for workload demand
HPA allows application replicas to follow workload demand.
Use node autoscaling for infrastructure demand
Cluster Autoscaler allows worker capacity to follow pod scheduling requirements.
Use Spot for fault-tolerant workloads
Spot capacity should be used where interruption is acceptable.
Keep critical capacity On-Demand
Critical workloads should retain reliable baseline capacity.
Measure before claiming savings
Kubernetes resource reduction should not automatically be described as AWS billing reduction.
The final report will separate:
Resource efficiency
vs.
Actual infrastructure cost savings

Evidence and Documentation
Detailed implementation results are documented in:
docs/k8s-cost-report.md

Research and technology comparison:
docs/research.md

Operational troubleshooting and cost regression guidance:
docs/runbook.md

Screenshots and supporting evidence:
docs/screenshots/

Cleanup
The project uses a personal test AWS environment.
After completing the final review, temporary resources should be removed to avoid unnecessary AWS charges.
Resources to review before cleanup include:
EKS cluster
Node groups
Spot capacity
Load generators
Test workloads
Autoscaling components
AWS IAM resources
Helm releases

Example cleanup commands should only be executed after all required evidence has been captured.
Project Completion
Current status:
Stage 1  ✅ Complete
Stage 2  ✅ Complete
Stage 3  ✅ Complete
Stage 4  ✅ Complete
Stage 5  🚧 In Progress

The project will be considered fully complete after Stage 5 demonstrates:
Before/after cost measurement
+
Namespace/workload cost visibility
+
Cost regression alarm
+
Deliberate regression test
+
Final Kubernetes cost report

Author
Sakib Sheikh
DevOps / Cloud Engineering Project
Technologies:
AWS
Amazon EKS
Kubernetes
Docker
Helm
Linux
Terraform
Git
GitHub
HPA
Cluster Autoscaler
EC2 Spot
AWS Node Termination Handler
