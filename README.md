# sce-l4s-bakeoff

This repo contains a [Flent](https://flent.org/) batch with lab tests designed
to compare [SCE](https://github.com/chromi/sce/) and
[L4S](https://riteproject.eu/dctth/).

In deference to [RFC 5033](https://tools.ietf.org/html/rfc5033), as it refers
to the evalution of congestion control proposals:

> The high-order criteria for any new proposal is that a serious scientific
> study of the pros and cons of the proposal needs to have been done such that
> the IETF has a well- rounded set of information to consider.

We admit that we have quite a ways to go to thoroughly test the current high
fidelity congestion signaling proposals against all of the considerations
mentioned in the literature, and that these tests are but a start.


## Table of Contents

1. [Test Setup](#test-setup)
2. [Test Output](#test-output)
3. [Scenarios and Results](#scenarios-and-results)
   1. [Scenario 1](#scenario-1)
   2. [Scenario 2](#scenario-2)
   3. [Scenario 3](#scenario-3)
   4. [Scenario 4](#scenario-4)
   5. [Scenario 5](#scenario-5)
   6. [Scenario 6](#scenario-6)
4. [L4S CoDel Interaction](#l4s-codel-interaction)
5. [Installation](#installation)
   1. [Kernels](#kernels)
   2. [Flent](#flent)
   3. [Supporting Files](#supporting-files)
6. [Future Work](#future-work)


## Test Setup

The test setup consists of two endpoints (one C and one S) and four middleboxes
(M1-M4). Each node is configured with one interface for management (not shown)
plus one (for C and S nodes) or two (for M nodes) for testing, connected as
follows:

```
C1 -|                     |- S1
    |- M1 - M2 - M3 - M4 -|
C2 -|                     |- S2
```

The test is run separately for SCE and L4S, and all configuration changes needed
for the different test scenarios are made automatically. SCE tests are run from
C1 to S1, and L4S tests from C2 to S2. The kernels, software and sysctl settings
on each node are below. The non-standard pacing parameters of `ca_ratio=40` and
`ss_ratio=100` have been shown to avoid overshoot in SCE testing, so we use them
for L4S as well so that results can more directly be compared.

- C1 (SCE):
  - role: client / sender
  - kernel: [SCE](https://github.com/chromi/sce/)
  - software: flent, netperf, fping
  - sysctl: `net.ipv4.tcp_ecn = 1`
  - sysctl: `net.ipv4.tcp_pacing_ca_ratio = 40`
  - sysctl: `net.ipv4.tcp_pacing_ss_ratio = 100`
- C2 (L4S):
  - role: client / sender
  - kernel: [L4S](https://github.com/L4STeam/linux)
  - software: flent, netperf, fping
  - sysctl: `net.ipv4.tcp_ecn = 3`
  - sysctl: `net.ipv4.tcp_pacing_ca_ratio = 40`
  - sysctl: `net.ipv4.tcp_pacing_ss_ratio = 100`
- M1:
  - role: middlebox
  - kernel: [L4S](https://github.com/L4STeam/linux)
  - sysctl: `net.ipv4.ip_forward = 1`
- M2:
  - role: middlebox
  - kernel: [SCE](https://github.com/chromi/sce/)
  - sysctl: `net.ipv4.ip_forward = 1`
- M3:
  - role: middlebox
  - kernel: [L4S](https://github.com/L4STeam/linux)
  - sysctl: `net.ipv4.ip_forward = 1`
- M4:
  - role: middlebox
  - kernel: [SCE](https://github.com/chromi/sce/)
  - sysctl: `net.ipv4.ip_forward = 1`
- S1 (SCE):
  - role: server / receiver
  - kernel: [SCE](https://github.com/chromi/sce/)
  - software: netserver
  - sysctl: `net.ipv4.tcp_sce = 1`
- S2 (L4S):
  - role: server / receiver
  - kernel: [L4S](https://github.com/L4STeam/linux)
  - software: netserver
  - sysctl: `net.ipv4.tcp_ecn = 3`


## Test Output

The results for each scenario include the following files:

- `*_fixed.png`- throughput, ICMP RTT and TCP RTT plot with fixed RTT
  scale for visual comparison
- `*_var.png`- throughput, ICMP RTT and TCP RTT plot with variable RTT
  scale based on maximum value for showing outliers
- `*.debug.log.bz2`- debug log from Flent
- `*.flent.gz`- standard Flent output file, may be used to view original
  data or re-generate plots
- `*.log`- stdout and stderr from Flent
- `*.process.log`- output from post-processing commands like plotting
  and scetrace
- `*.setup.log`- commands and output for setting up each node (nodes that
  do not appear have their configurations set to default)
- `*.tcpdump_*.json`- output from running scetrace on the pcap file
- `*.tcpdump_*.log`- stdout and stderr from tcpdump
- `*.tcpdump_*.pcap.bz2`- pcap file compressed with `bzip2 -9`
- `*.teardown.log`- commands and output upon teardown of each node, after
  the test is run, including `tc` stats and output from `ip tcp_metrics`


## Scenarios and Results

The batch consists of numbered scenarios. The following definitions help
interpret the topology for each:

- L4S middlebox: uses `sch_dualpi2`
- SCE middlebox: uses `sch_cake` with the `sce` parameter
- FQ-AQM middlebox: uses `fq_codel`
- single-AQM middlebox: uses `fq_codel` with `flows 1`
- ECT(1) mangler: uses an iptables rule to set ECT(1) on
  all packets for the one-flow test, or all packets on one of the flows
  in the two-flow test
- FIFO middlebox: uses `pfifo_fast`

All bottlenecks restrict to 50Mbit, unless otherwise noted. Each scenario is
run first with one flow, then with two flow competition (with the second
flow beginning after 10 seconds), with the following variations:

- RTT delays of 0ms, 10ms and 80ms
- Different CC algorithms as appropriate

Full results obtained at the SCE Data Center in Portland are available
[here](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/).

Following are descriptions of the scenarios, with observations and links
to some relevant results obtained in Portland:

### Scenario 1

> This is simply a sanity check to make sure the tools worked.

L4S: Sender → L4S middlebox (bottleneck) → L4S Receiver

SCE: Sender → SCE middlebox (bottleneck) → SCE Receiver

#### Scenario 1 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-2/)

Observations:

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-1/batch-sce-s1-1-cubic-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-1/batch-l4s-s1-1-cubic-50Mbit-10ms_fixed.png), single Cubic flows at 10ms

  Cake maintains a lower ICMP and TCP RTT than dualpi2, likely due to the
  operation of Cake's COBALT (CoDel-like) AQM in comparison to PI. Note also
  that Cake's default target is 5ms, and PI's is 15ms.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-1/batch-sce-s1-1-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-1/batch-l4s-s1-1-prague-50Mbit-10ms_fixed.png), single Reno-SCE and Prague flows at 10ms

  TCP Prague, which uses dualpi2's L queue, maintains a slightly lower ICMP and
  TCP RTT than Reno-SCE. This is probably due to dualpi2 marking congestion at a
  lower queue depth than Cake, which starts marking at a default depth of 2.5ms.
  We expect that the earlier default marking for dualpi2 may lead to a higher
  drop in utilization with bursty flows, but this will be tested at a later
  time.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-1/batch-sce-s1-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-1/batch-l4s-s1-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE and Prague flows at 80ms

  Reno-SCE shows a faster ramp during slow start, because while NewReno growth
  is 1/cwnd segments per ack, Reno-SCE grows by 1/cwnd segments per acked
  segment, so about twice as fast as stock NewReno but still adhering to the
  definition of Reno-linear growth.

  For some reason, utilization for TCP Prague is about 25% below what's expected.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-2/batch-sce-s1-2-cubic-vs-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-cubic-50Mbit-80ms_fixed.png), Cubic vs Cubic at 80ms

  Cubic ramps up faster for dualpi2 than Cake because **TODO**..., but with a
  corresponding spike in TCP RTT. We can also see that although TCP RTT is
  higher for dualpi2 than Cake, the L4S ping, marked ECT(1), shows lower RTT
  as the only L queue occupant.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s1-2/batch-sce-s1-2-cubic-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-80ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 80ms

  As expected, without changes to the default SCE marking ramp, Reno-SCE is
  dominated by a Cubic flow in a single queue.

  Unexpectedly, Prague loses to Cubic in single queue competition at 80ms,
  although its TCP RTT is decidedly lower. Here we see different behaviors at
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-10ms_fixed.png) and [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-0ms_fixed.png),
  suggesting that single queue fairness is highly RTT dependent for TCP Prague.

### Scenario 2

> This is the most favourable-to-L4S topology that incorporates a non-L4S
> component that we could easily come up with.

L4S: Sender → FQ-AQM middlebox (bottleneck) → L4S middlebox → L4S receiver

SCE: Sender → FQ-AQM middlebox (bottleneck) → SCE middlebox → SCE receiver

#### Scenario 2 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-2/)

Observations:

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-1/batch-sce-s2-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/batch-l4s-s2-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  Since fq_codel is the bottleneck in this scenario, single Cubic flows show
  remarkably similar characteristics for both SCE and L4S.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-1/batch-sce-s2-1-dctcp-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/batch-l4s-s2-1-dctcp-50Mbit-80ms_fixed.png), single flow DCTCP-SCE or
  DCTCP at 80ms

  DCTCP-SCE shows a throughput sawtooth because DCTCP-SCE treats the CE marks
  from fq_codel as per [RFC 8511](https://tools.ietf.org/html/rfc8511), which
  is closer to the tradtional [RFC 3168](https://tools.ietf.org/html/rfc3168)
  response.

  In the L4S architecture, DCTCP does not show a sawtooth, because CE has been
  redefined as a fine-grained congestion signal, as allowed for experimentation
  by [RFC 8311](https://tools.ietf.org/html/rfc8311). Correspondingly, the
  increase in TCP RTT stays right around fq_codel's target of 5ms, as compared
  to DCTCP-SCE, whose TCP RTT increase only approaches 5ms as queue depths near
  the CE marking point.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-1/batch-sce-s2-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE and Prague flows at 80ms

  As expected, Reno-SCE shows a Reno-like throughput sawtooth, because SCE 
  marking is not occurring at the bottleneck.

  Although TCP Prague maintains higher utilization due to its DCTCP-like
  behavior and L4S style response to CE, there is a remarkable TCP RTT spike
  as the flow starts. The full extent of it is better seen in the
  [same plot with variable scaling](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_var.png).
  This is due to an interaction with CoDel that is further described in
  [L4S CoDel Interaction](#l4s-codel-interaction). In this case, the spike
  occurs for TCP RTT and not ICMP RTT because fq_codel's fair queueing and
  sparse flow optimization are keeping queue sojourn times low for the sparse
  ICMP flow.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-2/batch-sce-s2-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-2/batch-l4s-s2-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 10ms

  Consistent with earlier results, as the second flow is introduced
  (Reno-SCE for SCE and Prague for L4S), the TCP RTT spike described
  earlier (due to the [L4S CoDel Interaction](#l4s-codel-interaction))
  only occurs for TCP Prague.

### Scenario 3

> This is the topology of most concern, and is obtained from topology 2 by
> adding the `flows 1` parameter to fq_codel, making it a single queue AQM.

L4S: Sender → single-AQM middlebox (bottleneck) → L4S middlebox → L4S receiver

SCE: Sender → single-AQM middlebox (bottleneck) → SCE middlebox → SCE receiver

#### Scenario 3 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-2/)

Observations:

- [SCE FQ](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s2-1/batch-sce-s2-1-reno-sce-50Mbit-80ms_fixed.png) vs [SCE 1Q](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-1/batch-sce-s3-1-reno-sce-50Mbit-80ms_fixed.png) and
[L4S FQ](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_fixed.png) vs [L4S 1Q](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-1/batch-l4s-s3-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  As expected, for SCE, moving to a single queue makes the short spike in
  RTT equivalent for ICMP and TCP, as there is no longer fair queueing or
  sparse flow optimization.

  For L4S, the single queue means that the
  [L4S CoDel Interaction](#l4s-codel-interaction) affects all other flows
  sharing the same queue.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-2/batch-sce-s3-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-2/batch-l4s-s3-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 10ms

  For SCE, Reno-SCE's mean throughput is about 1.5x that of Cubic, due to the
  use of the ABE response to CE described in
  [RFC 8511](https://tools.ietf.org/html/rfc8511).

  For L4S, TCP Prague's mean throughput is about 4x that of Cubic, due to its
  assumption that the CE mark is coming from an L4S aware queue.

  This unfairness was hinted at in
  [RFC 3168 Section 5](https://tools.ietf.org/html/rfc3168#section-5), where
  it discusses the potential pitfall in treating CE differently than drop:

  > If there were different congestion control responses to a CE codepoint 
  > than to a packet drop, this could result in unfair treatment for
  > different flows.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-80ms_fixed.png), Reno-SCE vs Reno-SCE and Prague vs Prague at 80ms

  Reno-SCE vs Reno-SCE shows approximate throughput fairness in a single
  queue at an RTT delay of 80ms, as well as [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-0ms_fixed.png) and [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-10ms_fixed.png).

  TCP Prague vs TCP Prague shows unfairness in favor of the first flow to
  start. This also occurs at [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-0ms_fixed.png) and [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-10ms_fixed.png).

### Scenario 4

> This explores what happens if an adversary tries to game the system by
> forcing ECT(1) on all packets.

L4S: Sender → ECT(1) mangler → L4S middlebox (bottleneck) → L4S receiver

SCE: Sender → ECT(1) mangler → SCE middlebox (bottleneck) → SCE receiver

*Note:* in the two-flow results for this scenario, "gamed" flows are not
labelled as such in the plot legends. However, the order of the flows are
the same as listed in the title, and may also be inferred from their behavior.

#### Scenario 4 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-2/)

Observations:

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-1/batch-sce-s4-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  For SCE, Cubic is unaffected by setting ECT(1) on all packets.

  For L4S, setting ECT(1) on all packets places them in the L queue,
  causing a drop in utilization that increases as the RTT delay goes up
  (compare with
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-10ms_fixed.png) and [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-0ms_fixed.png)).

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-1/batch-sce-s4-1-dctcp-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/batch-l4s-s4-1-dctcp-50Mbit-80ms_fixed.png), single DCTCP-SCE or DCTCP flow at 80ms

  As expected, setting ECT(1) on all packets causes a collapse in throughput
  for DCTCP-SCE, as there is a cwnd reduction for each ACK, limited to a
  minimum cwnd of two segments (however, with the 40% CA scale factor for
  pacing, this is effectively 0.8 from a throughput standpoint).

  For L4S, setting ECT(1) on all packets causes a drop in utilization for
  DCTCP that's RTT dependent, similar to Cubic.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-1/batch-sce-s4-1-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-1/batch-l4s-s4-1-prague-50Mbit-10ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  We see the similar throughput collapse for SCE and utilization reduction
  for L4S.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s4-2/batch-sce-s4-2-cubic-vs-cubic_gamed-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s4-2/batch-l4s-s4-2-cubic-vs-cubic_gamed-50Mbit-80ms_fixed.png), Cubic vs Cubic "Gamed" at 80ms

  For SCE, Cubic is unaffected by the setting of ECT(1), so the result is
  the same as if there were no gaming.

  For L4S, the gamed flow sees a reduction in utilization that causes it to have
  lower throughput than the un-gamed flow. When the gamed flow starts, there is
  a short ~5ms spike in inter-flow RTT (ICMP RTT) for the L queue, probably due
  to an init cwnd burst of packets arriving.

### Scenario 5

> This is Sebastian Moeller's scenario. We had some discussion about the
> propensity of existing senders to produce line-rate bursts occasionally, and
> the way these bursts could collect in *all* of the queues at successively
> decreasing bottlenecks. This is a test which explores the effects of that
> scenario, and is relevant to best consumer practice on today's Internet.

L4S: Sender → L4S middlebox (bottleneck 1) → FIFO middlebox (bottleneck 2) → FQ-AQM middlebox (bottleneck 3) → L4S receiver

SCE: Sender → SCE middlebox (bottleneck 1) → FIFO middlebox (bottleneck 2) → FQ-AQM middlebox (bottleneck 3) → SCE receiver

#### Scenario 5 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-2/)

Observations:

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-1/batch-sce-s5-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/batch-l4s-s5-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  Both SCE and L4S see very similar latency spikes at flow startup, as the
  initial bottleneck (bottleneck 3) is the same.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-1/batch-sce-s5-1-reno-sce-50Mbit-0ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-0ms_fixed.png), single Reno-SCE or Prague flow at 10ms

  For SCE, we see a similar latency spike at flow startup as with Cubic.

  For L4S, but we also see a longer and higher spike in TCP RTT due to the
  [L4S CoDel Interaction](#l4s-codel-interaction), and a spike in ICMP RTT
  that probably occurs at the single FIFO queue in bottleneck 2.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-1/batch-sce-s5-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  While the initial latency spike for SCE is similar to the one at 10ms,
  the intra-flow and inter-flow spikes for L4S have multiplied in
  duration and magnitude (see Prague plots with variable RTT scale at
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-10ms_var.png) and [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-80ms_var.png)).

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-2/batch-sce-s5-2-cubic-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-2/batch-l4s-s5-2-cubic-vs-prague-50Mbit-80ms_fixed.png), Cubic vs Reno-SCE or Cubic vs Prague at 80ms

  For SCE, similar short latency spikes are seen on startup of each flow.

  For L4S, the longer latency spike upon startup of the Prague flow (due to
  the [L4S CoDel Interaction](#l4s-codel-interaction)) affects the Cubic
  flow and both ping flows as well.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s5-2/batch-sce-s5-2-reno-sce-vs-reno-sce-50Mbit-80ms_var.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s5-2/batch-l4s-s5-2-prague-vs-prague-50Mbit-80ms_var.png), Reno-SCE vs Reno-SCE or Prague vs Prague at 80ms, variable RTT scaling

  For SCE, the latency bursts on startup of each flow are short, but
  significant in magnitude.

  For L4S, the longer latency spikes due to the
  [L4S CoDel Interaction](#l4s-codel-interaction) are seen on startup of
  each flow. The following commentary from Jonathon Morton further
  describes what's going on:

  > The *magenta* trace (overlapping completely with the *violet* trace) is the
  > delay incurred at the FIFO.
  >
  > The *green* trace is the delay incurred in both queues by the first Prague
  > flow.  This is clearly greater during its own startup than during the second
  > one.  At a nearly constant marking rate by Codel, Prague would need an
  > increase in RTT to increase the number of marks per RTT to signal it to
  > reduce cwnd on average, to adapt to the newly halved share of capacity.  In
  > fact Codel is also increasing its marking rate during this time, and some
  > minor fluctuations in throughput on the *aqua* trace indicate the period in
  > which Codel is ramping back down to the correct marking rate.
  >
  > The *yellow* trace is the delay incurred in both queues by the *second*
  > Prague flow.  This appears to last about the same time as the first spike on
  > the *green* trace, but is about twice as tall.  The latter is a natural
  > consequence of a halved queue drain rate, noting that the first second of
  > the *orange* trace indicates briefly getting full link capacity; the peak
  > cwnd is apparently determined by the combination of this and the 200ms RTT
  > balance point of Codel's initial marking rate.

### Scenario 6

> This is similar to Scenario 5, but narrowed down to just the FIFO and CoDel
> combination.  Correct behaviour would show a brief latency peak caused by the
> interaction of slow-start with the FIFO in the subject topology, or no peak at
> all for the control topology; you should see this for whichever RFC-3168 flow is
> chosen as the control. Expected results with L4S in the subject topology,
> however, are a peak extending about 4 seconds before returning to baseline.

L4S: Sender → Delay → FIFO middlebox (bottleneck 1) → FQ-AQM middlebox (bottleneck 2) → L4S receiver

SCE: Sender → Delay → FIFO middlebox (bottleneck 1) → FQ-AQM middlebox (bottleneck 2) → SCE receiver

#### Scenario 6 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-2/)

Observations:

- SCE for [Cubic](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-1/batch-sce-s6-1-cubic-50Mbit-80ms_fixed.png) and [Reno-SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-1/batch-sce-s6-1-reno-sce-50Mbit-80ms_fixed.png) vs L4S for [Cubic](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-1/batch-l4s-s6-1-cubic-50Mbit-80ms_fixed.png) and [Prague](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-1/batch-l4s-s6-1-prague-50Mbit-80ms_fixed.png), both at 80ms

  As expected, for SCE we see the described short latency spikes at flow start.

  For L4S, the TCP Prague spike has a longer duration and higher magnitude due
  to the previously described [L4S CoDel Interaction](#l4s-codel-interaction).
  The FIFO located before fq_codel is what causes the ICMP RTT spike. With a
  single fq_codel bottleneck, ICMP RTT would be kept low during the
  spike in TCP RTT by fair queueing and sparse flow optimization.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-2/batch-sce-s6-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-2/batch-l4s-s6-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE or Cubic vs Prague at 10ms

  For SCE, we see a TCP RTT sawtooth during competition. Because there are
  no SCE-aware middleboxes, Reno-SCE reverts to normal RFC-3168 behavior.

  For L4S, we see the previously seen latency spikes at flow startup due
  to the [L4S CoDel Interaction](#l4s-codel-interaction).

- SCE for Reno-SCE vs Reno-SCE at [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-2/batch-sce-s6-2-reno-sce-vs-reno-sce-50Mbit-0ms_fixed.png) and [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/sce-s6-2/batch-sce-s6-2-reno-sce-vs-reno-sce-50Mbit-80ms_fixed.png),
  and L4S for Prague vs Prague at [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-2/batch-l4s-s6-2-prague-vs-prague-50Mbit-0ms_var.png) and [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-10T050403-r1/l4s-s6-2/batch-l4s-s6-2-prague-vs-prague-50Mbit-80ms_var.png)

  As we have seen previously, the latency spikes at flow startup for L4S
  are longer, due to the [L4S CoDel Interaction](#l4s-codel-interaction), and
  their magnitude and duration are partly dependent on the path RTT.

## L4S CoDel Interaction

In the [Scenarios and Results](#scenarios-and-results) section above, we saw
a number of cases where using TCP Prague with CoDel resulted in TCP RTT and
sometimes ICMP RTT spikes. This is due to the fact that the L4S architecture
redefines the meaning of CE to be a fine-grained congestion control signal
that is expected to be marked at shallower queue depths. When it's not, it
takes longer for Prague to reduce it's cwnd to the optimal level. This
is a side effect of the redefinition of CE.

## Installation

Reproducing these results requires setting up the topology described in
[Test Setup](#test-setup), and installing the required kernels and software.

*Warning:* this can take a bit of time to get set up, and the instructions here
may not be correct or complete for your environment. File an
[Issue](https://github.com/heistp/sce-l4s-bakeoff/issues) if there are
any problems or questions.

### Kernels

The following table provides clone commands as well as relatively minimal sample
kernel configurations for virtual machine installations, which may be used to
replace the existing `.config` file in the kernel tree.

| Kernel | Clone Command                                | Sample Config            |
| ------ | -------------------------------------------- | ------------------------ |
| SCE    | `git clone https://github.com/chromi/sce/`   | [config-l4s](config-l4s) | 
| L4S    | `git clone https://github.com/L4STeam/linux` | [config-sce](config-sce) | 

Refer to or use the included [kbuild.sh](kbuild.sh) file to build the kernel and
deploy it to the test nodes. While using this file is not required, it can be
useful in that:

- It supports building and deploying the kernel in parallel to all the test
  nodes with one command.
- It places a text file with git information in the boot directory of each
  node, which is included in the output during setup.

Before using it:

- Edit the settings for the `targets` variables if your hostnames are not
  c[1-2], m[1-4], and s[1-2].
- Make sure your user has ssh access without a password to each test node
  as `root`.

Sample invocation that builds, packages, then deploys to and reboots each
node in parallel:

```
kbuild.sh cycle
```

The command must be run at the root of the kernel source tree, once for
the SCE kernel and once for the L4S kernel.

### Flent

The clients require Flent, and the servers require netserver (see
[Test Setup](#test-setup)). Flent should be compiled from source, as we use
changes that are not in the official latest release as of version 1.3.0.

The instructions below are guidelines for Ubuntu 19.10 (uses Debian
packaging), and may need to be modified for your distribution and version.

#### netperf and netserver

Clients require netperf, and servers require netserver, both compiled
from the netperf repo.

```
sudo apt-get install autoconf automake
git clone https://github.com/HewlettPackard/netperf
cd netperf
./autogen.sh
./configure --enable-dirty=yes --enable-demo=yes
make
sudo make install
```

Running netserver at startup (on server boxes):

First add /etc/systemd/system/netserver.service:
```
[Unit]
Description=netperf server
After=network.target

[Service]
ExecStart=/usr/local/bin/netserver -D
User=nobody

[Install]
WantedBy=multi-user.target
```

Then:
```
sudo systemctl enable netserver
sudo systemctl start netserver
```

#### FPing

Clients require FPing.

```
sudo apt-get install fping
```

#### scetrace

Clients may optionally install [scetrace](https://github.com/heistp/scetrace),
which analyzes the pcap file for congestion control related statistics and
produces a JSON file as output. If scetrace is not present, this analysis
will be skipped.

Note that scetrace was designed for SCE and does not have support for L4S or
AccECN, so some statistics may not be either useful for or applicable to L4S.

#### jq

Clients require jq for some post-processing tasks of the JSON in the
`.flent.gz` file.

```
sudo apt-get install jq
```

#### Flent

Clients require Flent.

```
# install python 3
sudo apt-get install python3
# verify python 3 is the default or make it so, e.g.:
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo apt-get install python3-pip
sudo pip install setuptools matplotlib
git clone https://github.com/tohojo/flent
cd flent
make
sudo make install
```

### Supporting Files

#### bakeoff.batch

Edit `bakeoff.batch` to change any settings at the top of the file to
suit your environment. Note that:

- Flent is run as root so it can manually set the CC algorithm.
- In order to set up and tear down the test nodes, the root user must have
  ssh access to each of the nodes without a password.
- The user used for management on each node must have sudo access without
  a password.

#### run.sh and runbg.sh

The file `run.sh` may be used to run some or all of the tests. Run it
without an argument for usage. A typical invocation which runs all SCE tests:

```
run.sh sce
```

Show all L4S tests that would be run:

```
run.sh l4s dry
```

`runbg.sh` runs tests in the background, allowing the user to log out.
Edit the variables in `run.sh` for Pushover notifications on completion.

#### clean.sh

Removes all results directories with standard naming. It is recommended
to rename results directories to something else if they are to be kept,
then use clean.sh to clean up results which are not needed.

#### show.sh

Shows all log files from the latest result, defaulting to setup logs, e.g.:

```
./show.sh # shows setup logs
./show.sh teardown # shows teardown logs
./show.sh process # shows post-processing logs
```

#### sync_clients.sh

Syncs files between C1 and C2, e.g.

```
./sync_clients.sh push # push files from current to other
./sync_clients.sh pull dry # show what files would be pulled from other to current
```

## Future Work

This is an unstructured collection area for things that may be tested in
the future. We will take inspiration from feedback on the tsvwg mailing list,
as well as
[draft-fairhurst-tsvwg-cc](https://datatracker.ietf.org/doc/draft-fairhurst-tsvwg-cc/)
and what it references, including but not limited to
[RFC 5033](https://tools.ietf.org/html/rfc5033),
[RFC 3819](https://tools.ietf.org/html/rfc3819) and
[RFC 5166](https://tools.ietf.org/html/rfc5166).

- Test with standard pacing parameters
- Add a scenario similar to #6, but with RED
- Run Flent with higher sampling rate for plots
- Expand testing to include:
  - Sudden capacity shifts
  - Burstiness
  - Sudden RTT shifts
  - Packet re-ordering
  - Packet loss
  - Wider spread of throughputs and RTTs
  - Bottleneck shifts (SCE to non-SCE, DualQ to 3168)
  - Asymmetric delays
  - Multipath routing
  - More flows
