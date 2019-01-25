#!/bin/bash

HOST=192.168.1.251
PORT=8161
USER=admin
PASSWORD=admin

monitorid=$1

case $monitorid in
	cacheservice)
		curl -u${USER}:${PASSWORD} http://${HOST}:${PORT}/admin/xml/subscribers.jsp 2> /dev/null |grep -A 11 'cacheservice'|grep 'pendingQueueSize'|awk -F '"' '{print $2}'
	;;
	dbservice)
	;;
		curl -u${USER}:${PASSWORD} http://${HOST}:${PORT}/admin/xml/subscribers.jsp 2> /dev/null |grep -A 11 'cacheservice'|grep 'pendingQueueSize'|awk -F '"' '{print $2}'
	front)
		curl -u${USER}:${PASSWORD} http://${HOST}:${PORT}/admin/xml/subscribers.jsp 2> /dev/null |grep -A 11 'cacheservice'|grep 'pendingQueueSize'|awk -F '"' '{print $2}'
	;;
esac

