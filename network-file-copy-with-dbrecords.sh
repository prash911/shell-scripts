#!/bin/bash
#Script to Backup Production Data
#Author : Prashant Singh
#Version :20170306 Adding Key Exchange with remote machine
#Version :20170307 separating remote & local functions


Usage(){
if [ $# -lt 2 ]
then
  echo "For -l Usage: $0 [Option] <source> <destination> " >&2
  echo "For -r Usage: $0 [Option] <source> <destination> <IP>" >&2
  exit $E_NOARGS          # Returns 85 as exit status of script (error code).
fi
}
#---------------------------------------------------------------------------------------------
src=$2
dest=$3
IP=$4
Cwd=`pwd`


#---------------------------------------------------------------------------------------------
function validateIP()
	{
	 local IP=$1
	 local stat=1
	 if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			OIFS=$IFS
			IFS='.'
			ip=($IP)
			IFS=$OIFS
			[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 \
			&& ${ip[0]} -ge 1  && ${ip[3]} -ge 1 ]]
			stat=$?
	fi

	echo $stat

	if [[ $stat -ne 0 ]];then
			echo "Invalid IP Address"
			exit 1
	else echo "Valid Ip"
		ping -c 1 -w 1 -q $IP >& /dev/null
		if [[ $? -eq 0 ]]; then
			echo "$IP exists in Network. "
		else echo "$IP doesnt exists in Network. "
			exit 1
		fi
	fi
}


#---------------------------------------------------------------------------------------------


auth(){
IP=$1
[[ -f $Cwd/.valdt ]] || echo `touch $Cwd/.valdt`
#sed -i "/$IP/d" .valdt  .ssh/known_hosts
valid=`grep $IP $Cwd/.valdt|awk '{print $2}'`


KExch()
{
Pass()
{
read -sp "Please enter the password for $USER@$IP: " passwd 
Known_host=`grep $IP ~/.ssh/known_hosts|awk '{print $1}'`
if [[ -z $Known_host ]]
then echo "$IP not found in know hosts file"
ssh-keyscan $IP >>~/.ssh/known_hosts
sshpass -p "$passwd" ssh-copy-id $IP  
else
sshpass -p "$passwd" ssh-copy-id $IP  
fi
}
#echo $passwd|base64




if [[ $valid != 1 ]]
then
pkey=~/.ssh/id_rsa
        if [[  -f "$pkey" ]]
        then
                echo "Private key  present"
                Pass && echo "$IP 1" >>$Cwd//.valdt
        else
                echo "Private key not present.\nGenerating Private key ... sleep 1"
                `ssh-keygen -f ~/.ssh/id_rsa -q -P ""`
                echo "Private key generated"
                Pass && echo "$IP 1" >>$Cwd//.valdt
        fi
#elif [[ $valid == 0 ]] ;then 
else  echo "Keys already added to $IP"
fi
}
	if [[ $valid == 1 ]]
	then
	  echo 'filecopy'
	else
	   KExch 
	fi


}
# SQl Queries -------------------------------------------------------------------------------




#rm -rf opt/*
echo " " > $Cwd/.files.out
#echo " " > .md5sum.out
echo " " > $Cwd/.sqlout


MYSQL=`which mysql`
DB_USER='mysql'
DB_PASSWD="`echo asd|base64 -d`"
DB_PORT=3306
DB_HOST=''
DB_NAME='filedb'
DB_Table="`echo $IP|tr '.' '_'`"


sqlqry(){
$MYSQL -N -u$DB_USER -p$DB_PASSWD -P$DB_PORT -h$DB_HOST -D$DB_NAME -e "select name,md5sum from $DB_Table where md5sum='$Smd5sum'"
}


Sqlins() {
echo "'$Base', '$Smd5sum', $Ssize, '$Path',,'$dest'"
$MYSQL -N -u$DB_USER -p$DB_PASSWD -P$DB_PORT -h$DB_HOST -D$DB_NAME -e "INSERT INTO $DB_Table ( Name, Md5sum, Size, Source, Destination, Time ) VALUES( '$Base', '$Smd5sum', '$Ssize', '$Path','$dest', NOW())"
}


create_table(){
$MYSQL -N -u$DB_USER -p$DB_PASSWD -P$DB_PORT -h$DB_HOST -D$DB_NAME -e "CREATE TABLE $DB_Table(File_id INT NOT NULL AUTO_INCREMENT,Name VARCHAR(255) NOT NULL, Md5sum VARCHAR(255) NOT NULL,Size INT, Source VARCHAR(255) NOT NULL, Destination VARCHAR(255) NOT NULL, Time TIMESTAMP,PRIMARY KEY ( file_id ))"
}


grep_table(){
$MYSQL -N -u$DB_USER -p$DB_PASSWD -P$DB_PORT -h$DB_HOST -D$DB_NAME -e "show tables"|grep $DB_Table
}


# Local copy function ------------------------------------------------------------------------


localcopy(){
#find  $src -type f   >>$Cwd/.files.out
#Filelist=`cat $Cwd/.files.out`
#	`grep -v -f $Cwd/exclude.txt $Cwd/.files.out` >>$Cwd/.files.out.exclude
#Time=`date +"%D-%T"`
#	Filelist=`cat $Cwd/.files.out.exclude`

echo $Filelist

for SFile in $Filelist
do
        Path=$(dirname $SFile)
        Base=$(basename $SFile)
        Smd5sum=`md5sum $SFile|awk '{print $1}'`
        DFile="$dest/$SFile"
	DB_Table='file_data'
        Ssize=`stat -c %s  $SFile`
#	DBMd5sum=`sqlqry`
	sqlqry >.sqlout
	Filename=`cat .sqlout |awk '{print $1}'`
	DBMd5sum=`cat .sqlout |awk '{print $2}'`
	#RSync="/usr/bin/rsync -aAvRog --out-format="%M %f" --log-file=/tmp/rlog"
	RSync="/usr/bin/rsync -aAvRog --log-file=/tmp/rlog"

if [[ $Smd5sum == $DBMd5sum ]]
   then 
      echo -e "Checksum Matches: \\033[36m $Base \\033[0m Skipped"
       	   if [[ $Base == $Filename ]]
              then echo -e "Filename Matches: \\033[36m $Base \\033[0m Skipped" 
	   fi 
else    
#      echo -e "$Scsum $Path $Base $Time" >>.md5sum.out
#      rsync --progress -apR --log-file=/tmp/rlog $SFile $dest 
	$RSync $SFile $dest |tee -a rsync-output.txt
	exstat="$?"
	if [[ $exstat == 0 ]]
	then   Sqlins
          echo -e "File \\033[32m $Base \\033[0m Copied and Db Updated"
          gzip -f $DFile && echo -e "File \\033[32m $Base \\033[0m gzipped "   || echo -e "\\033[31;1m $Base \\033[0m gzip Failed"
	else  echo -e "\\033[31;1m $Base Copy Failed \\033[0m"
	fi
fi      
done
}


#Remote Copy ---------------------------------------------------------------------------------
remotecopy(){
#find  $src -type f   >>.files.out
#Filelist=`cat .files.out`
#Time=`date +"%D-%T"`


for SFile in $Filelist
do
        Path=$(dirname $SFile)
        Base=$(basename $SFile)
        Smd5sum=`md5sum $SFile|awk '{print $1}'`
        DFile="$dest/$SFile"
        Ssize=`stat -c %s  $SFile`
#       DBMd5sum=`sqlqry`
        sqlqry >.sqlout
        Filename=`cat .sqlout |awk '{print $1}'`
        DBMd5sum=`cat .sqlout |awk '{print $2}'`
	#RSync="/usr/bin/rsync -aAvRog --out-format="%M %f" --log-file=/tmp/rlog"
	RSync="/usr/bin/rsync -aAvRog --log-file=/tmp/rlog"


#       echo Dest file is $DFile
if [[ $Smd5sum == $DBMd5sum ]]
then
       echo -e "Checksum Matches: \\033[36m $Base \\033[0m Skipped"
        if [[ $Base == $Filename ]]
           then echo -e "Filename Matches: \\033[36m $Base \\033[0m Skipped" 
        fi
else
#        echo -e "$Scsum $Path $Base $Time" >>.md5sum.out
        #rsync --progress -apR --log-file=/tmp/rlog $SFile $IP:$dest
	$RSync $SFile $IP:$dest


        exstat="$?"
     if [[ $exstat == 0 ]]
     then Sqlins
          echo -e "File \\033[32m $IP $Base \\033[0m Copied and Db Updated"
          ssh $IP gzip -f $DFile && echo -e "File \\033[32m $Base \\033[0m gzipped " ||echo -e "\\033[31;1m $Base \\033[0m gzip Failed"


     else  echo -e "\\033[31;1m $Base Copy Failed \\033[0m"
     fi
fi
done
}

#---------------------------------------------------------------------------------------------
Start(){
if [[ -z  `grep_table` ]]
then
	echo  "Table doesnt exists..Creating $DB_Table Table"
        create_table &&  grep_table ; remotecopy $src $dest $IP
else
	echo "grep_table exist"
        if [[ $DB_Table == `grep_table` ]]
	then
		remotecopy $src $dest $IP
	fi
fi
}

#SqlIns=$(echo $Insert | $MYSQL -N -u$DB_USER -p$DB_PASSWD -P$DB_PORT -h$DB_HOST -D$DB_NAME)
	#RSync="/usr/bin/rsync -aAvRog --exclude-from=exclude.txt --out-format="%M %f" --log-file=/tmp/rlog"


case "$1" in
  -l)
	Usage $src $dest $IP
    	echo "Starting local copy"
	#RSync="/usr/bin/rsync -aAvRog  --log-file=/tmp/rlog"
	find  $src -type f >>$Cwd/.files.out
	Filelist=`cat $Cwd/.files.out`
	localcopy $src $dest $IP 
    ;;
  -r)	
	Usage $src $dest $IP
	validateIP $IP
	auth $IP
	find  $src -type f >>$Cwd/.files.out
	Filelist=`cat $Cwd/.files.out`
     	Start
    ;;
  -e)
	Usage $src $dest $IP
	find  $src -type f >>$Cwd/.files.out
	echo > .files.out.exclude
	grep -v -f $Cwd/exclude.txt $Cwd/.files.out >>$Cwd/.files.out.exclude
	Filelist=`cat $Cwd/.files.out.exclude`
	#RSync="/usr/bin/rsync -aAvRog  --log-file=/tmp/rlog"
	if [[ -z $IP ]]
	then #echo "IP has no values"
	    	localcopy $src $dest $IP 
	else #echo "$IP"
		validateIP $IP
		auth $IP 
     		Start
	fi
    ;;
   *)
	echo "Usage: $0 [OPTION] <source> <destination>" >&2
        echo "Following are the available Options"
	echo -e "\t -l  To copy files Locally"
	echo -e "\t -r  To copy files to Remote location"
	echo -e "\t -e  To Exclude files from copying.\n\t     Enter the files names in exclude.txt file in same directory"
    exit 2
esac
