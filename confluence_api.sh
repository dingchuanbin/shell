#��������json
cd /opt/deploy/
confluenceuser="dingchuanbin"
confluencepassword="1234Qwer@#"
pagetitle="��������ʵ��"
titleinurl=`echo -n ${pagetitle}|xxd -p|sed 's/../%&/g'`
parentpageId=327964
appversions=`cat /opt/deploy/runningversion`
>.versiontable
for appversion in ${appversions[@]}
        do
                appname=`echo $appversion|awk -F':' '{print $1}'`
                version=`echo $appversion|awk -F':' '{print $2}'`
                echo -e "<tr><td>${appname}</td><td>${version}</td></tr>\c" >>.versiontable
        done
versiontr=`cat .versiontable`
waitupdatestr=`cat .waitupdatestr`
echo $waitupdatestr
#�ж�page�Ƿ��Ѵ���
curl -u $confluenceuser:$confluencepassword -X GET "http://wiki.tjdami.com:8090/rest/api/content?type=page&spaceKey=BBJL&expand=body.storage"|grep '"title":"'$pagetitle >/dev/null
if [[ $? -eq 0 ]]; then
        pageId=`curl -u $confluenceuser:$confluencepassword -X GET "http://wiki.tjdami.com:8090/rest/api/content?title=${titleinurl}&spaceKey=BBJL&expand=history"|python -mjson.tool|grep '"id":'|tail -1|awk -F'"' '{print $(NF-1)}'`
        pageupdatenum=20000
        jsonstring="{\"id\":\"${pageId}\",\"type\":\"page\",\"title\":\"${pagetitle}\",\"space\":{\"key\":\"BBJL\"},\"body\":{\"storage\":{\"value\":\"<p>��ȡҳ��汾</p>\",\"representation\":\"storage\"}},\"version\":{\"number\":\"${pageupdatenum}\"}}"
        pagecurrentnum=`curl -u $confluenceuser:$confluencepassword -X PUT -H 'Content-Type: application/json' -d "${jsonstring}" http://wiki.tjdami.com:8090/rest/api/content/${pageId} | python -mjson.tool|grep message|awk '{print $NF}'|awk -F'"' '{print $1}'`
        pageupdatenum=$((${pagecurrentnum} + 1))
        jsonstring="{\"id\":\"${pageId}\",\"type\":\"page\",\"title\":\"${pagetitle}\",\"space\":{\"key\":\"BBJL\"},\"body\":{\"storage\":{\"value\":\"<p>�������б�</p><p class= \\\"auto-cursor-target\\\"><br /></p><table><colgroup><col /><col /><col /></colgroup><tbody><tr><th>ģ������</th><th>ģ���̰汾</th><th>ʵ�̰汾</th></tr>${waitupdatestr}</tbody></table><br /><p>ʵ�̰汾��¼</p><p class= \\\"auto-cursor-target\\\"><br /></p><table><colgroup><col /><col /></colgroup><tbody><tr><th>ģ������</th><th>���а汾</th></tr>${versiontr}</tbody></table>\",\"representation\":\"storage\"}},\"version\":{\"number\":\"${pageupdatenum}\"}}"
        echo $pageupdatenum
        curl -u $confluenceuser:$confluencepassword -X PUT -H 'Content-Type: application/json' -d "${jsonstring}" http://wiki.tjdami.com:8090/rest/api/content/${pageId} | python -mjson.tool
        if [[ $? -eq 0 ]]; then
                echo ${pageupdatenum} >.pagecurrentnum
        else
                echo "����ҳ��ʧ��"
        fi
else
        jsonstring="{\"type\":\"page\",\"title\":\"${pagetitle}\",\"ancestors\":[{\"id\":\"${parentpageId}\"}],\"space\":{\"key\":\"BBJL\"},\"body\":{\"storage\":{\"value\":\"<p>�������б�</p><p class= \\\"auto-cursor-target\\\"><br /></p><table><colgroup><col /><col /><col /></colgroup><tbody><tr><th>ģ������</th><th>ģ���̰汾</th><th>ʵ�̰汾</th></tr>${waitupdatestr}</tbody></table><br /><p>ʵ�̰汾��¼</p><p class= \\\"auto-cursor-target\\\"><br/></p><table><colgroup><col/><col/></colgroup><tbody><tr><th>ģ������</th><th>���а汾</th></tr>${versiontr}</tbody></table>\",\"representation\":\"storage\"}}}"
        curl -u $confluenceuser:$confluencepassword -X POST -H 'Content-Type: application/json' -d"${jsonstring}" http://wiki.tjdami.com:8090/rest/api/content/ 2>/dev/null| python -mjson.tool
        if [[ $? -eq 0 ]]; then
                echo 1 >.pagecurrentnum
        else
                echo "���ҳ��ʧ��"
        fi
fi