# Docker One Liner Examples

### Examples for automating Docker and general lazyness

```
# start shells in the following OS's (rm means it will delete when you exit the shell, see the mittens example for persistance):
docker run -it --rm ubuntu
docker run -it --rm debian
docker run -it --rm fedora
docker run -it --rm centos
docker run -it --rm busybox

# start a container named mittens that will run in the background
docker run -itd --name mittens ubuntu

# now attach to the shell of the newly created container by name (ID also valid)
docker attach mittens

# start a stopped container by ID or name
docker start <container_id or name>
docker start mittens 

# Stop a container by ID or name
docker stop <container_id or name>
docker stop mittens

# Start a stopped container by ID or name
docker start <container_id or name>
docker start mittens

# Attach to a running container.
docker attach <container_id or name>
docker attach mittens

# get json formatted detailed information about a container
docker inspect <container_id or name>
docker inspect mittens
# parse using grep for interesting fields like so to get a container IP address:
docker inspect mittens | grep IPAddress

# Docker inspect the last container created
docker inspect $(docker ps -qal)

# Docker inspect all containers
docker inspect $(docker ps -qa)

# Delete all images named <none> (untagged images)
delnone() { docker rmi $(docker images | grep none | awk '{print $3}') ;}

# Or another way cleanup all of those untagged images (Those labeled with <none>)
docker images -a
# REPOSITORY                          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
# <none>                              <none>              4008b117428e        17 hours ago        210.2 MB
# <none>                              <none>              53eb80109e88        17 hours ago        210.2 MB
# <none>                              <none>              f48d7a9838a0        17 hours ago        210.2 MB

# If a container is using it or there is a conflict it will abort the current image delta and move on to the next.
docker rmi $(docker images -a | grep "^<none>" | awk '{print $3}')

# Delete all containers matching the passed paramater; e.g. 'delimg foo' deletes all images named 'foo'
delimg() { docker rmi $(docker images | grep $@ | awk '{print $3}') ;}

# to remove a container    
docker rm  <container_id or name>

# to remove all containers, even stopped ones.   
docker rm $(docker ps -aq)

# to stop all containers.   
docker stop $(docker ps -q)

# view the last container to be started
docker ps -l

# Get the container ID column only
docker ps -l -q

# Get the container count of all running containers
docker ps -q | wc -l

# Get the container count of all running and stopped containers
docker ps -qa | wc -l

# stop the last container created
docker stop $(docker ps -l -q) 

# Stop and delete the last container created
docker rm -f `docker ps -ql`
# or
docker ps -l -q | xargs docker stop | xargs docker rm

# delete the container name
docker rm <container_id or name>

# Remove the last container created (running or stopped)
docker rm -f $(docker ps -ql)

# Remove all containers forcefully if they are running -f is nice (fastest)
docker rm -f `docker ps -qa`

# another way to stop and delete the last container created (-f above is still fastest/simplest)
docker ps -l -q | awk '{ print $1 }' | xargs docker stop | awk '{ print $1 }' | xargs docker rm

# remove all containers
docker rm $(docker ps -a -q)
#... or ...
docker ps -a -q | xargs docker rm

# List all network IDs only
docker network ls -q

# Inspect all networks
docker network inspect $(docker network ls -q)

# Delete all networks
docker network rm $(docker network ls -q)'

# When you 'docker run' an image and it fails at runtime, it will appear as Exited for example:"Exited (0) 8 days ago"
 # exiited containers are  refered to as "dangling" images.
 # delete all exited/dangling images
docker rmi $(docker images -q --filter "dangling=true")

# same as above but for containers, remove all Exited/failed containers.
docker rm $(docker ps -q -a  --filter "dangling=true")

 # bind a specific port to the container and host OS.
docker run  -i -t -p 81:80 --name container_name  image_name
80/tcp -> 0.0.0.0:81

# bind a random port to the container and host OS for the "Expose" binding in Dockerfile.
docker run  -i -t  -P --name container_name  image_name
docker port $(docker ps -l -q)

# remove a single image    
docker rmi <image_id>

# return all containers on the host    
docker ps

# stop all running containers (Note: simply replace "grep Up" with whatever column value you want to match on.
docker ps -a | grep Up | awk '{ print $1 }' | xargs docker stop

# delete all containers    
docker rm $(docker ps -a -q)

# delete all containers    
docker rm $(docker ps -a -q)

# image operations are nearly identical to container operations.
docker images | grep some_image_name | awk '{ print $3 }' | xargs docker rmi
 # or ...
docker rmi $(docker images | grep some_image_name | awk '{ print $3 }')
 # Or change the awk operation to the image "tag" column and parse an OS name for example
docker rmi $(docker images | grep centos | awk '{ print $2 }')

# stop and remove all running containers. similar approach due to the consistent API to containers as prior with images. (status=='Up')
docker ps -a | grep Up | awk '{ print $6 }' | xargs docker stop

#stop and delete running containers
docker ps -l -q | awk '{ print $1 }' | xargs docker stop | awk '{ print $1 }' | xargs docker rm

# start all stopped containers (after a reboot for example)
docker start $(docker ps -qa)

#Attach to a bash shell in the last started container
dockexecl() { docker exec -i -t $(docker ps -l -q) bash ;}

#Attach to a bash shell in the specified container ID passed to $ dockexecl <cid>
dockexec() { docker exec -i -t $@ bash ;}

#Get the IP address of all running  containers
docker inspect --format "{{ .NetworkSettings.IPAddress }}" $(docker ps -q)

#Get the IP address of the last started container
docker inspect --format "{{ .NetworkSettings.IPAddress }}" $(docker ps -ql)

# If the network is a network you created simply using grep on docker inspect is quick
$ docker network inspect  mcv1  | grep -i ipv4
       "IPv4Address": "192.168.1.106/24",

# Or look at the gateway of the network
$ docker network inspect  mcv1  | grep Gateway
       "Gateway": "192.168.1.1/24"

# Inspect and parse all IPs for all containers
$ docker inspect $(docker ps -qa) | grep IPA | grep [0-9]
         "IPAddress": "192.168.1.130",
         "IPAddress": "192.168.1.129",
         "IPAddress": "192.168.1.128",

# Example Docker network inspect all network subnets
docker network inspect $(docker network ls -q) | grep "Subnet\|Gateway"
         "Subnet": "172.17.0.0/16",
         "Gateway": "172.17.0.1"
         "Subnet": "172.16.86.0/24",
         "Gateway": "172.16.86.2/24"
         "Subnet": "192.168.1.0/24",
         "Gateway": "192.168.1.1/24"
                    

#stop and delete a container by name
docker stop <image_name> && docker rm flow_img

# Gracefully stop and delete all container
docker rm $(docker stop $(docker ps -aq))

# Kill and delete all containers
docker rm $(docker kill $(docker ps -aq))
```
