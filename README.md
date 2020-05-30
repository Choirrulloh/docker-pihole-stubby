# docker-pihole-stubby  
a docker-compose.yml with pihole and stubby containers  

as you know, pihole accepts only ip address as dns server, so i had to give them static ip addresses.  

stubby's ip is 172.20.0.10, pihole's ip is 172.20.0.5  

use 172.20.0.10#53 as dns server ip in pihole's dns settings.  

also, there is 2 images in docker hub, linux/amd64 and linux/arm,   
i don't know how to make a single image for both of them yet. you can send a pull request if know how to do it.  

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/

-To disable host resolve service to use port 53 with pi-hole,

* sudo systemctl disable systemd-resolved.service
* sudo systemctl stop systemd-resolved