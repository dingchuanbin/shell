#sysid=essential
#devbranch=v1.1.0
#devversion=1.1.0-SNAPSHOT
#releaseversion=1.1.0
#goaloption=`echo 'release:prepare -DautoVersionSubmodules=true'`
datetime=`date "+%Y%m%d"`
devbuildsdir=/home/dami/JenkinsHome/workspace/builds/releasebuilds/${sysid}_${devversion}
releasebuildsdir=/home/dami/JenkinsHome/workspace/builds/releasebuilds/${sysid}_${releaseversion}
devversionfile=${devbuildsdir}/${devversion}_version.properties
releaseversionfile=${releasebuildsdir}/${releaseversion}_version.properties
changefile=${devbuildsdir}/changeapps
appversion=`mvn -q -N -Dexec.executable="echo"  -Dexec.args='${project.version}' org.codehaus.mojo:exec-maven-plugin:1.3.1:exec`
apptype=`mvn -q -N -Dexec.executable="echo"  -Dexec.args='${project.packaging}' org.codehaus.mojo:exec-maven-plugin:1.3.1:exec`

if [ ! -f  "./pom.xml"  ];
	then
		appname=$2
		svnurl=$SVN_URL
		svnversion=$SVN_REVISION	
	else
		appname=`mvn -q -N -Dexec.executable="echo"  -Dexec.args='${project.name}' org.codehaus.mojo:exec-maven-plugin:1.3.1:exec`
fi
function writeversion(){
	if [ "${goaloption}" == "release:prepare -DautoVersionSubmodules=true" ];
	then
		devversion=`echo $devversion|awk -F '-SNAPSHOT' '{print $1}'`
		devbuildsdir=/home/dami/JenkinsHome/workspace/builds/releasebuilds/${sysid}_${devversion}
		devversionfile=${devbuildsdir}/${devversion}_version.properties
	else
		devversionfile=$devversionfile
	fi
	echo "写入${appname}的SVN号"
	grep "^${appname}=" $devversionfile >/dev/null 2>&1
	if [ $? -eq 0 ] ; 
		then
			sed -i "s|${appname}=.*|${appname}=${svnurl}@${svnversion}|g" $devversionfile
		else
			echo "${appname}=${svnurl}@${svnversion}" >> $devversionfile
	fi
}
function writechange(){
	if [ "${goaloption}" == "release:prepare -DautoVersionSubmodules=true" ];
	then
		devversion=`echo $devversion|awk -F '-SNAPSHOT' '{print $1}'`
		devbuildsdir=/home/dami/JenkinsHome/workspace/builds/releasebuilds/${sysid}_${devversion}
		changefile=${devbuildsdir}/changeapps
	else
		changefile=$changefile
	fi
	##releasebuild写入change
	if [ ! -f  "${changefile}" ];
		then
			echo -e "appname\ttestenvrelease(yes/no)\tmonienvrelease(yes/no)\tproenvrelease" >>$changefile
	fi
	echo "将本次build写入changefile"
	grep -P "^${appname}\t" $changefile >/dev/null 2>&1
        if [ $? -eq 0 ];
		then
			sed -i "s|^${appname}\t.*|${appname}\tno\tno\tno|g" $changefile
		else
			echo -e "\n${appname}\tno\tno\tno" >>$changefile
	fi
}

function ifbuild(){
	result=null	
	if [ "${appversion}" == "${devversion}" ];
	then
		result=0
		
	else
		result=1
	fi
	return $result
}
function compile(){
	result=null
	if [ "${goaloption}" == "release:prepare -DautoVersionSubmodules=true" ];
	then
		rm -rf *
		svn update
		/usr/bin/expect <<\EOF
		set timeout 3000
		set result 2
		spawn mvn release:prepare -DautoVersionSubmodules=true
		expect {
					"*(yes/no)*" { send "yes\r"; exp_continue; }
					"*Dependency type to resolve*(0/1/2/3)*" { send "\r"; exp_continue; }
					"*Dependency 'com.tjdami*is a snapshot*" { send "\r"; exp_continue; }
					"*What version should the dependency be reset to for development*" { send "\r"; exp_continue; }
					"*What is the release version for *parent*" { send "\r"; exp_continue; }
					"*What is SCM release tag or label for *parent*" { send "\r"; exp_continue; }
					"*What is the new development version for *parent*" { send "\r"; exp_continue; }
					"*BUILD SUCCESS*" { set result 0; exp_continue;}
					"*BUILD FAILURE*" { set result 1; exp_continue; }
					eof
			}
			if { $result == 0 } {
					exit 0
				} else {
					exit 1
				}
EOF
	else
		mvn clean install  -Dmaven.test.skip=true findbugs:findbugs
	fi
	if [ $? -eq 0 ] ; then
		result=0
	else
		result=1
	fi
	
	return $result
}


function managedependency(){
	appdeps=`mvn dependency:resolve|grep -v "WARNING"|grep com.tjdami.**:jar|awk -F ":jar:" '{print $1}'|awk -F ':' '{print $NF}'`
	for appdep in ${appdeps[@]}
        do
                appdepreleasesvnversion=`grep "^${appdep}=" ${releaseversionfile}|awk -F '@' '{print $2}'`
                appdepdevsvnversion=`grep "^${appdep}=" ${devversionfile}|awk -F '@' '{print $2}'`
				#evalappdepversion=` mvn dependency:resolve|grep **:${appdep}:jar|awk -F "jar" '{print $2}'|awk -F ':' '{print $1}'`
                if [ "$apptype" == "war" ];
                        then
								unzip -qo target/${warname} -d target/${appname}	
                                if [ "$appdepreleasesvnversion" != "$appdepdevsvnversion" ];
                                        then
                                                echo "依赖包更新$appdep"
                                                rsync -avz target/${appname}-${appversion}/WEB-INF/lib/${appdep}-${appversion}.jar $devbuildsdir/$appname/WEB-INF/lib/
												writeversion
												writechange
                                        else
                                                echo "$appdep依赖包没有更新"
                                fi
                        else
							unzip -qo target/${zipname} -d target/
                            if [ "$appdepreleasesvnversion" != "$appdepdevsvnversion" ];
                                then
									echo "依赖包更新$appdep"
									rsync -avz target/${appname}-${appversion}/libs/${appdep}-${appversion}.jar $devbuildsdir/$appname/libs/
									writeversion
									writechange
								else
									echo "$appdep依赖包没有更新"
                            fi
                fi
        done
}


function managechange(){
changeinfo=`svn diff --old=$svnurl@${releasesvnversion} --new=$svnurl@${devsvnversion} --no-diff-deleted|grep Index:|awk -F ':' '{print $2}'|grep -v "(deleted)"|grep -v "pom.xml"`
deleteinfo=`svn diff --old=$svnurl@${releasesvnversion} --new=$svnurl@${devsvnversion} --no-diff-deleted|grep Index:|awk -F ':' '{print $2}'|grep -e "(deleted)"|grep -v "pom.xml"|awk -F '(' '{print $1}'`

for deletefileinfo in ${deleteinfo[@]}
	do
		deletefile=`echo $deletefileinfo|awk -F '/' '{print $NF}'`
		deletefiletype=`echo $deletefile|awk -F '.' '{print $2}'`
		deletefilename=`echo $deletefile|awk -F '.' '{print $1}'`
		deletefilepath=`echo $deletefileinfo|awk -F "/${deletefilename}" '{print $1}'`
		echo "删除文件：$deletefilepath/$deletefile"
		if [ "$apptype" == "war" ];
			then
				if [ "$deletefiletype" == "java" ];
					then
						deletetargetclasspath=`echo $deletefilepath|awk -F 'java/' '{print $2}'`
						echo "删除$deletetargetclasspath/${deletefilename}.class"	
						rm $devbuildsdir/$appname/WEB-INF/classes/$deletetargetclasspath/${deletefilename}.class
					else
						echo "删除$deletefilepath/$deletefile"
						rm $devbuildsdir/$appname/WEB-INF/classes/$deletefile
						
				fi
			else
				if [ "$deletefiletype" == "java" ];
					then
						echo "删除$deletetargetclasspath/${deletefilename}.class"
						rsync -avz target/${appname}-${appversion}.jar $devbuildsdir/$appname/libs/
					else
						echo "删除$deletefile"
						rm $devbuildsdir/$appname/$deletefile
				fi
		fi
	done
for changefileinfo in ${changeinfo[@]}
	do
		changefileoldversion=`svn diff --old=$svnurl@${releasesvnversion} --new=$svnurl@${devsvnversion} --no-diff-deleted|grep -A 3 Index:|grep -e ---|grep $changefileinfo|awk -F '(' '{print $NF}'|awk -F ')' '{print $1}'|awk -F ' ' '{print $NF}'`
		changefile=`echo $changefileinfo|awk -F '/' '{print $NF}'`
		changefiletype=`echo $changefileinfo|awk -F '/' '{print $NF}'|awk -F '.' '{print $2}'`
		changefilename=`echo $changefileinfo|awk -F '/' '{print $NF}'|awk -F '.' '{print $1}'`
        changefilepath=`echo $changefileinfo|awk -F "/${changefilename}" '{print $1}'`
		
		if [ "$apptype" == "war" ];
			then
				unzip -qo target/${warname} -d target/${appname}	
				if [ "$changefileoldversion" == "0" ];
					then
						if [ "$changefiletype" == "java" ];
							then
								addtargetclasspath=`echo $changefilepath|awk -F 'java/' '{print $2}'`
								echo "新增文件：$addtargetclasspath/${changefilename}.class"
								if [ ! -d "$devbuildsdir/$appname/WEB-INF/classes/$addtargetclasspath" ]; 
									then
										mkdir -p $devbuildsdir/$appname/WEB-INF/classes/$addtargetclasspath
								fi
								rsync -avz target/${appname}-${appversion}/WEB-INF/classes/$addtargetclasspath/${changefilename}.class $devbuildsdir/$appname/WEB-INF/classes/$addtargetclasspath/
							else
								echo "新增文件：$changefile"
								rsync -avz target/${appname}-${appversion}/WEB-INF/classes/$changefile $devbuildsdir/$appname/WEB-INF/classes/
						fi
					else
						if [ "$changefiletype" == "java" ];
							then
								modifytargetclasspath=`echo $changefilepath|awk -F 'java/' '{print $2}'`
								echo "修改文件：$modifytargetclasspath/${changefilename}.class"
								rsync -avz target/${appname}-${appversion}/WEB-INF/classes/$modifytargetclasspath/${changefilename}.class $devbuildsdir/$appname/WEB-INF/classes/$modifytargetclasspath/
							else
								echo "修改文件：$changefile"
								rsync -avz target/${appname}-${appversion}/WEB-INF/classes/$changefile $devbuildsdir/$appname/WEB-INF/classes/
						fi
				fi
			else [ "$apptype" == "jar" ];
				unzip -qo target/${zipname} -d target/
				if [ "$changefileoldversion" == "0" ];
					then
						if [ "$changefiletype" == "java" ];
							then
								addtargetclasspath=`echo $changefilepath|awk -F 'java/' '{print $2}'`
								echo "新增文件：$addtargetclasspath/${changefilename}.class"
								echo "同步整个jar包"
								rsync -avz target/${appname}-${appversion}.jar $devbuildsdir/$appname/libs/
							else
								echo "新增文件：$changefile"
								rsync -avz target/classes/$changefile $devbuildsdir/$appname/
						fi
					else
						if [ "$changefiletype" == "java" ];
							then
								modifytargetclasspath=`echo $changefilepath|awk -F 'java/' '{print $2}'`
								echo "修改文件：$modifytargetclasspath/${changefilename}.class"
								echo "同步整个jar包"
								rsync -avz target/${appname}-${appversion}.jar $devbuildsdir/$appname/libs/
							else
								echo "修改文件：$changefile"
								rsync -avz target/classes/$changefile $devbuildsdir/$appname/
						fi
				fi
		fi		
	done
}


function copybuild(){
	if [ "${goaloption}" == "release:prepare -DautoVersionSubmodules=true" ];
	then
		appversion=`echo $appversion|awk -F '-SNAPSHOT' '{print $1}'`
		devbuildsdir=`echo $devbuildsdir|awk -F '-SNAPSHOT' '{print $1}'`
	else
		appversion=$appversion
	fi
	releasesvnversion=
	warname=`echo target/${appname}-*.war|awk -F '/' '{print $NF}'`
	zipname=`echo target/${appname}-*.zip|awk -F '/' '{print $NF}'`
	if [ ! -d "$devbuildsdir" ]; 
		then
			if [ ! -d "$releasebuildsdir" ];
				then
					mkdir -p $devbuildsdir
					mkdir -p ${devbuildsdir}_config
				else
					rsync -avz --delete $releasebuildsdir/ $devbuildsdir
					rsync -avz --delete ${releasebuildsdir}_config/ ${devbuildsdir}_config
					cp $releaseversionfile $devversionfile
			fi	
	fi
	if [ ! -f "${releaseversionfile}" ];
		then
			releasesvnversion=
		else
			releasesvnversion=`grep ^${appname} ${releaseversionfile}|awk -F '@' '{print $2}'`
	fi
	devsvnversion=$svnversion
	if [ ! -n "${releasesvnversion}" ];
		then
			echo "该应用没有历史发布版本，全量拷贝build"		
			if [ "$apptype" == "war" ];
				then	
					unzip -qo target/${warname} -d target/${appname}					
					rsync -avz --delete target/${appname} ${devbuildsdir}/
					rsync -avz --delete --exclude=.svn config/ ${devbuildsdir}_config/$appname
					writeversion
					writechange
				else
					unzip -qo target/${zipname} -d target/
					rsync -avz --delete target/${appname}-${appversion}/ ${devbuildsdir}/${appname}
					rsync -avz --delete config/ ${devbuildsdir}_config/${appname}
					writeversion
					writechange
			fi
		else		
			managedependency
			if [ $? -eq 0 ];
				then
					echo $devsvnversion
					echo $releasesvnversion
					if [ "$devsvnversion" == "${releasesvnversion}" ];
						then
							echo "本此build的svn号与上次发布版本相同，没有更新"
						else
							managechange
							if [ $? -eq 0 ];
								then
									echo "处理增量更新成功"
								else
									echo "增量更新失败，请查看日志"
									exit 1
							fi
					fi					
				else
					echo "处理依赖jar包更新失败"
					exit 1
			fi		
	fi
}


case "$1" in
	writeversion)
		writeversion
	;;
	*)
		ifbuild
		if [ "$?" == "0" ];
			then
				modules=`awk -F '</module>' '{print $1}' pom.xml|grep -v '<!--'|awk -F '<module>' '{print $2}'|awk 'NF'`
				parentdir=`pwd`
				echo $modules
				for submodule in ${modules[@]}
					do
						cd $parentdir/${submodule}
						modulename=`echo $submodule |sed "s|-||g"`
						eval ${modulename}_svnurl=`svn info|grep "^URL:"|awk -F ': ' '{print $2}'`
						eval ${modulename}_svnversion=`svn info|grep "最后修改的版本:"|awk -F ': ' '{print $2}'`
						eval ${modulename}_apptype=`mvn -q -N -Dexec.executable="echo"  -Dexec.args='${project.packaging}' org.codehaus.mojo:exec-maven-plugin:1.3.1:exec`
					done
				echo "版本一致，开始编译代码"
				cd $parentdir
				compile
				if [ "$?" == "0" ];
					then
						echo "编译成功，开始拷贝应用到builds"
						for submodule in ${modules[@]}
							do					
								echo "==================================${submodule}========================================"
								cd $parentdir/${submodule}
											modulename=`echo $submodule |sed "s|-||g"`
								svnurl=`eval echo '$'"${modulename}_svnurl"`
								svnversion=`eval echo '$'"${modulename}_svnversion"`
								apptype=`eval echo '$'"${modulename}_apptype"`
								appname=$submodule
								warname=`echo target/${appname}-*.war|awk -F '/' '{print $NF}'`
								zipname=`echo target/${appname}-*.zip|awk -F '/' '{print $NF}'`
								if ([ $appname != *-api ] && [ -f  "target/${zipname}" ]) || ([ $appname != *-api ] && [ -f  "target/${warname}" ]);
									then
										echo "非api，执行拷贝build"
										copybuild
										if [ $? -eq 0 ];
											then
												echo "拷贝成功"
											else
												echo "拷贝失败，请查看拷贝日志"
												exit 1
										fi
									else
										echo "api 只需写入版本号"
										writeversion
								fi
							done
						if [ "${goaloption}" == "release:prepare -DautoVersionSubmodules=true" ];
							then
								echo "执行release:perform发布版本"
								cd $parentdir
								mvn release:perform
							else
								echo "end"
						fi
						echo "=================================================================="
					else
						echo "编译失败，请查看编译日志"
						exit 1
				fi
			else
				echo "应用pom定义版本${appversion}和项目开发版本${devversion}不一致，退出编译"
				exit 1
		fi	
	;;
	esac
