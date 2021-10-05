#!/bin/bash
############
#Script to monitor AIS feeds
#LM March 2021
############

##kill all processes on CTRL+C
trap "kill 0" SIGINT

##Check if run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

##Define Client name for log directoy
read -p "Which client is this for? " client 
clientname=${client,,} 

#Define the number of feeds, get names & ports 
read -p "How many feeds do you need to monitor? " feed_no 
if [[ $((feed_no)) != $feed_no ]]; then 
    echo "You must enter an integer, please start again :)"
	  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
else 
    echo "You want to monitor $feed_no feeds."
fi
i=1
name_array=( )
port_array=( )

while [ $i -le $feed_no ]; do
    echo "Please enter AIS name & port number $i that you want to monitor: "
    read -p 'AIS name (no spaces please): ' -r name 
    name_array=("${name_array[@]}" $name) 
    read -p 'Port number: ' -r port
    port_array=("${port_array[@]}" $port)
    i=$(( $i + 1 ))
done
##check number of feeds & ports matches (confirms no whitespaces in arrays)
[ ${#name_array[@]} != ${#port_array[@]} ] && { echo "The number of feeds & ports do not match, please start again :)"; exit 1; }

echo "You want to monitor: "
echo "Names: "${name_array[@]}
echo "Ports: "${port_array[@]}
read -p "Is this correct? " -n 1 -r 
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then

    echo "Working..."
    
##Create log directory
  if [[ ! -e "/tmp/ais_log/$clientname" ]]; then
     mkdir -p "/tmp/ais_log/$clientname"
     echo "Created log directory /tmp/ais_log/$clientname"
  fi
 
##netcat monitor port and write to log file appending timestamp
  numElems=${#name_array[@]}
  pid_array=( )
  for (( i = 0; i < numElems; i++ )); do
    filename="${name_array[i]}";
    sudo nc -l -u "${port_array[i]}" | while read -r l; do echo "$(date -R) $l"; done >> /tmp/ais_log/"$clientname"/"$filename"_ais.log 2>&1 &
    PID=$(($!-1)); echo $filename "is running on PID: "$PID ##most recent PID is the timestamp to logfile so assume one before is nc
    pid_array=("${pid_array[@]}" $PID)  
  done
  echo "PIDs are: "${pid_array[@]} 

##Rotate logs
  #create logrotate config
  if [[ ! -e /etc/logrotate.d/"$clientname" ]]; then 
      touch /etc/logrotate.d/"$clientname" 
  echo "/tmp/ais_log/"$clientname"/*.log {
    missingok
    size 2M
    copytruncate
    create 0664 root root
    rotate 1
    nodateext
    compress
    }" >> /etc/logrotate.d/"$clientname"
  fi 

##Watch for most recent message in log files
    watch -t tail -n 1 /tmp/ais_log/"$clientname"/*.log
 
else
	echo "then please start again :)"
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
