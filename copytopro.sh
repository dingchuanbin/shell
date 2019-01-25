

function findprofilelines(){
projectRowNum=`awk '/'$projectId'/''{print NR}' $filepath`
#projectColNum=`awk '/'$projectId'/''{print NF}' $filepath`
nextprojectRowNum=`awk -v projectColNum=$projectColNum -F ',' '{print $1}' $filepath|awk -v NR=NR -v projectRowNum=$projectRowNum '{if($0!="" && NR>projectRowNum)print NR}'|sed -n '1p'`
if [ ! -n "$nextprojectRowNum" ];
	then 
		totalRowNum=`cat $filepath|wc -l`
		nextprojectRowNum=$[$totalRowNum+1]
	else
		nextprojectRowNum=$nextprojectRowNum
	fi
profiles=`sed -n "$projectRowNum,$[$nextprojectRowNum-1]p" $filepath`
profilelines=`sed -n "$projectRowNum,$[$nextprojectRowNum-1]p" $filepath`
BCNapps=`echo "${profilelines[@]}"|awk -F ',' '{print $3}'|uniq`
for appname in ${BCNapps[@]}
do
	appRowNum=`echo "${profilelines[@]}"|awk '/'$appname,'/''{print NR}'`
	appRowInfo=`echo "${profilelines[@]}"|awk -v appRowNum=$appRowNum 'NR==appRowNum{print}'`
	multiapp=`echo $appRowNum |awk -v appname=$appname '{if($2!="")print appname}'`
	if [ ! -n "$multiapp" ];
		then
			#eval ${appname}_ip=`echo $appRowInfo|awk -F ',' '{print $4}'`
			#eval ${appname}_deployuser=`echo $appRowInfo|awk -F ',' '{print $5}'`
			#eval ${appname}_deploypass=`echo $appRowInfo|awk -F ',' '{print $6}'`
			#eval ${appname}_deploypath=`echo $appRowInfo|awk -F ',' '{print $7}'`
			ip=`echo $appRowInfo|awk -F ',' '{print $4}'`
			user=`echo $appRowInfo|awk -F ',' '{print $5}'`
			pass=`echo $appRowInfo|awk -F ',' '{print $6}'`
			path=`echo $appRowInfo|awk -F ',' '{print $7}'`
			printf "[$appname]\n"
			printf "$ip ansible_ssh_user=$user ansible_ssh_pass=$pass ${appname}_deploypath=$path \n"
		else
			printf "[$multiapp]\n"
			for multiappRowNum in ${appRowNum[@]}
				do
					appRowInfo=`echo "${profilelines[@]}"|awk -v appRowNum=$multiappRowNum 'NR==appRowNum{print}'`
					eval ${appname}_$[$multiappRowNum+$projectRowNum-1]_ip=`echo $appRowInfo|awk -F ',' '{print $4}'`
                        		eval ${appname}_$[$multiappRowNum+$projectRowNum-1]_deployuser=`echo $appRowInfo|awk -F ',' '{print $5}'`
                        		eval ${appname}_$[$multiappRowNum+$projectRowNum-1]_deploypass=`echo $appRowInfo|awk -F ',' '{print $6}'`
                        		eval ${appname}_$[$multiappRowNum+$projectRowNum-1]_deploypath=`echo $appRowInfo|awk -F ',' '{print $7}'`
					ip=`echo $appRowInfo|awk -F ',' '{print $4}'`
					user=`echo $appRowInfo|awk -F ',' '{print $5}'`
					pass=`echo $appRowInfo|awk -F ',' '{print $6}'`
					path=`echo $appRowInfo|awk -F ',' '{print $7}'`
					printf "$ip ansible_ssh_user=$user ansible_ssh_pass=$pass ${multiapp}_deploypath=$path \n"					
				done
	fi
done
}
filepath=BBST.csv
projectIds=`awk -F ',' '{print $1}' $filepath|awk '{if(NR!=1 && $0!="")print}'`
for projectId in ${projectIds[@]}
	do
		findprofilelines
	done
