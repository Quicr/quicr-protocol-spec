# QuicR Manifest {#manifest}

QuicR Manifests provides a light-weight declarative way for the 
publishers to advertise their capabilities for publishing media. 
Publisher manifest advertisement captures supported codecs, 
encoding rates and also use case specific media properties such as 
languages supported. Publisher advertisements 
are intend to declare publisher's capabilities and a publisher 
is free to choose a subset of those advertised in the manifest
as part of the session and thus does not require a manifest update.
This could be, for example - to change encoding bitrate or the codec used.
However, in the case where a new capability needs to be advertised, 
a manifest update MAY be necessary. 

Publishers advertise their capabilities via QuicR Control channel,
as and when its deemed necessary, under a well-known name. 
Manifest objects are also scoped to a domain and the application under a 
given Origin server.

Subscribers can retrieve the manifest for a given session by subscribing
to the well-known manifest QuicR name. On retrieving 
the manifest, Subscribers/Receivers of the media can discover names 
being published and in turn request media for the corresponding
names by sending appropriate subscriptions (with wildcarding as necessary).

At any point in the session, updated manifest is pushed to the subscribers
like any media objects are delivered to the subscribers of the manifest
QuicR name.

## Scope of the manifest

The role of the manifest is to identify the names as well as aspects
pertaining to the associated data in a given usage context of the
application.

* Typically a manifest identifies the domain and application aspects for
  the set of names that can be published.

* The content of Manifest is application defined and end-to-end
  encrypted.

* The manifest is owned by the application's origin server and are
  accessed as a protected resources by the authorized QuicR clients.

* The QuicR protocol treats Manifests as a named object, thus allowing
  for clients to subscribe for the purposes of bootstrapping into the
  session as well as to follow manifest changes during a session
  [ new members joining a conference for example].

* The manifest has well known name on the Origin server.

Also to note, a given application might provide non QuicR mechanisms to
retrieve the manifest. 

Below is a sample manifest for streaming application where a media 
presentation server describes media streams available for 
distribution. For downstream distribution of media data to clients 
with varying requirements, the central server (along with the source) 
generate different quality media representations. Each such quality is 
represented with a unique name and subscribers are made know of 
the same via the Manifest.

Note: Below json representation is provided as an example 
and need not be the only way to encode the manifest.


```
{
  "liveSessionID" : "jon.doe.music.live.tv",
  "streams: [
      {    
      "id": "1234",
      "codec": "av1",
      "quality": "1280x720_30fps",
      "bitrate": "1200kbps",
      "crypto": "aes128-gcm",
      },
      {    
      "id": "5678",
      "codec": "av1",
      "quality": "3840x2160_30fps",
      "bitrate": "4000kbps",
      "crypto": "aes256-gcm",
      },
      {    
      "id": "9999",
      "codec": "av1",
      "quality": "640x480_30fps",
      "crypto": "aes128-gcm",
      },
  ]
}

```

Given the above manifest, if a publisher wants to send a 4k stream, it
does so by publishing objects following the below pattern

```
//4K Stream
publish: quicr://jon.doe.music.live.tv/video/5678/[groupN/objectM ...]
```

 
If at any point, the producer intends to move to a lower quality stream
due to underlying network conditions, it can do so by switching the published
stream as below

```
//480p Stream
publish: quicr://jon.doe.music.live.tv/video/9999/[groupN/objectM ...]
```

and subscriber who is capable of receiving any of the qualities can do
so by

```
// Receiving any of the published streams and use its name 
// to know more information about media properties via manifest and
// object data
subscribe: quicr://jon.doe.music.live.tv/video/*
```

