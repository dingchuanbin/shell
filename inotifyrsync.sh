src=/usr/local/servers/.uploadfile/
des=upload
rsync_passwd_file=/etc/rsyncd.secrets
ip1=47.91.233.90
desport=1873
user=bileuploadrsync
cd ${src}
/usr/local/bin/inotifywait -mrq --format  '%Xe %w%f' -e modify,create,delete,attrib,close_write,move ./ | while read file
do
        INO_EVENT=$(echo $file |grep -v 'CLOSE_WRITEXCLOSE'| awk '{print $1}')
        INO_FILE=$(echo $file |grep -v 'CLOSE_WRITEXCLOSE'| awk '{print $2}')
        echo "-------------------------------$(date)------------------------------------"
        echo $file
        if [[ $INO_EVENT =~ 'CREATE' ]] || [[ $INO_EVENT =~ 'MODIFY' ]] || [[ $INO_EVENT =~ 'CLOSE_WRITE' ]] || [[ $INO_EVENT =~ 'MOVED_TO' ]]         # 判断事件类型
        then
                echo 'CREATE or MODIFY or CLOSE_WRITE or MOVED_TO'
                rsync -avzcR --port=${desport} --password-file=${rsync_passwd_file} $(dirname ${INO_FILE}) ${user}@${ip1}::${des}
                if [[ $? -eq 0 ]]
                        then
                                rm -rf ${INO_FILE}
                        else
                                echo "${INO_FILE}删除失败"
                fi
        fi
        #删除、移动出事件
        if [[ $INO_EVENT =~ 'DELETE' ]] || [[ $INO_EVENT =~ 'MOVED_FROM' ]]
        then
                echo 'DELETE or MOVED_FROM'
                rsync -avzR --delete --password-file=${rsync_passwd_file} $(dirname ${INO_FILE}) ${user}@${ip1}::${des}
		fi
done