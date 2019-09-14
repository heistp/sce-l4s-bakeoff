# sce-l4s-bakeoff

This repo contains lab tests using [Flent](https://flent.org/) to compare
[SCE](https://github.com/chromi/sce/) and [L4S](https://riteproject.eu/dctth/).


## Table of Contents

1. [Introduction](#introduction)
2. [Test Setup](#test-setup)
3. [Test Output](#test-output)
4. [Scenarios and Results](#scenarios-and-results)
   1. [Scenario 1](#scenario-1)
   2. [Scenario 2](#scenario-2)
   3. [Scenario 3](#scenario-3)
   4. [Scenario 4](#scenario-4)
   5. [Scenario 5](#scenario-5)
   6. [Scenario 6](#scenario-6)
5. [List of SCE Issues](#list-of-sce-issues)
6. [List of L4S Issues](#list-of-l4s-issues)
7. [Installation](#installation)
   1. [Kernels](#kernels)
   2. [Flent](#flent)
   3. [Supporting Files](#supporting-files)
8. [Future Work](#future-work)
9. [Acknowledgements](#acknowledgements)


## Introduction

This repo contains lab tests using [Flent](https://flent.org/) to compare
[SCE](https://github.com/chromi/sce/) and [L4S](https://riteproject.eu/dctth/).
The current tests cover some basics, including link utilitization,
inter-flow and intra-flow latency, fairness, a simple gaming scenario and
interaction with the CoDel AQM.

In deference to [RFC 5033](https://tools.ietf.org/html/rfc5033), as it pertains
to the evalution of congestion control proposals:

> The high-order criteria for any new proposal is that a serious scientific
> study of the pros and cons of the proposal needs to have been done such that
> the IETF has a well-rounded set of information to consider.

We admit that we have quite a ways to go to thoroughly test all of the
considerations mentioned in the literature. We also acknowledge that real world
tests in realistic scenarios should be the final arbiter of the utility of
high-fidelity congestion control and how it may be deployed. To the extent
that we can, we will try to incorporate any reported problems seen in
real world testing into something we can repeatably test in the lab.

The plan is to iterate on these tests up until IETF 106 in Singapore, so that
the IETF has some more concrete comparative material to work with in evaluating
the SCE and L4S proposals. We will consider input from feedback on the tsvwg
mailing list and surrounding communities, as well as the helpful
[draft-fairhurst-tsvwg-cc](https://datatracker.ietf.org/doc/draft-fairhurst-tsvwg-cc/)
and its references, including but not limited to
[RFC 5033](https://tools.ietf.org/html/rfc5033),
[RFC 3819](https://tools.ietf.org/html/rfc3819) and
[RFC 5166](https://tools.ietf.org/html/rfc5166).

:warning: *Disclaimer:* These tests were designed, run and interpreted by
members of the SCE team and related community, and as such are influenced by
that perspective. That said, we feel it's reasonable to help illuminate
what we see as deployment challenges for the L4S architecture, as well as find
any problems with SCE so that we may correct them. Regardless, we will
endeavor to maintain a scientific approach.

Please feel free to file an
[Issue](https://github.com/heistp/sce-l4s-bakeoff/issues) for any of the
following reasons:
- Suggestions for new tests or variations (see also [Future Work](#future-work))
- Suspicious results
- Updated code for re-testing
- Requests for additions or corrections to plots or other test output
- Inaccuracies or omissions
- Biased or inappropriate wording in this document


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
C1 to S1, and L4S tests from C2 to S2. 


### Kernels, Software and sysctl settings

The kernels, software and sysctl settings on each node are as follows:

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

### Qdisc Configuration

Unless otherwise noted, default parameters are used for all qdiscs. One exception is for Cake, for which we use the
`besteffort` parameter in all cases, which treats all traffic as besteffort,
regardless of any DSCP marking. Since we are not testing DSCP markings in these
tests, this has no effect other than to make it a little clearer when viewing
the tc statistics.

The setup and teardown logs (examples
[here](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/batch-l4s-s1-1-cubic-50Mbit-0ms.setup.log) and [here](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/batch-l4s-s1-1-cubic-50Mbit-0ms.teardown.log)),
accessible from the *Full Results* links, show the configuration and statistics
of the qdiscs before and after each test is run.

:information_source: All bottlenecks restrict to 50Mbit, unless otherwise
noted. Bandwidth information is also available in line 3 of the plot title.

### Pacing Parameters

:warning: The non-standard pacing parameters of `ca_ratio=40` and `ss_ratio=100`
are used for the SCE client in these tests, the theoretical justification for
which is as follows (from Jonathan Morton):

> 0: Transient queuing is much more noticeable to high-fidelity congestion
> signalling schemes than to traditional AQM.  A single brief excursion into the
> marking region kicks the flow out of SS, even if it hasn't actually reached
> the correct range of cwnd to match path BDP.
> 
> 1: The default pacing parameters exhaust the cwnd in less than one RTT,
> regardless of whether in SS or CA phase, leaving gaps in the stream of packets
> and thus making the traffic more bursty.  Ack clocking is not sufficient to
> smooth those bursts out sufficiently to prevent significant amounts of
> transient queuing, especially during SS.  Hence we choose 100% as the maximum
> acceptable scale factor.
> 
> 2: SS makes the cwnd double in each RTT, and it takes a full RTT for the first
> congestion signal to take effect via the sender, so the transition out of SS
> has to compensate for that by at least halving the send rate.  The initial
> response to transitioning out of SS phase is an MD for a traditional CC (to
> 70% with CUBIC), plus the change from SS to CA pacing rate (to 60% of SS rate
> with defaults).  In total this is a reduction to 42% of the final SS send rate
> at the start of CA phase, which is compatible with this requirement.
> 
> 3: High fidelity CC responds much less to the initial congestion signal, which
> may indicate less than a millisecond of instantaneous excess queuing and thus
> the need for only a very small adjustment to cwnd.  The one-time reduction of
> send rate required due to the SS-CA transition must therefore be provided
> entirely by the pacing scale factor.  Our choice of 40% gives similar
> behaviour to CUBIC with the default scale factors, including the opportunity
> to drain the queue of excess traffic generated during the final RTT of the SS
> phase.
> 
> 4: A sub-unity pacing gain may also show benefits in permitting smooth
> transmission in the face of bursty and contended links on the path, which
> cause variations in observed RTT.  This has not yet been rigorously
> quantified.

Experimentally, these pacing settings have been shown to help avoid overshoot
for SCE.

We do not use these settings for L4S, because that's not what the L4S team
tested with, and we have not found these settings to materially improve the
results for L4S in repeatable ways. For comparison, the full results for an
L4S run with the modified pacing are
[here](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-12T021200-pacing-100). Please file
an [Issue](https://github.com/heistp/sce-l4s-bakeoff/issues) if there are
any concerns with this.


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
- `*.setup.log`- commands and output for setting up each node, as well as
  kernel version information (nodes that do not appear have their configuration
  set to default)
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

Each scenario is run first with one flow, then with two flows
(the second flow beginning after 10 seconds), and with the following
variations:

- RTT delays of 0ms, 10ms and 80ms
- Different CC algorithms as appropriate

Full results obtained at the SCE Data Center in Portland are available
[here](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/).

Following are descriptions of the scenarios, with observations and links
to some relevant results from Portland. Issues are marked with the icon
:exclamation:, which is linked to the corresponding issue under the sections
[List of SCE Issues](#list-of-sce-issues) and [List of L4S
Issues](#list-of-l4s-issues).

### Scenario 1

> This is a sanity check to make sure the tools worked, and evaluate some
> basics.

L4S: Sender → L4S middlebox (bottleneck) → L4S Receiver

SCE: Sender → SCE middlebox 1q (bottleneck) → SCE Receiver

#### Scenario 1 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/)

*One-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-1/batch-sce-s1-1-cubic-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/batch-l4s-s1-1-cubic-50Mbit-10ms_fixed.png), single Cubic flows at 10ms

  Cake maintains a lower ICMP and TCP RTT than dualpi2, likely due to the
  operation of Cake's COBALT (CoDel-like) AQM in comparison to PI. Note that
  Cake's default target is 5ms, and dualpi2's is 15ms.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-1/batch-sce-s1-1-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/batch-l4s-s1-1-prague-50Mbit-10ms_fixed.png), single Reno-SCE and Prague flows at 10ms

  TCP Prague, which uses dualpi2's L queue, maintains a lower ICMP and TCP RTT
  than Reno-SCE. This is probably due to dualpi2 marking congestion at a lower
  queue depth than Cake, which starts marking at a default depth of 2.5ms. We
  hypothesize that the earlier default marking for dualpi2 may lead to a higher
  drop in utilization with bursty flows, but this will be tested at a later
  time.

  [:exclamation:](#l4s-under-utilization) For L4S, we see intermittent
  under-utilization on this test.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-1/batch-sce-s1-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-1/batch-l4s-s1-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE and Prague flows at 80ms

  For SCE, Reno-SCE shows a faster ramp during slow start, because while NewReno
  growth is 1/cwnd segments per ack, Reno-SCE grows by 1/cwnd segments per acked
  segment, so about twice as fast as stock NewReno, but still adhering to the
  definition of Reno-linear growth. Also, sometimes a single Reno-SCE flow can
  receive a CE mark, even when already in CA on an otherwise unloaded link. This
  may be due to a transient load in the test environment, causing a temporary
  buildup of queue. CE *can* still occur for SCE flows and this is not
  necessarily abnormal.

  [:exclamation:](#l4s-under-utilization) For L4S, as with 10ms, we see
  intermittent under-utilization on this test.

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-2/batch-sce-s1-2-cubic-vs-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-cubic-50Mbit-80ms_fixed.png), Cubic vs Cubic at 80ms

  Cubic ramps up faster for dualpi2 than Cake, but with a corresponding spike in
  TCP RTT. We hypothesize that Cubic is exiting HyStart early for Cake here,
  possibly due to minor variations in observed RTT.

  We can also see that although TCP RTT is higher for dualpi2 than Cake, the L4S
  ping, marked ECT(1), shows lower RTT as the only L queue occupant.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-2/batch-sce-s1-2-cubic-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-80ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 80ms

  [:exclamation:](#sce-single-queue-non-sce-unfairness) Without changes to the
  default SCE marking ramp, Reno-SCE is dominated by a Cubic flow in a single
  queue.

  [:exclamation:](#l4s-dualpi2-unfairness) Prague loses to Cubic in dualpi2
  competition at 80ms, although its TCP RTT is decidedly lower. Here we see
  different behaviors at
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-10ms_fixed.png) and [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-cubic-vs-prague-50Mbit-0ms_fixed.png),
  suggesting that fairness is RTT dependent in this case.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-2/batch-sce-s1-2-reno-sce-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-prague-vs-prague-50Mbit-80ms_fixed.png), Reno-SCE vs Reno-SCE and Prague vs Prague at 80ms

  Noting that this is a single queue, Reno-SCE shows throughput fairness,
  with convergence in about 25 seconds at 80ms. Convergence time drops to a
  second or two at
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s1-2/batch-sce-s1-2-reno-sce-vs-reno-sce-50Mbit-10ms_fixed.png).

  [:exclamation:](#l4s-dualpi2-unfairness)  We are not seeing throughput
  fairness for TCP Prague vs itself at any of the tested RTTs: 
  [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-prague-vs-prague-50Mbit-0ms_fixed.png),
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-prague-vs-prague-50Mbit-10ms_fixed.png), or
  [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s1-2/batch-l4s-s1-2-prague-vs-prague-50Mbit-80ms_fixed.png)
 

### Scenario 2

> This is the most favourable-to-L4S topology that incorporates a non-L4S
> component that we could easily come up with.

L4S: Sender → FQ-AQM middlebox (bottleneck) → L4S middlebox → L4S receiver

SCE: Sender → FQ-AQM middlebox (bottleneck) → SCE middlebox → SCE receiver

#### Scenario 2 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-2/)

*One-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-1/batch-sce-s2-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/batch-l4s-s2-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  Since fq_codel is the bottleneck in this scenario, single Cubic flows show
  remarkably similar characteristics for both SCE and L4S.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-1/batch-sce-s2-1-dctcp-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/batch-l4s-s2-1-dctcp-50Mbit-80ms_fixed.png), single flow DCTCP-SCE or
  DCTCP at 80ms

  DCTCP-SCE shows a throughput sawtooth because DCTCP-SCE treats the CE marks
  from fq_codel as per ABE, defined in
  [RFC 8511](https://tools.ietf.org/html/rfc8511), which is closer to the
  traditional [RFC 3168](https://tools.ietf.org/html/rfc3168) response.

  In the L4S architecture, DCTCP does not show a sawtooth, because CE has been
  redefined as a fine-grained congestion signal, as allowed for experimentation
  by [RFC 8311](https://tools.ietf.org/html/rfc8311). Correspondingly, the
  increase in TCP RTT stays right around fq_codel's target of 5ms, as compared
  to DCTCP-SCE, whose TCP RTT increase only approaches 5ms as queue depths near
  the CE marking point.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-1/batch-sce-s2-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE and Prague flows at 80ms

  As expected, Reno-SCE shows a Reno-like throughput sawtooth, because SCE 
  marking is not occurring at the bottleneck.

  [:exclamation:](#l4s-codel-interaction) Although TCP Prague maintains
  higher utilization due to its DCTCP-like behavior and L4S style response
  to CE, there is a remarkable TCP RTT spike as the flow starts due to its
  interaction with CoDel. The full extent of it is better seen in the
  [same plot with variable scaling](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_var.png).
  In this case, the spike occurs for TCP RTT and not ICMP RTT because
  fq_codel's fair queueing and sparse flow optimization are keeping queue
  sojourn times low for the sparse ICMP flow.

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-2/batch-sce-s2-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-2/batch-l4s-s2-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 10ms

  [:exclamation:](#l4s-codel-interaction) Consistent with earlier results,
  as the second flow is introduced (Reno-SCE for SCE and Prague for L4S),
  the TCP RTT spike due to the interaction with CoDel only occurs for
  TCP Prague.

### Scenario 3

> This scenario is obtained from topology 2 by adding the `flows 1` parameter
> to fq_codel, making it a single queue AQM. Any queueing delays will affect
> all other flows in the queue.

L4S: Sender → single-AQM middlebox (bottleneck) → L4S middlebox → L4S receiver

SCE: Sender → single-AQM middlebox (bottleneck) → SCE middlebox → SCE receiver

#### Scenario 3 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-2/)

*One-flow Observations:*

- [SCE FQ](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s2-1/batch-sce-s2-1-reno-sce-50Mbit-80ms_fixed.png) vs [SCE 1Q](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-1/batch-sce-s3-1-reno-sce-50Mbit-80ms_fixed.png) and
[L4S FQ](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s2-1/batch-l4s-s2-1-prague-50Mbit-80ms_fixed.png) vs [L4S 1Q](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-1/batch-l4s-s3-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  As expected, for SCE, moving to a single queue makes the short spike in
  RTT equivalent for ICMP and TCP, as there is no longer fair queueing or
  sparse flow optimization.

  [:exclamation:](#l4s-codel-interaction)For L4S, the single queue means that the
  interaction with CoDel affects all other flows sharing the same queue.

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-2/batch-sce-s3-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-2/batch-l4s-s3-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE and Cubic vs Prague at 10ms

  For SCE, Reno-SCE's mean throughput is about 1.5x that of Cubic, due to the
  use of the ABE response to CE described in
  [RFC 8511](https://tools.ietf.org/html/rfc8511). Whether or not this is
  acceptable is a discussion that should happen as part of the ABE
  standardization process.

  [:exclamation:](#l4s-ce-unfairness) For L4S, TCP Prague's mean throughput
  is about 4x that of Cubic, due to the redefinition of CE and its assumption
  that the CE mark is coming from an L4S aware AQM.

  The potential for unfairness was hinted at in
  [RFC 3168 Section 5](https://tools.ietf.org/html/rfc3168#section-5), where
  it mentions the possible consequences of treating CE differently than drop:

  > If there were different congestion control responses to a CE codepoint 
  > than to a packet drop, this could result in unfair treatment for
  > different flows.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-80ms_fixed.png), Reno-SCE vs Reno-SCE and Prague vs Prague at 80ms

  Reno-SCE vs Reno-SCE shows approximate throughput fairness in a single
  queue at an RTT delay of 80ms, as well as [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-0ms_fixed.png) and [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s3-2/batch-sce-s3-2-reno-sce-vs-reno-sce-50Mbit-10ms_fixed.png).

  [:exclamation:](#l4s-ce-unfairness) TCP Prague vs TCP Prague shows
  unfairness in favor of the first flow to start. This also occurs at
  [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-0ms_fixed.png) and
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s3-2/batch-l4s-s3-2-prague-vs-prague-50Mbit-10ms_fixed.png),
  however, we have noted in several runs that the unfairness does not
  always favor the first flow. We're not sure of the cause of this, so have
  classified it under a possible result of CE unfairness.

### Scenario 4

> This explores what happens if an adversary tries to game the system by
> forcing ECT(1) on all packets.

L4S: Sender → ECT(1) mangler → L4S middlebox (bottleneck) → L4S receiver

SCE: Sender → ECT(1) mangler → SCE middlebox (bottleneck) → SCE receiver

:warning: In the two-flow results for this scenario, "gamed" flows are not
labelled as such in the plot legends, which only contain the names of the TCP CC
algorithms. However, the order of the flows are the same as listed in the title,
and may also be inferred from their behavior.

#### Scenario 4 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-2/)

*One-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-1/batch-sce-s4-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  For SCE, Cubic is unaffected by setting ECT(1) on all packets.

  For L4S, setting ECT(1) on all packets places them in the L queue,
  causing a drop in utilization that increases as the RTT delay goes up
  (compare with
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-10ms_fixed.png) and [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/batch-l4s-s4-1-cubic-50Mbit-0ms_fixed.png)).

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-1/batch-sce-s4-1-dctcp-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/batch-l4s-s4-1-dctcp-50Mbit-80ms_fixed.png), single DCTCP-SCE or DCTCP flow at 80ms

  As expected, setting ECT(1) on all packets causes a collapse in throughput
  for DCTCP-SCE, as there is a cwnd reduction for each ACK, limited to a
  minimum cwnd of two segments (however, with the 40% CA scale factor for
  pacing, this is effectively 0.8 from a throughput standpoint).

  For L4S, setting ECT(1) on all packets causes a drop in utilization for
  DCTCP that's RTT dependent, similar to Cubic.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-1/batch-sce-s4-1-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-1/batch-l4s-s4-1-prague-50Mbit-10ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  We see the similar throughput collapse for SCE.

  L4S is unaffected because TCP Prague marks ECT(1) anyway, however, the
  under-utilization problem with dualpi2 is also sometimes seen here.

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s4-2/batch-sce-s4-2-cubic-vs-cubic_gamed-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s4-2/batch-l4s-s4-2-cubic-vs-cubic_gamed-50Mbit-80ms_fixed.png), Cubic vs Cubic "Gamed" at 80ms

  For SCE, Cubic is unaffected by the setting of ECT(1), so the result is
  the same as if there were no gaming.

  For L4S, the gamed flow sees a reduction in utilization that causes it to have
  lower throughput than the un-gamed flow, which should discourage gaming
  in this way.

### Scenario 5

> This is Sebastian Moeller's scenario. We had some discussion about the
> propensity of existing senders to produce line-rate bursts, and the way these
> bursts could collect in *all* of the queues at successively decreasing
> bottlenecks. This is a test which explores the effects of that scenario, and
> is relevant to best consumer practice on today's Internet.

L4S: Sender → L4S middlebox (bottleneck #1, 100Mbit) → FIFO middlebox (bottleneck #2, 50Mbit) → FQ-AQM middlebox (bottleneck #3, 47.5Mbit) → L4S receiver

SCE: Sender → SCE middlebox (bottleneck #1, 100Mbit) → FIFO middlebox (bottleneck #2, 50Mbit) → FQ-AQM middlebox (bottleneck #3, 47.5Mbit) → SCE receiver

#### Scenario 5 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-2/)

*One-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-1/batch-sce-s5-1-cubic-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/batch-l4s-s5-1-cubic-50Mbit-80ms_fixed.png), single Cubic flow at 80ms

  Both SCE and L4S see very similar latency spikes at flow startup, as the
  initial bottleneck (bottleneck 3) is the same.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-1/batch-sce-s5-1-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-10ms_fixed.png), single Reno-SCE or Prague flow at 10ms

  For SCE, we see a similar latency spike at flow startup as with Cubic.

  [:exclamation:](#l4s-codel-interaction) For L4S, but we also see a longer
  and higher spike in TCP RTT due to the interaction with CoDel, and a
  resulting spike in ICMP RTT that occurs at the single FIFO queue in
  bottleneck 2.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-1/batch-sce-s5-1-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-80ms_fixed.png), single Reno-SCE or Prague flow at 80ms

  The initial latency spike for SCE is similar to the one at 10ms.

  [:exclamation:](#l4s-codel-interaction) The intra-flow and inter-flow
  spikes for L4S have increased in duration and magnitude in going from 10ms
  to 80ms (see also the Prague plots with variable RTT scaling at
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-10ms_var.png) and [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-1/batch-l4s-s5-1-prague-50Mbit-80ms_var.png)).

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-2/batch-sce-s5-2-cubic-vs-reno-sce-50Mbit-80ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-2/batch-l4s-s5-2-cubic-vs-prague-50Mbit-80ms_fixed.png), Cubic vs Reno-SCE or Cubic vs Prague at 80ms

  For SCE, similar relatively short latency spikes are seen on startup of
  each flow.

  [:exclamation:](#l4s-codel-interaction) For L4S, the longer latency spike
  upon startup of the Prague flow, due to the interaction with CoDel,
  affects the Cubic flow and both ping flows as well.

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s5-2/batch-sce-s5-2-reno-sce-vs-reno-sce-50Mbit-80ms_var.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s5-2/batch-l4s-s5-2-prague-vs-prague-50Mbit-80ms_var.png), Reno-SCE vs Reno-SCE or Prague vs Prague at 80ms, variable RTT scaling

  For SCE, the latency bursts on startup of each flow are comparatively short,
  but significant in magnitude.

  [:exclamation:](#l4s-codel-interaction) For L4S, the longer latency spikes
  due to the interaction with CoDel can be seen. The following commentary
  from Jonathan Morton describes what each trace represents:

  > The *magenta* trace (overlapping completely with the *violet* trace) is the
  > delay incurred at the FIFO.
  >
  > The *green* trace is the delay incurred in both queues by the first Prague
  > flow (whose throughput is tracked by the *aqua* trace).
  >
  > The *yellow* trace is the delay incurred in both queues by the second
  > Prague flow (whose throughput is tracked by the *orange* trace).

  :information_source: Note here that when the second Prague flow drops out
  of slow start early, as commonly happens with the default pacing parameters,
  the latency spike on startup of the second flow is minimal to nonexistent.
  However, when `ss_ratio=100` and `ca_ratio=40` are used (as we typically
  use for SCE), the second flow usually does not drop out of slow start too
  early, and the second latency spike can be seen, as in
  [this plot](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-12T021200-pacing-100/l4s-s5-2/batch-l4s-s5-2-prague-vs-prague-50Mbit-80ms_var.png).

### Scenario 6

> This is similar to Scenario 5, but narrowed down to just the FIFO and CoDel
> combination.  Correct behaviour would show a brief latency peak caused by the
> interaction of slow-start with the FIFO in the subject topology, or no peak at
> all for the control topology; you should see this for whichever
> [RFC 3168](https://tools.ietf.org/html/rfc3168) flow is chosen as the control.
> Expected results with L4S in the subject topology, however, are a peak
> extending about 4 seconds before returning to baseline.

L4S: Sender → Delay → FIFO middlebox (bottleneck #1, 52.5Mbit) → FQ-AQM middlebox (bottleneck #2, 50Mbit) → L4S receiver

SCE: Sender → Delay → FIFO middlebox (bottleneck #1, 52.5Mbit) → FQ-AQM middlebox (bottleneck #2, 50Mbit) → SCE receiver

#### Scenario 6 Portland Results

Full results: [SCE one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-1/) |
[SCE two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-2/) |
[L4S one-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-1/) |
[L4S two-flow](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-2/)

*One-flow Observations:*

- SCE for [Cubic](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-1/batch-sce-s6-1-cubic-50Mbit-80ms_fixed.png) and [Reno-SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-1/batch-sce-s6-1-reno-sce-50Mbit-80ms_fixed.png) vs L4S for [Cubic](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-1/batch-l4s-s6-1-cubic-50Mbit-80ms_fixed.png) and [Prague](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-1/batch-l4s-s6-1-prague-50Mbit-80ms_fixed.png), both at 80ms

  As expected, for SCE we see the described relatively short latency spikes
  at flow start.

  [:exclamation:](#l4s-codel-interaction) For L4S, the TCP Prague spike has a
  longer duration and higher magnitude due to the interaction with CoDel.
  The FIFO located before fq_codel is what causes the ICMP RTT spike. With a
  single fq_codel bottleneck, ICMP RTT would be kept low during the
  spike in TCP RTT by fair queueing and sparse flow optimization, as we saw
  in [Scenario 2](#scenario-2).

*Two-flow Observations:*

- [SCE](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-2/batch-sce-s6-2-cubic-vs-reno-sce-50Mbit-10ms_fixed.png) vs [L4S](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-2/batch-l4s-s6-2-cubic-vs-prague-50Mbit-10ms_fixed.png), Cubic vs Reno-SCE or Cubic vs Prague at 10ms

  For SCE, we see a TCP RTT sawtooth during competition. Because there are
  no SCE-aware middleboxes, Reno-SCE reverts to standard
  [RFC 3168](https://tools.ietf.org/html/rfc3168) behavior.

  [:exclamation:](#l4s-codel-interaction) For L4S, we see the previously
  seen latency spikes at flow startup.

- SCE for Reno-SCE vs Reno-SCE at [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-2/batch-sce-s6-2-reno-sce-vs-reno-sce-50Mbit-0ms_fixed.png),
[10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-2/batch-sce-s6-2-reno-sce-vs-reno-sce-50Mbit-10ms_fixed.png)
and [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/sce-s6-2/batch-sce-s6-2-reno-sce-vs-reno-sce-50Mbit-80ms_fixed.png),
  and L4S for Prague vs Prague at [0ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-2/batch-l4s-s6-2-prague-vs-prague-50Mbit-0ms_var.png),
  [10ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-2/batch-l4s-s6-2-prague-vs-prague-50Mbit-10ms_var.png) and
  [80ms](https://www.heistp.net/downloads/sce-l4s-bakeoff/bakeoff-2019-09-13T045427-r1/l4s-s6-2/batch-l4s-s6-2-prague-vs-prague-50Mbit-80ms_var.png)

  [:exclamation:](#l4s-codel-interaction) As we have seen previously, the
  latency spikes at flow startup for L4S are longer, due to the
  interaction with CoDel, and their magnitude and duration are partly
  dependent on the path RTT.

## List of SCE Issues

### SCE Single Queue Non-SCE Unfairness

Because SCE is marked at lower queue depths than CE, non-SCE flows will
outcompete SCE flows in a single queue without either changes to the
SCE marking ramp,
[presented at IETF 105](https://datatracker.ietf.org/meeting/105/materials/slides-105-tsvwg-sessa-61-some-congestion-experienced-00),
or the proposed
[Lightweight Fair Queueing](https://tools.ietf.org/html/draft-morton-tsvwg-lightweight-fair-queueing-00).

Changing the marking ramp is effective, but can require some tuning. The
use of FQ is also effective, but has caused some controversy because of a
perception that FQ can do harm to periodic bursty flows. For this reason,
the SCE team continues to explore alternative solutions to this challenge.

## List of L4S Issues

Note that the list below may contain inaccuracies, as it comes from our
attempt to combine the behavior in different scenarios into a list of
issues. Please file an
[Issue](https://github.com/heistp/sce-l4s-bakeoff/issues) to report any
corrections.

### L4S Under-Utilization

We sometimes see link under-utilization for either DCTCP or TCP Prague
when used with dualpi2. This may be accompanied by occasional steps up in
throughput. See [Scenario 1](#scenario-1). One possible cause for this
could be Flent's simultaneous ping measurement flow, but the drops in
utilization we sometimes see (50%, for example) are larger than might
be expected from that.

### L4S Dualpi2 Unfairness

We do not see fairness between either Cubic vs TCP Prague or TCP Prague vs
itself when used with dualpi2, and fairness characteristics are RTT
dependent. If there are dualpi2 parameters that influence this, we could
add those to the test, but we did expect that fairness between TCP
Prague and itself would be the default.
See [Scenario 1](#scenario-1).

### L4S CoDel Interaction

In the [Scenarios and Results](#scenarios-and-results) section above, we saw
a number of cases where using TCP Prague with CoDel resulted in TCP RTT and
sometimes ICMP RTT spikes. This is due to the fact that the L4S architecture
redefines CE to be a fine-grained congestion control signal that is expected to
be marked at shallower queue depths. When it's not, it takes longer for Prague
to reduce it's cwnd to the optimal level.

This interaction is expected to be worse for CoDel than for some other AQMs,
because CoDel's marking rate stays constant as queue depth increases, whereas
the marking rate rises quickly with queue depth for
[PIE](https://tools.ietf.org/html/rfc8033) and
[RED](http://www.icir.org/floyd/papers/red/red.html), for example.

### L4S CE Unfairness

When TCP Prague receives CE signals from a non-L4S-aware AQM, as can happen
in [Scenario 3](#scenario-3), for example, it can result in domination of
L4S flows over classic flows sharing the same queue. This is due to the 
redefinition of CE, and the inability of the current implementation to detect
when the bottleneck is a non-L4S-aware queue.

This issue may also extend to unfairness among L4S (TCP Prague) flows when
being signaled by non-L4S-aware AQM, such as seen later in
[Scenario 3](#scenario-3) (as those flows may expect a higher CE signaling
rate), but we're unsure about that.

## Installation

Reproducing these results requires setting up the topology described in
[Test Setup](#test-setup), and installing the required kernels and software.

:warning: This can take a bit of time to get set up, and the instructions here
may not be correct or complete for your environment. File an
[Issue](https://github.com/heistp/sce-l4s-bakeoff/issues) if there are
any problems or questions.

### Kernels

The following table provides clone commands as well as relatively minimal sample
kernel configurations for virtual machine installations, which may be used to
replace the existing `.config` file in the kernel tree.

| Kernel | Clone Command                                | Sample Config            |
| ------ | -------------------------------------------- | ------------------------ |
| SCE    | `git clone https://github.com/chromi/sce/`   | [config-sce](config-sce) | 
| L4S    | `git clone https://github.com/L4STeam/linux` | [config-l4s](config-l4s) | 

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
AccECN, so some statistics are neither useful for nor applicable to L4S.

#### jq

Clients require jq for some post-processing tasks of the JSON in the
`.flent.gz` file.

```
sudo apt-get install jq
```

#### parallel

Clients may optionally install the GNU parallel command, which makes some
post-processing tasks faster with multiple CPUs, including running bzip2
on each pcap file.

```
sudo apt-get install parallel
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

### Up Next

This is what we plan to do next:

- Add a scenario with a sudden capacity increase, then decrease
- Add a scenario with a sudden RTT increase, then decrease
- Add a scenario with a simulated bursty link using netem slotting

### Inbox

This is an unstructured collection area for things that may be tested in
the future:

- Packet loss
- Packet re-ordering
- Very high and very low bandwidths
- Very high and very low RTTs
- Bottleneck shifts (SCE to non-SCE, DualQ to 3168)
- Asymmetric links, including highly asymmetric (> 25:1)
- Asymmetric delays
- Multipath routing
- More flows
- Bi-directional traffic
- RED AQM


## Acknowledgements

Many thanks go out to:

- Jonathan Morton for deciphering and explaining many complex results
- the L4S team for working with us to quickly prepare their code for testing
- Sebastian Moeller for providing the illuminating
[Scenario 5](#scenario-5)
- Toke Høiland-Jørgensen for helping with key changes to
[Flent](https://flent.org/)
