# NGINX

### Problem

Port numbers are not easy to remember and it is hard to remember, that aria2 is running on `raspberrypi.local:3001`.

### Solution

`avahi` is used to create a subdomain in the local network (`aria2.raspberrypi.local`) and nginx to proxy the traffic on port `80` of subdomain to a specified port.

So `aria2.raspberrypi.local` will be the same as `raspberrypi.local:3001`.