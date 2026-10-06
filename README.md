# Kubernetes Cost Optimization on Amazon EKS

A practical Kubernetes cost optimization project focused on reducing infrastructure waste while maintaining application reliability.

The project demonstrates resource right-sizing, improved bin-packing, pod autoscaling, node autoscaling, and Spot capacity on Amazon EKS. Each optimization is measured against a controlled baseline to evaluate cost, resource utilization, and reliability before and after the changes.

---

## Project Objective

The main objective is to reduce unnecessary Kubernetes infrastructure cost without compromising workload reliability.

The project focuses on:

- Measuring baseline CPU and memory waste
- Right-sizing Kubernetes resource requests and limits
- Improving pod bin-packing
- Implementing Horizontal Pod Autoscaling (HPA)
- Evaluating Vertical Pod Autoscaling (VPA)
- Implementing node autoscaling using Karpenter
- Using Spot capacity for suitable workloads
- Measuring infrastructure and workload utilization
- Comparing before/after optimization results
- Maintaining reliability during optimization
- Creating operational documentation and troubleshooting runbooks

---

## Environment

| Component | Configuration |
|---|---|
| Cloud | Amazon Web Services |
| Kubernetes Platform | Amazon EKS |
| Region | `ap-south-1` |
| Kubernetes Version | `1.36` |
| Worker Nodes | 2 × `t3.small` |
| Node Capacity | On-Demand |
| Container Runtime | containerd |
| Application | NGINX |
| Application Replicas | 4 |
| Metrics | Kubernetes Metrics Server |

---

## Architecture

```text
                    Amazon EKS
                        |
                eks-cost-optimization
                        |
              +---------+---------+
              |                   |
        t3.small Node       t3.small Node
              |                   |
        +-----+-----+       +-----+-----+
        |           |       |           |
      App Pod     App Pod  App Pod     App Pod
        |           |       |           |
        +-----------+-------+-----------+
                    |
             cost-baseline

The initial environment uses two fixed On-Demand worker nodes.
The application consists of four NGINX replicas deployed in the cost-baseline namespace.
Optimization Stages
Stage 1 — Baseline Waste Analysis
Objective
Measure the current resource allocation and identify potential resource waste before making any optimization changes.
Implemented
- Created Amazon EKS cluster
- Created two t3.small On-Demand worker nodes
- Created cost-baseline namespace
- Deployed four NGINX application replicas
- Configured CPU and memory requests/limits
- Exposed the application using a Kubernetes Service
- Created a temporary load generator
- Measured pod CPU and memory usage
- Measured node CPU and memory utilization
- Checked current autoscaling configuration
- Verified workload reliability
Baseline Application Resources
Each application pod initially requested:
CPU:    250m
Memory: 256Mi

Each pod had limits:
CPU:    500m
Memory: 512Mi

For four replicas:
Total CPU request:    1000m
Total memory request: 1024Mi

Initial Measurements
During the controlled load test, the four application pods together consumed approximately:
CPU:    69–79m
Memory: ~12Mi

The measurements indicate significant resource-request waste under the controlled benchmark.
Node utilization during the load test reached approximately:
Node 1: ~39% CPU / ~55% memory
Node 2: ~11% CPU / ~54% memory

Reliability Baseline
At the end of Stage 1:
Application Pods: 4/4 Running
Restarts:         0
Unavailable Pods: 0

Scaling Baseline
At this stage there was:
- No HPA
- No VPA
- No Karpenter
- No Cluster Autoscaler
- Fixed worker-node count
- Fixed application replica count
Stage 1 establishes the baseline against which later optimization stages will be compared.
Stage 2 — Right-Sizing Requests and Limits
Status: In Progress
Objective
Reduce unnecessary CPU and memory reservations based on measured workload behavior while maintaining application reliability.
Planned Work
- Collect additional representative workload measurements
- Analyze CPU and memory usage
- Determine safe resource requests
- Determine appropriate resource limits
- Update Kubernetes manifests
- Deploy the right-sized workload
- Verify pod stability
- Check for OOMKills and restarts
- Compare node utilization before and after
- Evaluate improved bin-packing
Success Criteria
The optimization should:
- Reduce unnecessary resource reservations
- Improve cluster resource utilization
- Maintain application availability
- Avoid OOMKills
- Avoid unexpected pod restarts
- Maintain acceptable workload performance
Stage 3 — Autoscaling
Status: Planned
Stage 3 will introduce workload and infrastructure autoscaling.
HPA
Horizontal Pod Autoscaler will be evaluated and implemented to automatically increase or decrease application replicas based on workload demand.
VPA
Vertical Pod Autoscaler will be evaluated for resource recommendation and/or automatic resource adjustment.
Node Autoscaling
Karpenter will be evaluated and implemented to dynamically provision and remove worker nodes based on pending pod resource requirements.
Validation
The implementation will demonstrate:
- Scale-out during increased workload
- Scale-in when demand decreases
- Appropriate node provisioning
- Node scale-down during lower demand
- Improved off-peak infrastructure efficiency
Stage 4 — Spot Capacity
Status: Planned
Suitable workloads will be moved to Amazon EC2 Spot capacity to reduce compute cost.
Strategy
Critical workloads will continue using On-Demand capacity.
Suitable interruptible workloads will use Spot capacity.
Planned Validation
- Spot node provisioning
- Workload scheduling on Spot
- Pod disruption handling
- Node drain behavior
- Pod rescheduling
- Interruption handling
- Reliability verification
- Cost comparison against On-Demand capacity
Stage 5 — Cost and Reliability Measurement
Status: Planned
The final stage will compare the optimized environment against the original baseline.
Measurements
The final report will compare:
                    Baseline        Optimized
------------------------------------------------
Node count
CPU requests
Memory requests
CPU utilization
Memory utilization
Application replicas
Infrastructure cost
Estimated savings
Pod availability
Pod restarts
OOMKills

The final result will quantify the overall cost reduction while demonstrating that reliability requirements were maintained.
Project Structure
eks-kubernetes-cost-optimization/
│
├── README.md
│
├── autoscaling/
│   ├── hpa/
│   ├── vpa/
│   └── karpenter/
│
├── right-sizing/
│   └── baseline-workload.yaml
│
├── spot/
│
└── docs/
    ├── k8s-cost-report.md
    ├── research.md
    ├── runbook.md
    │
    └── screenshots/

Measurement Approach
The project uses Kubernetes metrics and controlled workload tests to compare resource allocation with actual resource consumption.
Primary commands include:
kubectl top pods -A
kubectl top nodes
kubectl get pods -A
kubectl describe deployment
kubectl get hpa -A
kubectl get nodes

Measurements are collected under defined benchmark conditions so that before/after comparisons remain meaningful.
Reliability Validation
Each optimization will be validated against reliability indicators including:
- Pod availability
- Pod restart count
- OOMKilled events
- Deployment availability
- Scheduling failures
- Application response behavior
- Node availability
- Autoscaling behavior
Cost optimization will not be considered successful if it causes unacceptable workload instability.
Cost Optimization Principles
The project follows these principles:
1. Measure Before Changing
Resource requests and limits should be based on observed workload behavior rather than arbitrary values.
2. Requests Affect Scheduling
Kubernetes schedules pods according to resource requests. Excessive requests can result in poor bin-packing and unnecessary nodes.
3. Limits Provide Protection
Resource limits are used to prevent a workload from consuming uncontrolled amounts of node resources.
4. Autoscaling Should Follow Demand
Pod and node capacity should increase when demand increases and decrease when demand falls.
5. Use Spot Where Appropriate
Interruptible workloads are candidates for Spot capacity, while critical workloads should retain appropriate On-Demand capacity.
6. Reliability Comes First
Cost reductions must not introduce unacceptable downtime, OOMKills, or workload instability.
Evidence and Documentation
Evidence will be stored under:
docs/screenshots/

Screenshots should show relevant Kubernetes commands and results while avoiding exposure of sensitive information such as:
- AWS account IDs
- Access keys
- Secret keys
- Tokens
- Private credentials
- Unnecessary public IP addresses
Each important optimization result should be documented with its benchmark conditions and expected outcome.
Operational Runbook
The project includes a runbook covering situations such as:
- Cost increases without traffic increases
- Excessive resource requests
- Poor pod bin-packing
- Unexpected node scaling
- Autoscaler failures
- Spot interruptions
- OOMKills
- Workload scheduling failures
See:
docs/runbook.md

Research
The project compares Kubernetes scaling and optimization mechanisms including:
- HPA
- VPA
- Cluster Autoscaler
- Karpenter
- Kubernetes resource requests and limits
- Pod scheduling and bin-packing
- Amazon EC2 Spot Instances
Research and references are documented in:
docs/research.md

Cleanup
Resources created for testing should be removed after the project review to avoid unnecessary AWS charges.
Example:
eksctl delete cluster \
  --name eks-cost-optimization \
  --region ap-south-1

Before deletion, verify that no resources outside this project are being used.
Current Project Status
Stage	Status
Stage 1 — Baseline	✅ Complete
Stage 2 — Right-Sizing	🔄 In Progress
Stage 3 — Autoscaling	⏳ Planned
Stage 4 — Spot	⏳ Planned
Stage 5 — Measurement & Report	⏳ Planned


Author
Sakib Sheikh
DevOps / Cloud Engineering Project
Technologies:
- AWS
- Amazon EKS
- Kubernetes
- Docker
- Linux
- HPA
- VPA
- Karpenter
- Terraform
- Git & GitHub

### One important point

I've marked **Stage 2 as "In Progress"**, not complete, because we haven't actually performed the right-sizing yet. That's important for keeping the GitHub project technically honest.
