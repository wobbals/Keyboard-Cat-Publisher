Keyboard-Cat-Publisher
======================

A silly demonstration of the OpenTok iOS SDK Video Drivers

Usage
=====

OpenTok.framework
-----------------

Download the OpenTok SDK for iOS, version 2.2.0 to the root of this repository:

```curl -L http://tokbox.com/downloads/opentok-ios-sdk-2.2 | tar xj``` 

The paths might not link automatically, so make sure that `OpenTok.framework` is
at the root, not just the distribution tarball contents:

```
danger:Keyboard-Cat-Publisher charley$ ls -la
total 32
drwxr-xr-x   9 charley  staff   306 Jun 10 16:53 .
drwxr-xr-x  43 charley  staff  1462 Jun 10 15:43 ..
drwxr-xr-x  13 charley  staff   442 Jun 10 16:53 .git
drwxr-xr-x   6 charley  staff   204 Jun 10 15:45 KeyboardCatPublisher
-rw-r--r--   1 charley  staff  1082 Jun 10 15:43 LICENSE
drwxr-xr-x   5 charley  staff   170 Jun 10 16:53 OpenTok-iOS-2.2.0-beta.3
drwxr-xr-x   7 charley  staff   238 Jun 10 16:52 OpenTok.framework  # !! THIS
-rw-r--r--   1 charley  staff   106 Jun 10 15:43 README.md

```

OpenTok Session Credentials
---------------------------

In `ViewController.m`, you will need to set an API key, Session ID, and Token
in order to connect and realize the full power of the Keyboard Cat Publisher.
See the notes in the source for more information.

How It Works
============
Check out
[MovVideoCapture.m](KeyboardCatPublisher/KeyboardCatPublisher/MovVideoCapture.m)
to see the internals of the video capture. In this example, we decode H.264
from the .mov with the AVAssetReader interface, pass the decoded frame to the 
OpenTok `OTVideoCapture.videoCaptureConsumer` receiver, and the SDK sends the
media to the session. At this time, there is no way to send pre-encoded frames
directly to the session, so this extra decode-encode cycle is an unfortunate
necessity.

NB: Audio not supported in this example. The app will simply send audio from the
device microphone.

![Screenshot of app](http://i.imgur.com/PchhrB6.png)
