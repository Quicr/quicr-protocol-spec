# Introduction

This specification defines QuicR, a publish and subscribe based 
media delivery protocol over QUIC.

Recently new use cases have emerged requiring higher scalability of
media delivery for interactive realtime applications and much lower latency
for streaming applications and a combination thereof. 

On one side are use cases such as normal web conferences wanting to 
distribute out to millions of viewers and allow viewers to instantly 
move to being a presenter (a.k.a active participant). On the other side are 
use cases such as streaming a soccer game to millions of people 
including people in the stadium watching the game live. Viewers 
watching an e-sports event want to be able to comment 
with low latency to ensure the interactivity aspects between what 
different viewers are preserved. All of these use cases push 
towards latencies that are in the order of 100ms over the 
natural latency the network causes.

The architecture for this specification is outlined in
draft-jennings-moq-arch, where the principal idea is 
client endpoints publish and subscribe to named objects that 
is sent to, and received from relays, that forms an overlay 
delivery network similar to what CDN provides today.

The architecture specification, draft-jennings-moq-arch, is a 
perquisite to read this specification.

This specification defines the protocol specifics of the 
QuicR Media Delivery Architecture.

# Contributing

All significant discussion of development of this protocol is in the
GitHub issue tracker at: ```
https://github.com/Quicr/quicr-protocol-spec ```

# Terminology

* Relay Function: Functionality of the QuicR architecture, that
  implements store and forward behavior at the minimum. Such a function
  typically receives subscriptions and publishes data to the other
  endpoints that have subscribed to the named data. Such functions may
  cache the data as well for optimizing the delivery experience.

* Relay: Server component (physical/logical) in the cloud that
  implements the Relay Function.

* Publisher: An endpoint that sends named objects to a
  Relay. [ also referred to as producer of the named object]

* Subscriber: An endpoint that subscribes and receives the named
  objects. Relays can act as subscribers to other relays. Subscribers
  can also be referred to as consumers.

* Client/QuicR Client: An endpoint that acts as a Publisher, Subscriber,
  or both. May also implement a Relay Function in certain contexts.

* Named Object: Application level chunk of Data that has a unique Name,
  a limited lifetime, priority and is transported via the protocol defined
  in this specification.

* Origin server: Component managing/authoring the names scoped under a 
  domain for a specific application and is responsible for establishing 
  trust between clients and relays for delivering media. Origin servers 
  MAY implement other QuicR functions, such as Relay function, as necessary.

# QuicR Protocol

At a high level, entities within QuicR architecture publish named media 
objects and consume media by subscribing to the named objects. Some 
entities perform "Relay" function providing the store and forward behavior
to serve the subscription requests, that optimize media delivery latencies
for local delivery and improved quality via local repairs, wherever applicable. 
The names used in the QuicR protocol are scoped and authorized to a domain 
by the Origin serving the domain. 

## Origin Server
The Origin serves as the authorization authority for the named resources, 
in the manner similar to an HTTP origin. QuicR names to be used under 
a given domain and the application are authorized by the Origin server.
It is also responsbilbe for establishing necessary trust relationship
between the clients, the relay and itself

## Relays
The Relays play an important role  within the QuicR architecture. They receive 
subscriptions and intent to publish and forwards them towards the origin.
This may involve sending messages directly to the Origin Relay or possibly 
traverse another Relay on the path. Replies to theses message follow the reverse 
direction of the request and when the Origin gives the OK to a subscription or 
intent to publish, the Relay allows the subscription or future publishes to the 
Names in the request.

Subscriptions received are aggregated. When a relay receives a publish
request with data, it will forward it both towards the Origin and to any
clients or relays that have a matching subscriptions. This "short
circuit" of distribution by a relay before the data has even reached the
Origin servers provides significant latency reduction for clients closer
to the relay.

The Relay keeps an outgoing queue of objects to be sent to the each
subscriber and objects are sent in priority order. Relays MAY cache some 
of the information for short period of time and the time cached may depend 
on the origin.

Below example callflow is high-level exchage capturing publish/subscribe 
flow between Alice, the publisher and Bob, Carl, the subscribers 
and the  interactions that occur between Relays on-path and the origin 
server. The details on how the trust setup happens between these
entities are skipped, however.

In the exchange depicted following sequence happen

* Alice sets up a control channel (QUIC Stream) to the relay indicating 
its intent to publish media with name (video1/1) as the representation id. 
It does so by sending `publish_intent`.

* On receiving the `publish_intent` from Alice, the Relay 
setups another control channel to the authorized Origin server and
forwards Alice's `publish_intent` message.

* Once `publish_intent_ok` is received from the Origin, Relay
forwards the same to Alice to enable publishing the media
over the media channel [QUIC Stream or QUIC Datagram]

* In the meanwhile, Bob and Carl subscribe to receiving media
corresponding to the wildcard'ed name (video1/*). They each 
send `subscribe` messages to the Relay on the control channel and 
the same is forwarded by the Relay to the Origin. Successful subscribe 
responses are sent back to Bob and via the relay. Relay makes
note of Bob and Carl's interest in the name (video1/*).
The details of knowing the name via `manifest` is skipped in the callflow.

* Eventually, Alice publishes media on the name (video1/1) towards
the relay on the media channel, which could be over QUIC Streams
or QUIC Datagram as chosen by Alice.

* Media from Alice gets cached at the relay and is forwarded to the 
Origin server (optionally). On noting about interested subscribers,
the media received from Alice is forwarded to both Bob and Carl 
from the local cache.



~~~aasvg
┌───────┐     ┌───────┐    ┌───────┐        ┌───────┐         ┌───────┐
│ Alice │     │  Bob  │    │ Carl  │        │ Relay │         │Origin │
└───┬───┘     └───┬───┘    └───┬───┘        └───┬───┘         └───┬───┘
    │                          │                │                 │
    │          ctrl: pub_intent│                │                 │
    │             (video1/1)   │                │ ctrl:pub_intent │
    │                          │                │   (video1/1)    │
    ├─────────────┼────────────┼───────────────▶│                 │
    │             │            │                ├─────────────────▶
    │             │            │                │
    │                          │                │ ctrl:pub_intent_ok
    │           ctrl: pub_inten│_ok             │
    │                          │                │◀────────────────┤
    ◀─────────────┼────────────┼────────────────┤                 │
    │             │                             │                 │
    │             │  ctrl: subscribe (video1/*) │                 │
    │             │                             │                 │
    │             ├────────────┼────────────────▶ ctrl: subscribe │
    │             │            │                │   (video1/*)    │
    │             │            │                │─────────────────▶
    │             │            │                │                 │
    │             │            │                │     ctrl:       │
    │             │            │                │  subscribe_ok   │
    │             │            │                │   (video1/*)    │
    │             │            │                │                 │
    │             │            │                ◀─────────────────┤
    │             │            │                │                 │
    │             │                             │─────┐  add bob: │
    │             │ ctrl: subscribe_ok          │ ◀───┘  video1/* │
    │             │                             │                 │
    │             │◀───────────┼────────────────┤                 │
    │             │            │                │                 │
    │             │            │  ctrl:sub:     │                 │
    │             │            │  (video1/*)    │                 │
    │             │            │                │                 │
    │             │            ├────────────────▶ ctrl: subscribe │
    │             │            │                │   (video1/*)    │
    │             │            │                │─────────────────▶
    │             │            │                │     ctrl:       │
    │             │            │                │  subscribe_ok   │
    │             │            │                │   (video1/*)    │
    │             │            │                │                 │
    │             │            │                ◀─────────────────┤
    │             │            │                │                 │
    │             │                             ├────┐  add carl: │
    │             │   ctrl: subscribe_ok        │◀───┘  video1/*  │
    │             │                             │                 │
    │             │◀───────────┼────────────────┤                 │
    │                          │                │                 │
    │    media:pub:video1/1    │                │                 │
    │                          │                │     cache       │
    ├─────────────┼────────────┼───────────────▶│                 │
    │             │            │                │─────┐           │
    │             │            │                │ ◀───┘    [pub]  │
    │             │            │                │                 │
    │                          │  media:pub:    ├─────────────────▶
    │  media:pub:              │  (video1/1)    │                 │
    │  (video1/1)              │                │                 │
    │                          │◀───────────────┤                 │
    │◀────────────┼────────────┼────────────────┤                 │
    │             │            │                │                 │
    │             │            │                                  │

~~~
{: title="Pub/Sub flow between Alice(publisher), Bob, Carl (subscirbers), Relay and Origin"}
