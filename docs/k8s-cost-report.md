Stage 1 --- Baseline Waste Analysis
Environment
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
Baseline Resource Configuration
Each application pod requested:
- CPU: 250m
- Memory: 256Mi
Each application pod had limits:
- CPU: 500m
- Memory: 512Mi
For 4 replicas, total application requests were:
- CPU: 1000m
- Memory: 1024Mi
Observed Application Usage
During the controlled load test, application pods showed approximately:
- CPU: 14--22m per pod
- Memory: 3Mi per pod
Combined application usage was approximately:
- CPU: 69--79m
- Memory: 12Mi
Compared with the configured requests, this represented approximately:
- CPU request utilization: 7--8%
- Memory request utilization: ~1.2%
Therefore, the workload was significantly over-requested under this
controlled benchmark.
Note: kubectl top provides sampled/rounded metrics. These
measurements should not be interpreted as exact zero usage or as
production-safe right-sizing values. Additional representative
measurements are required before applying final requests/limits.
Node Utilization During Load Test
During the controlled load test:
- Node 1: approximately 39% CPU / 55% memory
- Node 2: approximately 11% CPU / 54% memory
The results show that CPU had substantial spare capacity, while memory
utilization was comparatively higher because of Kubernetes system
components and workload placement.
Scaling Baseline
The deployment remained fixed at 4 replicas.
No Horizontal Pod Autoscaler or node autoscaling mechanism was
configured.
Therefore:
- Replicas did not automatically scale with demand.
- Worker capacity remained fixed at 2 nodes.
- Off-peak capacity could not automatically scale down.
- Peak demand could not automatically increase application replicas or
  worker capacity.
Reliability Baseline
At the end of the baseline test:
- Application replicas available: 4/4
- Application pod restarts: 0
- Application pod status: Running
- Kubernetes system components: Healthy
The baseline therefore provides a stable reliability reference for
subsequent optimization stages.
Cost Optimization Findings
The baseline demonstrates significant potential resource-request waste,
particularly CPU.
The application requested 1000m CPU while the controlled workload
consumed approximately 69--79m CPU.
This excessive reservation can reduce Kubernetes bin-packing efficiency
because the scheduler places pods according to their resource requests
rather than their instantaneous CPU consumption.
The next optimization stage will use measured workload behavior to
reduce requests/limits while maintaining reliability and avoiding
OOMKills or performance degradation.
Baseline Infrastructure Condition
The benchmark started with:
- 2 × t3.small On-Demand worker nodes
- Fixed desired/min/max node count of 2
- 4 application replicas
- No pod autoscaling
- No node autoscaling
- No Spot capacity
Exact AWS billing cost will be captured separately using the AWS
billing/cost data under controlled benchmark conditions rather than
estimated from assumptions.
Stage 2 --- Right-Sizing
Status: Complete
Objective
Reduce unnecessary CPU and memory resource reservations based on the
measured behavior of the controlled workload while maintaining
application reliability.
Measured Workload
Additional controlled measurements were collected before applying the
new resource configuration.
The four application pods showed approximately:
- CPU: 12--22m per pod across repeated samples
- Combined CPU: approximately 65--81m
- Memory: approximately 3Mi per pod
- Combined memory: approximately 12Mi
These measurements were used to determine a smaller resource allocation
with safety headroom for the controlled NGINX benchmark.
Right-Sized Resource Configuration
The application resource configuration was changed from:
  Resource           Baseline   Right-Sized
  CPU Request            250m           50m
  Memory Request        256Mi          32Mi
  CPU Limit              500m          200m
  Memory Limit          512Mi          64Mi
For 4 replicas, the total requested resources changed from:
  Resource           Baseline   Right-Sized
  CPU Request           1000m          200m
  Memory Request       1024Mi         128Mi
This represents an 80% reduction in both CPU and memory resource
requests for the application workload.
Important: The 80% reduction applies to Kubernetes resource requests
for the application pods. It does not represent an 80% reduction in
AWS infrastructure cost because the cluster continued to run two
worker nodes during this stage.
Deployment
The right-sized workload was applied using the updated Kubernetes
deployment manifest.
The deployment continued running four application replicas.
The rollout completed successfully without deployment availability
issues.
Sustained-Load Validation
The right-sized workload was validated using the controlled
load-generator workload.
Observed results included:
- Application replicas: 4/4 available
- Application pod status: Running
- Application pod restarts: 0
- OOMKills observed: 0
- Combined application CPU usage: approximately 65--81m during sampled
  load
- Combined application memory usage: approximately 12Mi
- Worker nodes remained available and schedulable
The validation indicates that the reduced resource requests and limits
were sufficient for the controlled NGINX benchmark.
Reliability Result
The right-sizing change did not introduce observed workload instability
during the controlled test.
The workload maintained:
- 4/4 application replicas
- 0 pod restarts
- No observed OOMKills
- Successful deployment rollout
- Stable node availability
Bin-Packing Experiment
After right-sizing, the application resource requests were sufficiently
reduced to investigate whether the four application replicas could be
concentrated onto a single worker node.
The two worker nodes had approximately:
- Allocatable CPU: 1930m per node
- Allocatable memory: approximately 1468Mi per node
The application itself requested only:
- CPU: 200m total
- Memory: 128Mi total
A controlled scheduling test was performed by temporarily constraining
the application workload to one worker node.
Bin-Packing Result
The single-node placement test was not feasible under the current EKS
configuration.
When the deployment was constrained to one worker node:
- Existing replicas remained on their original nodes during the
  rolling update.
- Two replacement replicas became Pending.
- The constrained node could not accommodate the complete replacement
  workload together with the existing Kubernetes system workloads and
  scheduling requirements.
- The deployment exceeded its progress deadline.
The scheduling constraint was subsequently removed and the deployment
was successfully restored to its normal configuration.
Bin-Packing Conclusion
The test demonstrates that right-sizing improved the application's
resource-request efficiency, but the current two-node EKS configuration
cannot safely be reduced to one worker node based on this experiment
alone.
Therefore, the project does not claim a node-count reduction during
Stage 2.
Instead, the result establishes an infrastructure constraint that will
be addressed through dynamic node autoscaling in the later optimization
stage.
Right-Sizing Risks
The selected values are based on the controlled NGINX benchmark and
should not automatically be applied to an unrelated production workload.
Potential risks include:
- Higher-than-observed production traffic
- CPU bursts above the measured workload
- Memory growth over time
- Increased concurrency
- Different application behavior
- OOMKills if memory limits are too low
- CPU throttling if CPU limits are too restrictive
For production workloads, resource recommendations should be based on
representative historical usage and monitored over an appropriate
period.
Stage 2 Conclusion
Stage 2 successfully reduced unnecessary Kubernetes resource
reservations while maintaining workload reliability during the
controlled benchmark.
The application resource requests were reduced by 80% for both CPU and
memory without observed OOMKills or pod restarts.
The bin-packing experiment demonstrated that the application could not
safely be consolidated onto one worker node under the current EKS
system-workload and capacity constraints.
The optimized resource configuration establishes the foundation for
workload and node autoscaling.
Stage 3 --- Pod and Node Autoscaling
Status: Complete
Objective
Introduce automatic workload and node scaling so that application
capacity increases during demand and unnecessary worker capacity is
removed during low-demand periods.
Stage 3 implemented:
- Horizontal Pod Autoscaler (HPA)
- VPA evaluation/recommendation approach
- Cluster Autoscaler for worker-node scaling
HPA Configuration
The application was configured with an HPA using the Kubernetes
autoscaling/v2 API.
Configuration:
  Setting                                  Value
  Target Deployment            cost-baseline-app
  Minimum replicas                             2
  Maximum replicas                             6
  CPU target                                 60%
  Scale-up stabilization               0 seconds
  Scale-down stabilization            60 seconds
The HPA was configured to scale the application based on CPU utilization
relative to the right-sized CPU requests.
HPA Scale-Out Evidence
A controlled load test was used to increase application CPU demand.
The HPA successfully increased application capacity:
3 replicas → 5 replicas
Observed HPA output included:
NAME                REFERENCE                      TARGETS       MINPODS   MAXPODS   REPLICAS
cost-baseline-hpa   Deployment/cost-baseline-app   cpu: 52%/60%   2         6         5
The workload therefore demonstrated automatic pod scale-out when demand
increased.
HPA Scale-In Evidence
During the lower-demand phase, the HPA reduced application replicas.
An earlier controlled observation showed:
cpu: 54%/60%   REPLICAS: 3
The workload therefore demonstrated both HPA scale-out and scale-in
behavior rather than remaining permanently at peak replica capacity.
VPA Evaluation
Vertical Pod Autoscaler was evaluated as part of the autoscaling design.
The EKS cluster did not have the VPA CustomResourceDefinition installed,
so VPA was not enabled as an automatic controller.
For this project, VPA is treated as a recommendation-based future
optimization mechanism rather than an automatic scaling mechanism.
Recommended operating model:
- Use VPA in recommendation/Off mode to analyze historical resource
  usage.
- Review recommendations before applying new requests and limits.
- Avoid automatically changing requests while HPA is simultaneously
  using CPU utilization based on those requests.
- Apply validated recommendations through controlled deployment
  changes.
This approach avoids introducing competing automatic resource
adjustments between HPA and VPA.
Cluster Autoscaler
Cluster Autoscaler was selected instead of Karpenter for the
node-autoscaling implementation.
The EKS managed node group was configured with:
- Node group: baseline-workers
- Initial desired nodes: 2
- Minimum nodes: 2
- Maximum nodes: 4
- Instance type: t3.small
- Capacity type: On-Demand
Cluster Autoscaler was installed using Helm with AWS autodiscovery for
the eks-cost-optimization cluster.
An IAM OIDC provider and dedicated IAM service account were configured
to allow Cluster Autoscaler to interact with the AWS Auto Scaling API.
Cluster Autoscaler Scale-Out Evidence
Under increased workload and scheduling pressure, the worker-node count
increased automatically.
Observed node state changed from:
2 nodes → 3 nodes
The third EKS worker node successfully joined the cluster and reached
Ready status.
Example observed state:
NAME                                            STATUS
ip-192-168-28-222.ap-south-1.compute.internal   Ready
ip-192-168-53-200.ap-south-1.compute.internal   Ready
<new worker node>                               Ready
This demonstrates that Cluster Autoscaler successfully provisioned
additional worker capacity when the existing capacity was insufficient.
Cluster Autoscaler Scale-In Evidence
After the controlled load was removed and the application workload was
returned to the lower-demand state, the additional worker capacity was
no longer required.
The cluster automatically returned to:
3 nodes → 2 nodes
Observed final node state:
NAME                                            STATUS
ip-192-168-28-222.ap-south-1.compute.internal   Ready
ip-192-168-53-200.ap-south-1.compute.internal   Ready
This demonstrates automatic node scale-down during reduced demand.
Autoscaling Behavior Summary
  Optimization         Scale-Out                 Scale-In        Result
  HPA                  3 → 5 pods                4 → 3 pods      Complete
  Cluster Autoscaler   2 → 3 nodes               3 → 2 nodes     Complete
  VPA                  Recommendation approach   Not automatic   Evaluated
The cluster therefore demonstrated the intended pattern:
- Off-peak: fewer replicas and 2 worker nodes
- Peak: more application replicas and 3 worker nodes
Reliability During Autoscaling
The autoscaling tests were performed using the controlled NGINX
workload.
Observed reliability characteristics during the implemented stages
included:
- Application pods remained schedulable.
- HPA successfully created additional replicas.
- Additional worker capacity joined the cluster successfully.
- Worker nodes reached Ready status.
- Node capacity was removed after the workload decreased.
- No OOMKills were observed during the right-sizing validation.
- No application restart issue was observed during the controlled
  autoscaling workflow.
The benchmark was controlled and does not represent production traffic
or a production availability guarantee.
Cost Optimization Impact
The combination of right-sizing and autoscaling improves cost efficiency
in two separate ways.
Right-sizing reduces the amount of CPU and memory capacity reserved by
each application pod. This gives the Kubernetes scheduler more
flexibility to place workloads efficiently.
HPA prevents the application from permanently running peak replica
counts when demand is low.
Cluster Autoscaler prevents the cluster from permanently running peak
worker capacity when workloads do not require it.
Together:
Right-sizing → better bin-packing → less reserved capacity
HPA → fewer pods during low demand
Cluster Autoscaler → fewer worker nodes during low demand
This reduces infrastructure waste while retaining the ability to scale
when demand increases.
Stage 3 Conclusion
Stage 3 successfully implemented and demonstrated pod and node
autoscaling.
The HPA scaled the application from 3 to 5 replicas during increased
demand and demonstrated scale-in during reduced demand.
Cluster Autoscaler scaled worker capacity from 2 to 3 nodes during
increased scheduling pressure and subsequently reduced the cluster from
3 to 2 nodes when the additional capacity was no longer required.
VPA was evaluated and intentionally not enabled in automatic update mode
because the project already uses HPA and resource-request-based CPU
scaling.
Stage 3 therefore establishes automatic demand-based scaling while
maintaining the right-sized resource configuration from Stage 2.
Stage 4 --- Spot Capacity
Status: Complete
Objective
Use Amazon EC2 Spot capacity for suitable, non-critical workloads while
retaining On-Demand capacity as the baseline for critical and fallback
workloads.
Stage 4 implemented:
- Dedicated Spot managed node group
- Spot-preferred workload scheduling
- AWS Node Termination Handler for interruption handling
- Graceful node drain and pod rescheduling
- Spot versus On-Demand price comparison
Spot Node Group
A dedicated managed node group named spot-workers was created with
Spot capacity.
Configuration:
  Setting                                            Value
  Node group                                  spot-workers
  Capacity type                                       Spot
  Requested nodes                                        1
  Minimum nodes                                          1
  Maximum nodes                                          2
  Candidate instance types             t3.small, t3a.small
  Actual provisioned instance type               t3a.small
  Region                                        ap-south-1
The existing baseline-workers node group remained On-Demand.
This creates a mixed-capacity cluster in which critical baseline
capacity remains available while suitable workloads can use lower-cost
Spot capacity.
Spot Workload
A separate spot-demo-app Deployment was created in the cost-baseline
namespace.
Configuration:
  Setting                               Value
  Replicas                                  2
  Image                     nginx:1.27-alpine
  CPU request                             50m
  Memory request                         32Mi
  CPU limit                              200m
  Memory limit                           64Mi
  Scheduling preference     Prefer Spot nodes
The workload uses Kubernetes node affinity to prefer nodes with:
eks.amazonaws.com/capacityType=SPOT
The affinity is preferred rather than required so that the workload can
fall back to On-Demand capacity if Spot capacity becomes unavailable.
Spot Placement Evidence
After deployment, both spot-demo-app replicas were running on the Spot
node:
ip-192-168-66-199.ap-south-1.compute.internal
The node was identified as:
- Capacity type: SPOT
- Instance type: t3a.small
At the same time, the existing cost-baseline-app workload continued
running on the On-Demand worker nodes.
This demonstrated successful workload separation between Spot and
On-Demand capacity.
On-Demand Baseline
The following capacity remained On-Demand:
- baseline-workers managed node group
- Critical Kubernetes/system capacity
- Fallback capacity for the Spot-eligible application
The project intentionally did not move all workloads to Spot because
critical or interruption-sensitive workloads should retain reliable
On-Demand capacity.
Spot Interruption Handling
AWS Node Termination Handler was installed using the AWS EKS Helm chart.
Configuration included:
- Spot interruption draining enabled
- Rebalance monitoring enabled
- Scheduled event draining enabled
- IMDS mode
Installed versions:
- Chart version: 0.21.0
- Application version: 1.19.0
- Image: public.ecr.aws/aws-ec2/aws-node-termination-handler:v1.19.0
The handler provides graceful node draining when an interruption event
is detected, allowing Kubernetes workloads to be evicted and
rescheduled.
Spot Interruption / Drain Test
A controlled interruption scenario was simulated by draining the Spot
node:
ip-192-168-66-199.ap-south-1.compute.internal
The node was successfully:
1. Cordoned
2. Drained
3. Application pods gracefully evicted
4. Application pods rescheduled onto On-Demand nodes
Both spot-demo-app replicas were successfully rescheduled.
Final rescheduled placement:
- Replica 1 → On-Demand t3.small
- Replica 2 → On-Demand t3.small
Both replicas reported:
- 1/1 Running
- 0 restarts
This demonstrates that the Spot workload survived the controlled
node-drain event and automatically recovered on available On-Demand
capacity.
The test validates the intended resilience mechanism: Spot capacity is
preferred for the workload, while On-Demand capacity provides a fallback
when Spot capacity is interrupted.
Note: The interruption test used a controlled Kubernetes node drain
rather than an actual AWS Spot interruption event. AWS Node
Termination Handler was installed to provide the production-style
interruption/drain mechanism. The test demonstrates pod eviction and
rescheduling behavior; a continuous external request probe was not
used, so the report does not claim a measured zero-second service
interruption.
Spot Price Evidence
AWS EC2 Spot price history was queried for the actual t3a.small
instance type in ap-south-1.
Observed Spot prices included:
  Availability Zone     Spot Price / hour
  ap-south-1c                    $0.0055
  ap-south-1a                    $0.0067
  ap-south-1b                    $0.0061
The latest observed price in the captured output was:
$0.0055/hour
At this observed rate, one Spot t3a.small would cost approximately:
- Hourly: $0.0055
- 730 hours: approximately $4.02/month
For comparison, AWS provides On-Demand EC2 pricing through its EC2
On-Demand pricing page and Price List APIs. The exact On-Demand price
used for a final billing calculation should be captured from the same
region, operating system, and pricing source at report-finalization
time.
Using the previously captured benchmark comparison of approximately
$0.0123/hour for On-Demand t3a.small, the observed $0.0055/hour Spot
price represents approximately:
55.3% compute-price savings
Approximate monthly comparison at 730 hours:
  Capacity                Approx. hourly   Approx. monthly
  On-Demand t3a.small           $0.0123            $8.98
  Spot t3a.small                $0.0055            $4.02
  Approx. saving                $0.0068            $4.96
  Approx. saving %                 55.3%             55.3%
Cost note: These figures represent EC2 instance compute pricing only.
They do not include EBS, networking, load balancer, control-plane,
monitoring, or other AWS service charges. Spot prices also vary by
Availability Zone and over time.
Spot Reliability Result
The controlled Spot drain test demonstrated:
- Spot workload successfully scheduled
- Spot node successfully drained
- Spot application pods gracefully evicted
- Pods automatically recreated by the Deployment controller
- Pods successfully rescheduled onto On-Demand nodes
- Both replacement pods reached 1/1 Running
- No pod restarts were reported on the replacement pods
- On-Demand baseline capacity remained available
This establishes a resilient mixed-capacity design for
interruption-tolerant workloads.
Workload Placement Policy
Workloads suitable for Spot should generally be:
- Stateless
- Horizontally scalable
- Fault tolerant
- Able to tolerate node interruption
- Backed by multiple replicas or another recovery mechanism
Examples include:
- Stateless web/API replicas
- Batch processing
- CI/CD workers
- Distributed background workers
- Non-critical development/test workloads
Workloads retained on On-Demand should include:
- Critical services that cannot tolerate interruption
- Stateful workloads requiring stable capacity
- Components without sufficient redundancy
- Workloads with strict availability requirements
The project keeps the baseline worker capacity On-Demand and uses Spot
for the dedicated demonstration workload.
Stage 4 Cost Optimization Impact
Stage 4 adds another cost-optimization layer on top of the Stage 2 and
Stage 3 improvements.
The combined strategy is:
Right-sizing → lower pod resource reservations
HPA → fewer application replicas during low demand
Cluster Autoscaler → fewer worker nodes when capacity is not required
Spot → lower compute price for interruption-tolerant capacity
Together, these mechanisms reduce both resource waste and the price paid
for suitable compute capacity while preserving an On-Demand fallback.
Stage 4 Conclusion
Stage 4 successfully implemented and demonstrated Spot capacity for a
suitable workload.
A dedicated Spot managed node group was created and an application
workload was successfully scheduled onto the Spot t3a.small node.
AWS Node Termination Handler was installed for graceful interruption
handling.
A controlled Spot-node drain successfully evicted both application
replicas and demonstrated automatic rescheduling onto the existing
On-Demand worker nodes, with both replacement pods reaching
1/1 Running and reporting zero restarts.
The captured Spot price history showed approximately
$0.0055--$0.0067/hour for t3a.small during the observed period.
Using the previously captured On-Demand comparison of approximately
$0.0123/hour, the observed Spot price represented approximately 55.3%
compute-price savings.
Critical baseline capacity remains On-Demand, while the
interruption-tolerant workload uses Spot with On-Demand fallback.
Stage 5 --- Cost and Reliability Measurement
Status: Complete
Objective
Measure the cost and reliability impact of the completed optimization
strategy, add cost visibility by namespace/workload, and detect resource
request regressions that could increase infrastructure waste.
Stage 5 implemented:
- OpenCost cost visibility for namespace and workload allocation
- Prometheus metrics integration
- Cost regression detection for Kubernetes resource requests
- Deliberate regression test and alarm trigger
- Final Spot versus On-Demand compute-cost comparison
- Reliability and cost trade-off assessment
- Final Kubernetes cost-optimization report
Cost Visibility
OpenCost was installed in the cluster and integrated with Prometheus.
The monitoring components used for the controlled benchmark were:
- Prometheus namespace: prometheus-system
- OpenCost namespace: opencost
- OpenCost API port: 9003
- Cost allocation dimensions tested:
  - Namespace
  - Workload
Prometheus was configured without persistent storage for this controlled
assignment benchmark. This keeps the test environment lightweight; it is not
intended to represent a production-grade long-term monitoring configuration.
OpenCost Namespace Cost Snapshot
A controlled OpenCost allocation query was used to obtain namespace-level
resource and cost information.
The captured sample showed:
- cost-baseline namespace:
  - CPU request: approximately 0.20 cores
  - CPU usage: approximately 0 cores during the sampled window
  - CPU cost: approximately $0.00053
  - Memory request: approximately 128 MiB
  - Memory usage: approximately 12.3 MiB
  - Memory cost: approximately $0.00004
  - Total sampled allocation: approximately $0.00057
- kube-system:
  - CPU request: approximately 0.85 cores
  - CPU usage: approximately 0.004 cores
  - CPU cost: approximately $0.00224
  - Memory request: approximately 540 MiB
  - Memory usage: approximately 332 MiB
  - Total sampled allocation: approximately $0.00243
- opencost:
  - CPU request: approximately 0.02 cores
  - CPU usage: approximately 0.00012 cores
  - CPU cost: approximately $0.00005
  - Memory request: approximately 110 MiB
  - Memory usage: approximately 53 MiB
  - Total sampled allocation: approximately $0.00009
The OpenCost values are short-window allocation estimates rather than the
actual AWS invoice. They are used for cost visibility and comparison of
resource allocation, not as a replacement for AWS billing data.
Cost Regression Alarm
A repository-level regression check was added:
docs/cost-regression-check.ps1
The check compares the deployment's current CPU request against the
optimized baseline.
Configured values:
- Expected optimized CPU request: 50m per pod
- Regression threshold: 75m per pod
- Regression test value: 100m per pod
The check reports an ALERT when the CPU request exceeds the configured
threshold. This is intended to detect resource-request creep because higher
requests can reduce bin-packing efficiency and increase the number of worker
nodes required.
Deliberate Regression Test
The regression alarm was deliberately triggered by increasing the
application CPU request:
- Optimized request: 50m per pod
- Deliberately increased request: 100m per pod
- Replicas during test: 2
- Total requested CPU during regression: 200m
- Regression threshold: 75m
The alarm correctly reported:
ALERT: CPU request regression detected!
Current request 100m exceeds threshold 75m.
This demonstrates that the repository contains an executable regression
control rather than only a documentation-based warning.
The deployment was subsequently restored to the optimized 50m CPU request.
Final Resource Efficiency
The completed optimization reduced the application resource reservations
substantially.
For the original four-replica workload:
Resource              Baseline       Right-Sized       Reduction
CPU request           1000m          200m              80%
Memory request        1024Mi         128Mi             87.5%
The CPU and memory reductions describe Kubernetes resource-request efficiency.
They must not be interpreted as the same percentage reduction in the complete
AWS bill because the EKS worker nodes and Kubernetes system workloads still
consume infrastructure capacity.
Autoscaling Cost Behavior
The completed autoscaling configuration demonstrated:
- HPA:
  - Minimum replicas: 2
  - Maximum replicas: 6
  - CPU target: 60%
  - Scale-out observed: 3 -> 5 replicas
  - Scale-in observed: 4 -> 3 replicas
- Cluster Autoscaler:
  - Minimum nodes: 2
  - Maximum nodes: 4
  - Scale-out observed: 2 -> 3 nodes
  - Scale-in observed: 3 -> 2 nodes
This establishes the intended cost behavior:
- Lower demand -> fewer application replicas
- Higher demand -> additional application replicas
- Lower node demand -> worker-node scale-in
- Higher scheduling demand -> worker-node scale-out
The experiment did not claim a permanent one-node cluster because the Stage 2
bin-packing test showed that one worker could not safely accommodate the
application together with the existing EKS system workloads.
Spot Cost Comparison
The final Spot comparison uses the captured AWS pricing data.
Captured On-Demand pricing:
- t3.small in ap-south-1: $0.0224/hour
- t3a.small in ap-south-1: $0.0123/hour
Captured t3a.small Spot prices during the test window included:
- ap-south-1c: $0.0055/hour
- ap-south-1a: $0.0067/hour
- ap-south-1b: $0.0061/hour
Latest observed Spot price:
- t3a.small Spot: $0.0055/hour
Equivalent three-node peak-capacity comparison:
Baseline peak capacity:
- 3 x t3.small On-Demand
- 3 x $0.0224/hour
- Total: $0.0672/hour
Optimized mixed-capacity peak:
- 2 x t3.small On-Demand
- 1 x t3a.small Spot at the latest observed price
- 2 x $0.0224 + $0.0055
- Total: $0.0503/hour
Observed compute-cost difference:
- Saving: $0.0169/hour
- Approximate saving: 25.1%
At 730 hours, if the same capacity and Spot price were maintained:
- Three t3.small On-Demand: approximately $49.06/month
- Two t3.small On-Demand + one t3a.small Spot: approximately $36.72/month
- Approximate difference: $12.34/month
This is an equivalent peak-capacity compute comparison, not a claim that the
entire AWS bill decreased by 25.1%.
Spot prices fluctuate by time and Availability Zone. Actual AWS charges also
include other services and resources such as EBS, networking, load
balancers, monitoring, and other applicable charges.
Off-Peak Cost Behavior
The tested cluster retained two On-Demand baseline workers during the
off-peak state.
This was intentional.
The Stage 2 single-node bin-packing experiment showed that safely reducing
the cluster to one worker was not feasible under the tested EKS system
workload and capacity constraints.
Therefore, this project does not claim a permanent off-peak one-node
configuration.
Instead, the cost strategy is:
Right-sizing -> reduce reserved application resources
HPA -> reduce unnecessary application replicas
Cluster Autoscaler -> remove unnecessary worker nodes when safe
Spot -> reduce compute price for suitable interruption-tolerant capacity
On-Demand -> retain reliable baseline and fallback capacity
Reliability Assessment
Reliability remained acceptable throughout the controlled optimization
workflow.
Observed results included:
- Stage 1 baseline: 4/4 application replicas available
- Stage 1 baseline: 0 application pod restarts
- Stage 2 right-sizing: 4/4 replicas available
- Stage 2 right-sizing: 0 pod restarts
- Stage 2 right-sizing: 0 observed OOMKills
- Stage 3 HPA: successful scale-out and scale-in
- Stage 3 Cluster Autoscaler: successful node scale-out and scale-in
- Stage 4 Spot: Spot workload scheduled successfully
- Stage 4 Spot drain: pods evicted and recreated successfully
- Stage 4 Spot fallback: both replicas reached 1/1 Running on On-Demand
  nodes
- Stage 4 replacement pods: 0 restarts reported
The Spot interruption experiment used a controlled Kubernetes node drain
rather than a real AWS Spot interruption event. Therefore, the project
demonstrates rescheduling resilience but does not claim a measured
zero-second production outage.
Cost / Reliability Trade-offs
The project deliberately accepted the following trade-offs:
1. Aggressive right-sizing was limited to the controlled NGINX benchmark.
   The 50m CPU / 32Mi memory requests provide measured headroom for this
   test workload, but they should not be copied directly to an unrelated
   production application.
2. One-node consolidation was rejected.
   Although the application requests were small enough in isolation, the
   complete worker node also had to support Kubernetes system workloads.
   The test showed that forcing all replicas onto one node was not safe.
3. VPA was not enabled in automatic update mode.
   VPA recommendations can be useful, but automatically changing resource
   requests while HPA is using CPU utilization based on those requests can
   create competing scaling behavior. Recommendation-based VPA is therefore
   preferred for this project.
4. Critical capacity remained On-Demand.
   Spot was used only for a workload that could tolerate interruption and
   had a Deployment controller plus On-Demand fallback.
5. Prometheus persistence was not enabled.
   The monitoring stack was intentionally lightweight for the controlled
   assignment. A production implementation should use persistent monitoring
   and alerting infrastructure.
Hardest Workload to Optimise Safely
The hardest workload to optimize safely in this project was the primary
application deployment when considering node consolidation rather than only
pod requests.
The application itself used very little CPU and memory after right-sizing,
but the worker node also had to accommodate:
- Kubernetes system components
- Networking components
- DNS
- Metrics infrastructure
- Autoscaling components
- Other cluster-level workloads
The single-node bin-packing experiment caused replacement replicas to remain
Pending and the deployment exceeded its progress deadline.
Therefore, the project drew the line at one worker node and retained a
two-node On-Demand baseline.
Final Before / After Summary
Aspect                     Baseline                  Optimized
Worker baseline            2 x t3.small OD           2 x t3.small OD
Peak tested workers        Fixed 2                    Up to 3 with CA
Application replicas       Fixed 4                    HPA 2-6
CPU request/pod            250m                       50m
Memory request/pod         256Mi                      32Mi
CPU request reduction      --                         80%
Memory request reduction   --                         87.5%
HPA                        None                       Enabled
Cluster Autoscaler         None                       Enabled
VPA                        None                       Recommendation-only
Spot                       None                       Dedicated Spot group
Cost visibility            None                       OpenCost
Regression alarm           None                       PowerShell check
Spot interruption handling None                       AWS NTH + fallback
Observed OOMKills          0                          0
Observed app restarts      0                          0
Overall Cost Result
The optimization produced three distinct cost-efficiency improvements:
1. Resource-request efficiency
   Application CPU requests were reduced by 80% and memory requests by 87.5%,
   giving the scheduler substantially more flexibility for bin-packing.
2. Elastic capacity
   HPA and Cluster Autoscaler demonstrated that application and worker
   capacity can scale down during lower demand instead of remaining
   permanently at the tested peak state.
3. Lower-cost capacity
   The tested Spot configuration reduced the equivalent three-node peak
   compute price from approximately $0.0672/hour to $0.0503/hour at the
   latest observed Spot price, a modeled saving of approximately 25.1% for
   that peak-capacity comparison.
The project does not claim a single percentage reduction for the entire AWS
invoice because the benchmark did not use a finalized AWS billing-period
before/after invoice comparison. The measured figures above are therefore
reported as resource-efficiency improvements, autoscaling behavior, and
equivalent-capacity compute savings.
Final Conclusion
The Kubernetes cost-optimization project is complete.
The final architecture combines:
Right-sizing
    ->
Better bin-packing
    ->
HPA pod autoscaling
    ->
Cluster Autoscaler node scaling
    ->
Spot capacity for suitable workloads
    ->
OpenCost cost visibility
    ->
Resource-request regression detection
The optimization maintained the tested workload's reliability while
reducing unnecessary Kubernetes resource reservations and demonstrating
elastic worker capacity and lower-cost Spot compute.
The main safety boundary established by the project is that cost reduction
must not be achieved by blindly shrinking resources or removing required
baseline capacity. Resource changes must be based on measured usage, node
capacity must include system workloads, critical services should retain
On-Demand capacity, and Spot workloads must have a recovery path.
Stage 5 therefore completes the measurement, cost-visibility, regression
detection, and final reporting requirements for the Kubernetes cost
optimization assignment.
Final Cleanup
After final review and evidence capture, temporary benchmark resources
should be removed to avoid unnecessary AWS charges.
Cleanup should include:
- Spot demonstration workload
- Load-generator pods
- OpenCost
- Prometheus
- Cluster Autoscaler
- AWS Node Termination Handler
- Spot node group
- EKS cluster
The final cleanup should be performed only after all required screenshots,
logs, and report evidence have been captured