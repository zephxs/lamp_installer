#!/bin/bash

### SETTINGS ###
# working folder
webroot="/var/www"
dirsource="/root/CDE_Sources"
if [ ! -d "$dirsource" ]; then mkdir -p ${dirsource}/{tmp,log,src}; fi
logfile="${dirsource}/log/CDE-AutoInstall_$(date +"%H%M-%d-%b-%y")"
touch $logfile

### INSTALL BASIC TOOLS ###
yum install -y wget unzip yum-utils

### PASSW GEN ###
GENPASS () {
tmpass=$(date +%s | sha256sum | base64 | head -c 24 ; echo)
echo $tmpass
}

### Wordpress variables ###
cde_dbi="capdemat_internet"
cde_usri="cde_int"
cde_passi=$(GENPASS)

### SuiteCRM variables ###
cde_dbg="capdemat_gru"
cde_usrg="cde_gru"
cde_passg=$(GENPASS)

### Jasper variables ###
cde_dbj="capdemat_jas"
cde_usrj="cde_jas"
cde_passj=$(GENPASS)

### NOE variables ###
cde_dbn="capdemat_noe"
cde_usrn="cde_noe"
cde_passn=$(GENPASS)

# script color
BLX="echo -e \e[36m"
NLMX="echo -e \e[39m"
RDX="echo -e \e[5m \e[95m"


$BLX; echo ""
echo "#################### SYSTEM COMPATIBILITY CHECKS #####################"
echo ""
### HOST INFO ###
hostnmx=$(hostname -f)
host_ipx=$(ip a|grep dynamic|awk '{print $2}'|awk -F '/' '{print $1}')
OSVERX=$(cat /etc/os-release|grep "PRETTY_NAME="|awk -F'"' '{print $2}')

SYS_CHECK () {
#### SELINUX ####
$BLX; echo ""
echo "- SELinux mode :"
chkselinux=$(grep "SELINUX=" /etc/selinux/config|tail -n 1)
$RDX; echo " $chkselinux"
$BLX
if [ "$chkselinux" = "SELINUX=enforcing" ]; then
  echo "Press '1' to disable SELinux"
  echo "Press '2' to set to permissive"
  echo "Press Anything else to continue.."
  read -n 1 -p " >_  " choiced
  case $choiced in
    "1") sed -i "s#enforcing#disabled#" /etc/selinux/config ;;
    "2") sed -i "s#enforcing#permissive#" /etc/selinux/config ;;
    "*") return ;;
  esac
fi
$NLMX

### LOCALES ###
chkloc=$(localectl|grep System)
$BLX
if grep -q "fr_FR@euro" <<<"$chkloc"; then
  echo "- Locale set to : "
  $RDX; echo " fr_FR@euro"
  else
  $RDX; echo "Locales are NOT set to fr_FR@euro"
  $BLX; echo "Setting up locale ..."
  $NLMX
  localedef -c -i fr_FR -f UTF-8 fr_FR@euro
  localectl set-locale LANG=fr_FR@euro
fi
echo ""

### HOSTNAME ###
$BLX; echo "- Current Hostname :"
$RDX; echo " $(hostname)"; $BLX
echo ""
echo "Press 'h' to set a new Hostname"
read -n 1 -p " >_ " replyf
if [ "$replyf" = 'h' ]; then
  echo ""
  echo "Please enter desired hostname"
  read -p " >_ " machine_namex
  hostnamectl set-hostname $machine_namex
  systemctl restart network
fi
echo ""
echo ""
$BLX;
echo "Press 'r' to reboot"
read -n 1 -p " >_ " returnx
if [ "$returnx" = 'r' ]; then
  echo ""
  echo "System is rebooting"; sleep 2
  echo ""; $NLMX
  reboot
fi
}

echo "Press 'Enter' to perform System requirements checking"
read -n 1 -p " >_ " replyx
if [ -z "$replyx" ]; then
  SYS_CHECK
fi

### MYSQL ROOT SETTINGS ###
DBROOT_PW_CHCK () {
$BLX; echo ""
if [ ! -f "$dirsource/tmp/db_root_passw" ]; then 
  touch "$dirsource"/tmp/db_root_passw
fi
if [ -s "$dirsource/tmp/db_root_passw" ]; then 
  echo "Mysql root Password already set : "
  cat "$dirsource"/tmp/db_root_passw
else
  echo "Input MYSQL root password or leave blank to generate a new one"
  read -p " >_ " inputpass
  if [ -n "$inputpass" ]; then
    cat "$inputpass" > "$dirsource"/tmp/db_root_passw
  else
    GENPASS > "$dirsource"/tmp/db_root_passw
  fi
fi
$NLMX
}
DBROOT_PW_CHCK
DBROOT_PW=$(<$dirsource/tmp/db_root_passw)

### MYSQL SERVER SELECTION ###
$BLX; echo "If Mysql database Server is NOT located on 'localhost', Press 'm'"
read -n 1 -p " >_ " replyz
if [ "$replyz" = 'm' ]; then echo "Please Input Hostname or IP of the MySQL Server" 
read -p " >_ " mysqldbsrv
echo ""
$RDX; echo "Mysql Server set to : $mysqldbsrv"; $NLMX
else
mysqldbsrv="localhost"
echo ""
$RDX; echo "Mysql Server set to : $mysqldbsrv"; $NLMX
fi

### SERVICES FUNCTIONS ###
SQLVX () { yum list installed|grep mysql|grep server|awk '{print substr($2,0,3);}'; }
PHPVX () { yum list installed|grep php|grep cli|awk '{print substr($2,0,3);}'; }
HTTPVX () { yum list installed|grep httpd|grep -v tools|awk '{print substr($2,0,3);}'; }
HTTPVER () { yum list installed|grep httpd.x|awk '{print $1,$2}'; }
SQLVER () { yum list installed|grep mysql|grep server|awk '{print $1,$2}'; }
PHPVER () { yum list installed|grep php|grep cli|awk '{print $1,$2}'; }


tmpx1=$(echo $PATH|awk -F ":" '{print $1,$2,$3,$4,$5,$6}')
tmpx2(){ for i in $(echo $tmpx1 | tr " " "\n"); do find $i -name "php*"; done }
tmpx2 > $dirsource/tmp/path
#cat path|grep -v "-" > path2
readarray -t xtvar < <(cat $dirsource/tmp/path)
select phpbin in "${xtvar[@]}"; do 
echo "php location : $phpbin"; break; done	


INSTALL_OPTIONS () {
$BLX; echo ""
echo "############################################################"
echo "########################## zephyr ##########################"
echo "#################### CDE Installer 3.0 #####################"
echo "############################################################"
echo "#############################################For Centos7####"
echo ""
echo ""
echo " Service Versions : "
echo " - Mysql  = $(SQLVX)"
echo " - PHP    = $(PHPVX)"
echo " - Apache = $(HTTPVX)"
echo ""
echo ""
echo " Install Options :"
echo "1) Apache - MYSQL - PHP"
echo "2) WordPress"
echo "3) SuiteCRM"
echo "4) JasperReport Server"
echo "5) Talend Runtime ESB"
echo "7) Exit Installer"
echo ""
echo "############################################################"
$NLMX; echo ""
}



main () {

### MAIN CDE INSTALLER SCRIPT ###

cat >> $logfile <<EOF
##################################################################
####################### Recap Installation #######################
####################### CapDemat Evolution #######################
##################################################################

- OS        = $OSVERX
- Hostname  = $hostnmx
- IP        = $host_ipx
- date      = $(date)

######################## Services Versions #######################

- $(SQLVER)
- $(PHPVER)
- $(HTTPVER)

EOF

while true; do
INSTALL_OPTIONS
$BLX; read -p " >_  " launcher
$NLMX
case $launcher in
"1") echo ""
$BLX; echo "####################### MYSQL INSTALLER #######################"
$NLMX; echo ""
retix=$(yum list installed|grep mysql-com)
if [ -z "$retix" ]; then
  $BLX;  echo ""
  echo "Mysql package not detected"
  echo "    ...Installing"
  echo ""; $NLMX
  SQLINST
fi
$BLX; echo ""
if [ "$(SQLVX)" != "5.6" ]; then
  echo "Press 'Enter' to install Mysql Version 5.6"
  read -n 1 -p " >_ " replyx
  if [ -z $replyx ]; then
    echo "... Reinstall"; $NLMX
    yum remove *mysql*
    SQLINST
  fi
fi
$BLX
echo "enable mysql in systemd"
systemctl restart mysql
mysqladmin -u root status > /dev/null 2>&1
if [ "$?" = "0" ]; then
  echo "securing mysql installation"; $NLMX

  cat > $dirsource/tmp/secure_install.sql <<EOF
UPDATE mysql.user SET Password=PASSWORD('$DBROOT_PW') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

  mysql -sfu root < $dirsource/tmp/secure_install.sql

  cat >> $logfile <<EOF

MYSQL Infos :
- Root Password = $DBROOT_PW

EOF

fi

$BLX
echo "#######################################################"
echo "#                                                     #"
echo "#         Installed SQL version : $(SQLVX)                 #"
echo "#                                                     #"
echo "#######################################################"
echo ""
echo ""
$BLX; echo "################ APACHE INSTALLER ###############"	
$NLMX
retx=$(yum list installed|grep httpd)
if [ -z "$retx" ]; then
  $BLX; echo ""
  echo ""
  echo ""
  echo "Apache package not detected"
  echo "Press 'Enter' to install"
  read -n 1 -p " >_ " repliz
  echo ""; $NLMX
  if [ -z $repliz ]; then
  yum install -y httpd
  fi
else
  $BLX; echo ""
  echo "Apache Server already installed"
  echo ""; $NLMX
fi
$BLX
echo "#######################################################"
echo "#                                                     #"
echo "#         Installed HTTPD version : $(HTTPVX)              #"
echo "#                                                     #"
echo "#######################################################"
echo ""
echo ""
echo "################ PHP INSTALLER ###############"	
echo ""
$NLMX

retz=$(yum list installed|grep php)
if [ -z "$retz" ]; then
  $BLX; echo ""
  echo "PHP package not detected"
  echo "Press 'Enter' to install"
  read -n 1 -p " >_ " repliz
  $NLMX; echo ""
  if [ -z $repliz ]; then
  PHPINST
  fi
else
  $BLX; echo ""
  echo "Installed PHP version : $(PHPVX)"
  echo "Press 'Enter' to install another PHP Version"
  read -n 1 -p " >_ " repliz; $NLMX
  if [ -z $repliz ]; then
    yum remove *php*
    PHPINST
  fi
fi
$BLX
echo "Setting PHP ini"
tmpx1=$(echo $PATH|awk -F ":" '{print $1,$2,$3,$4,$5,$6}')
tmpx2(){ for i in $(echo $tmpx1 | tr " " "\n"); do find $i -name "php*"; done }
tmpx2 > $dirsource/tmp/path
#cat path|grep -v "-" > path2
readarray -t xtvar < <(cat $dirsource/tmp/path)
select phpbin in "${xtvar[@]}"; do 
echo "php location : $phpbin"; break; done	

phpiniloc=$($phpbin --ini|grep Loaded|awk '{print $4}')
sed -i 's#^;date.timezone =#date.timezone = "Europe/Paris"#' $phpiniloc
sed -i "s#^Options Indexes FollowSymLinks#Options FollowSymLinks#" $phpiniloc
sed -i "s#^;cgi.fix_pathinfo=1#cgi.fix_pathinfo=0#" $phpiniloc
sed -i "s#^upload_max_filesize = 2M#upload_max_filesize = 100M#" $phpiniloc
sed -i "s#^post_max_size = 8M#post_max_size = 50M#" $phpiniloc
echo "Enable Apache Systemd"
systemctl start httpd.service
systemctl enable httpd.service
echo ""
echo "#######################################################"
echo "#                                                     #"
echo "#           Installed PHP version : $(PHPVX)               #"
echo "#                                                     #"
echo "#######################################################"
echo ""
echo ""
echo "#######################################################"
echo "#                                                     #"
echo "#       MYSQL - PHP - Apache Servers installed        #"
echo "#                                                     #"
echo "#######################################################"
echo ""
echo ""
echo "CENTOS Firewalld settings"
firewall-cmd --add-service=http --permanent && firewall-cmd --add-service=https --permanent; firewall-cmd --reload
$NLMX
cat >> $logfile <<EOF
############ Services Installation ##########

- $(SQLVER)
- $(PHPVER)
- $(HTTPVER)

EOF
;;

"2") $BLX; echo "################## WORDPRESS INSTALLER ##################"
$NLMX; echo ""
apache_user=$(ps aux|grep httpd|grep -m 1 -v root|awk '{print $1}')
if [ ! -d /var/log/capdemat ]; then mkdir /var/log/capdemat; fi
cd $dirsource/tmp
$BLX
if [ -e wordpress-4.8.7-fr_FR.zip ]; then echo "Wordpress already downloaded"
else
  wget https://fr.wordpress.org/wordpress-4.8.7-fr_FR.zip
fi
$NLMX
unzip wordpress-4.8.7-fr_FR.zip
mv wordpress $webroot/$cde_dbi
chown -R $apache_user:$apache_user $webroot/$cde_dbi

$BLX
echo "Press 'Enter' to create WordPress Mysql User and Database"
read -n 1 -p " >_ " replyz
$NLMX
if [ -z "$replyz" ]; then
cat > ${dirsource}/tmp/${cde_dbi}.sql <<EOF
CREATE DATABASE $cde_dbi CHARACTER SET = 'utf8' COLLATE = 'utf8_general_ci';
CREATE USER '$cde_usri'@'localhost' IDENTIFIED BY '$cde_passi';
GRANT ALL ON $cde_dbi.* TO '$cde_usri'@'localhost' IDENTIFIED BY '$cde_passi';
FLUSH PRIVILEGES;
EOF 
mysql -u root -h $mysqldbsrv -p$DBROOT_PW < ${dirsource}/tmp/${cde_dbi}.sql
fi

$BLX
echo "Press 'Enter' to create WordPress vhost"
read -n 1 -p " >_ " replyz
$NLMX
if [ -z "$replyz" ]; then
  if [ -d "/etc/httpd/conf.d" ]; then
  cd /etc/httpd/conf.d/
  $BLX; echo "Creating Vhost conf for Apache"
  else
  echo "Apache Dir not found" && exit; $NLMX
  fi
cat > ${cde_dbi}.conf <<EOF
<VirtualHost *:80>
ServerName $hostnmx
DocumentRoot $webroot/$cde_dbi
DirectoryIndex index.php index.html index.xml index.jsp
ErrorLog /var/log/capdemat/error.capdemat_front.log
CustomLog /var/log/capdemat/access.capdemat_front.log combined
<Directory $webroot/$cde_dbi/>
Options FollowSymLinks
AllowOverride All
</Directory>
</VirtualHost>
EOF
apachectl restart
fi
cd $webroot/$cde_dbi
cat >> wp-config-sample.php << EOF

define ( 'AUTOMATIC_UPDATER_DISABLED', true );
EOF
sed -i 's/[^[:print:]\t]//g' wp-config-sample.php
cat >> $logfile <<EOF

########################### WordPress ############################

MYSQL Infos :
- Root Password = $DBROOT_PW
- WP User       = $cde_usri
- WP Database   = $cde_dbi
- WP Password   = $cde_passi

EOF

;;

  "3") $BLX; echo "################### SUITECRM INSTALLER ##################"
$NLMX
GRU_PW_CHCK () {
$BLX
if [ ! -f "${dirsource}/tmp/gru_passw" ]; then 
 touch ${dirsource}/tmp/gru_passw
fi
if [ -s "$dirsource/tmp/gru_passw" ]; then echo "GRU Password already set : "
  cat ${dirsource}/tmp/gru_passw
else
  echo "Input Password or leave blank to generate new password"
  echo "and press 'Enter' "
  read -p " >_ " inputpassx
  if [ -n "$inputpassx" ]; then cat "$inputpassx" > ${dirsource}/tmp/gru_passw
  else
    GENPASS > ${dirsource}/tmp/gru_passw
  fi
fi
$NLMX
}
GRU_PW_CHCK
GRUPASS=$(<$dirsource/tmp/gru_passw)
apache_user=$(ps aux|grep httpd|grep -m 1 -v root|awk '{print $1}')
if [ ! -d /var/log/capdemat ]; then mkdir /var/log/capdemat; fi

$BLX
echo "Press 'Enter' to create SuiteCRM Mysql User and Database"
read -n 1 -p " >_ " replyz
$NLMX
if [ -z $replyz ]; then
cat > ${dirsource}/tmp/${cde_dbg}.sql <<EOF
CREATE DATABASE $cde_dbg CHARACTER SET = 'utf8' COLLATE = 'utf8_general_ci';
CREATE USER '$cde_usrg'@'localhost' IDENTIFIED BY '$cde_passg';
GRANT ALL ON $cde_dbg.* TO '$cde_usrg'@'localhost' IDENTIFIED BY '$cde_passg';
GRANT ALL ON $cde_dbg.* TO '$cde_usrg'@'%' IDENTIFIED BY '$cde_passg';
FLUSH PRIVILEGES;
EOF
mysql -u root -h $mysqldbsrv -p$DBROOT_PW < ${dirsource}/tmp/${cde_dbg}.sql
fi


$BLX
echo "Press 'Enter' to create Apache Vhost for SuiteCRM"
read -n 1 -p " >_ " replyz
$NLMX
if [ -z $replyz ]; then
  if [ -d "/etc/httpd/conf.d" ]; then
  cd /etc/httpd/conf.d/
  $BLX; echo "Creating Vhost conf for SuiteCRM"
  else
  echo "Apache Dir not found" && exit; $NLMX
  fi
cat > $cde_dbg.conf <<EOF
<VirtualHost *:80>
ServerName $hostnmx
DocumentRoot $webroot/$cde_dbg
DirectoryIndex index.php index.html index.xml index.jsp
ErrorLog /var/log/capdemat/error.capdemat_gru.log
CustomLog /var/log/capdemat/access.capdemat_gru.log combined
<Directory $webroot/$cde_dbg/>
Options FollowSymLinks
AllowOverride All
</Directory>
</VirtualHost>
EOF
apachectl restart
fi

echo "set Firewalld to accept incoming Mysql request (GRU Only)"
firewall-cmd --add-service=mysql --permanent; firewall-cmd --reload

cd $dirsource/src
if [ -e v7.9.7.zip ]; then $BLX; echo "SuiteCRM zip already downloaded"; $NLMX
else
  wget https://github.com/salesagility/SuiteCRM/archive/v7.9.7.zip
fi

unzip v7.9.7.zip
mv SuiteCRM-7.9.7 $webroot/$cde_dbg

cat > $dirsource/tmp/config_si.php <<EOF
<?php
\$sugar_config_si  = array (
    'dbUSRData' => 'create',
    'default_currency_iso4217' => 'EUR',
    'default_currency_name' => 'Euro',
    'default_currency_significant_digits' => '2',
    'default_currency_symbol' => '€',
    'default_date_format' => 'd/m/Y',
    'default_decimal_seperator' => ',',
    'default_export_charset' => 'UTF-8',
    'default_language' => 'fr_FR',
    'default_locale_name_format' => 's f l',
    'default_number_grouping_seperator' => ' ',
    'default_time_format' => 'H:i',
    'export_delimiter' => ',',
    'setup_db_admin_password' => '$cde_passg',
    'setup_db_admin_user_name' => '$cde_usrg',
    'setup_db_create_database' => 0,
    'setup_db_database_name' => '$cde_dbg',
    'setup_db_drop_tables' => 0,
    'setup_db_host_name' => 'localhost',
    'setup_db_pop_demo_data' => false,
    'setup_db_type' => 'mysql',
    'setup_db_username_is_privileged' => true,
    'setup_site_admin_password' => '$GRUPASS',
    'setup_site_admin_user_name' => 'admin',
    'setup_site_url' => 'http://$hostnmx',
    'setup_system_name' => 'CapDemat SuiteCRM',
  );
EOF

cp $dirsource/tmp/config_si.php $webroot/$cde_dbg/
chown -R $apache_user:$apache_user $webroot/$cde_dbg
# install.php?goto=SilentInstall&cli=true
cd $webroot/$cde_dbg
$phpbin -r "\$_SERVER['HTTP_HOST'] = 'localhost'; \$_SERVER['REQUEST_URI'] = 'install.php';\$_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);require_once 'install.php';";
sleep 1
echo "Press:"
echo "'Enter'  =  to install mail templates"
echo " 's'     =  to skip"
read -n 1 -p " >_ " repliz
if [ -z "$repliz" ]; then
wget https://cloud.xxxxx.xxx/index.php/s/xxxx/download -O $dirsource/src/mail.sql
mysql -u root -h $mysqldbsrv -p$DBROOT_PW $cde_dbg < $dirsource/src/mail.sql
fi

chown -R $apache_user:$apache_user $webroot/$cde_dbg
chmod -R o+x custom/ cache/ include/ modules/ themes/ service/
chmod -R o+r custom/ cache/ include/ modules/ themes/ service/
find . -type d -exec chmod 775 {} \;
find . -type f -exec chmod 664 {} \;

# correct .htaccess rewrite error with localhost setted sites
sed -i "s#RewriteBase localhost#RewriteBase /#" .htaccess
sed -i "s#'dir_mode' => 1528,#'dir_mode' => 509,#" config.php
sed -i "s#'file_mode' => 493,#'file_mode' => 509,#" config.php
sed -i "s#'user' => '',#'user' => '$apache_user',#" config.php
sed -i "s#'group' => '',#'group' => '$apache_user',#" config.php
sed -i 's/[^[:print:]\t]//g' config.php

cat >> $logfile <<EOF

######################### GRU - SuiteCRM #########################

MYSQL Infos :
- Root Password = $DBROOT_PW
- GRU User      = $cde_usrg
- GRU Database  = $cde_dbg
- GRU Password  = $cde_passg

Web Infos :
- user     = admin
- password = $GRUPASS

EOF
  ;;


  "4") $BLX; echo "################### JASPER INSTALLER ##################"; $NLMX
# [ -f $tomcat_home/catalina.pid ] && touch $tomcat_home/catalina.pid

yum install -y java-1.7.0-openjdk.x86_64 java-1.7.0-openjdk-headless.x86_64 
yum install -y mysql-connector-java
cd $dirsource/src/
wget http://apache.mirrors.ovh.net/ftp.apache.org/dist/tomcat/tomcat-7/v7.0.94/bin/apache-tomcat-7.0.94.tar.gz
## yum install -y tomcat
tar -zxvf apache*.tar.gz
mv apache-tomcat-7.0.94 /opt/tomcat

java_root=$(find /usr/lib -iname *jdk*|grep 'jvm/'|grep java|grep '1.7')
tomcat_home=$(find / -iname *tomcat*|grep -m 1 "tomcat/bin"|sed 's#/bin.*##g')


cat > $tomcat_home/bin/setenv.sh <<EOF
export CATALINA_HOME="$tomcat_home"
export CATALINA_PID="$tomcat_home/catalina.pid"
export JAVA_HOME="$java_root"
export JRE_HOME="$java_root"
export JAVA_OPTS="\$JAVA_OPTS -Xms1024m -Xmx2048m -XX:PermSize=32m"
export JAVA_OPTS="\$JAVA_OPTS -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC"
export JAVA_OPTS="\$JAVA_OPTS -XX:+CMSClassUnloadingEnabled"
EOF
chmod +x $tomcat_home/bin/setenv.sh
touch $tomcat_home/catalina.pid
cat >> /etc/bashrc <<EOF
export JAVA_HOME=$eava_root/jre
export PATH=\$JAVA_HOME/bin:\$PATH
## ou export PATH=$PATH:$JAVA_HOME/bin sous debian
EOF
source /etc/bashrc
cd $tomcat_home/bin
./startup.sh
sleep 3
tomcat_user=$(ps aux|grep tomcat|grep -m 1 -v root|awk '{print $1}')

cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking

Environment=JAVA_HOME="/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.221-2.6.18.0.el7_6.x86_64"
Environment=CATALINA_PID=/opt/tomcat/catalina.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
export JRE_HOME="/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.221-2.6.18.0.el7_6.x86_64/jre"
export JAVA_OPTS="\$JAVA_OPTS -Xms1024m -Xmx2048m -XX:PermSize=32m"
export JAVA_OPTS="\$JAVA_OPTS -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC"
export JAVA_OPTS="\$JAVA_OPTS -XX:+CMSClassUnloadingEnabled"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/bin/kill -15 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
chmod 664 /etc/systemd/system/tomcat.service 
systemctl daemon-reload
systemctl enable tomcat.service
systemctl start tomcat.service

cd $dirsource/src
if [ ! -e jasper*.zip ]; then
  $BLX; echo "Jasper Reports zip not found in $dirsource/src"
  echo "Press 'Enter' to download"; $NLMX  
  read -n 1 -p " >_ " replyx
  if [ -z "$replyx" ]; then
wget --no-check-certificate https://downloads.sourceforge.net/project/jasperserver/JasperServer/JasperReports%20Server%20Community%20Edition%206.0.1/jasperreports-server-cp-6.0.1-bin.zip
  fi
fi
unzip jasper*.zip
mv jasperreports*/ /opt/jasperreports-server
cd /opt/jasperreports-server/buildomatic
cp sample_conf/mysql_master.properties default_master.properties

#sed -i "s#appServerType =.*#appServerType = tomcat7#" default_master.properties
sed -i "s#appServerDir =.*#appServerDir = $tomcat_home#" default_master.properties
#sed -i "s#dbType =.*#dbType = mysql#" default_master.properties
sed -i "s#dbHost=localhost#dbHost=$mysqldbsrv#" default_master.properties
#sed -i "s#dbUsername=root#dbUsername=root#" default_master.properties
sed -i "s#dbPassword=password#dbPassword=$DBROOT_PW#" default_master.properties
sed -i "s#.*CATALINA_HOME =.*#CATALINA_HOME = $tomcat_home#" default_master.properties
sed -i "s#.*CATALINA_BASE =.*#CATALINA_BASE = $tomcat_home#" default_master.properties
sed -i "s#.*jdbcDriverClass=com.mysql.jdbc.Driver#jdbcDriverClass=com.mysql.jdbc.Driver#" default_master.properties
sed -i "s#.*jdbcDataSourceClass=com.mysql.jdbc.jdbc2.optional.MysqlConnectionPoolDataSource#jdbcDataSourceClass=com.mysql.jdbc.jdbc2.optional.MysqlConnectionPoolDataSource#" default_master.properties
sed -i "s#.*maven.jdbc.groupId=mysql#maven.jdbc.groupId=mysql#" default_master.properties
sed -i "s#.*maven.jdbc.artifactId=mysql-connector-java#maven.jdbc.artifactId=mysql-connector-java#" default_master.properties
sed -i "s#.*maven.jdbc.version=5.1.30-bin#maven.jdbc.version=#" default_master.properties
sed -i 's/[^[:print:]\t]//g' default_master.properties

firewall-cmd --add-port=8080/tcp --permanent; firewall-cmd --reload
systemctl start tomcat.service

$BLX
echo "Press 'Enter' to create Jasper Mysql User and Database"
read -n 1 -p " >_ " replyz
$NLMX
if [ -z "$replyz" ]; then
cat > $dirsource/tmp/$cde_dbj.sql <<EOF
CREATE DATABASE $cde_dbj CHARACTER SET = 'utf8' COLLATE = 'utf8_general_ci';
CREATE USER '$cde_usrj'@'localhost' IDENTIFIED BY '$cde_passj';
GRANT ALL ON $cde_dbj.* TO '$cde_usrj'@'localhost';
FLUSH PRIVILEGES;
EOF
mysql -u root -h $mysqldbsrv -p$DBROOT_PW < $dirsource/tmp/$cde_dbj.sql
fi

cp $(find / -name "mysql-connector-java.jar") /opt/jasperreports-server/buildomatic/conf_source/db/mysql/jdbc/mysql-connector-java-.jar 

$BLX; echo "Install Test"; $NLMX
/opt/jasperreports-server/buildomatic/js-install-ce.sh test 
echo ""
$BLX; echo "If there are no errors, Press 'Enter' to install Jasper Reports"; $NLMX
read -n 1 -p " >_ " replyz
if [ -z $replyz ]; then
  /opt/jasperreports-server/buildomatic/js-install-ce.sh minimal	
else
  return
fi
systemctl restart tomcat.service
echo ""
$BLX; echo "Jasper Reports Installed"
echo "Available under http://$hostnmx:8080/jasperserver"
$NLMX


cat >> $logfile <<EOF

########################### JasperReports ############################

MYSQL Infos :
- Root Password   = $DBROOT_PW
- Jasper User     = $cde_usrj
- Jasper DB       = $cde_dbj
- Jasper Password = $cde_passj

EOF

;;


  "5") $BLX; echo "#################### KARAF INSTALLER ###################"; $NLMX
yum install -y java-1.7.0-openjdk-headless.x86_64
# java-1.7.0-openjdk.x86_64 
java_root=$(find /usr/lib -iname *jdk*|grep 'jvm/'|grep java)
apache_user=$(ps aux|grep httpd|grep -m 1 -v root|awk '{print $1}')
#yum install -y tomcat
cd $dirsource/tmp
if [ ! -e TOS*  ]; then
  $BLX; echo "ESB Archive not found in $dirsource"
  echo "Press 'Enter' to download"; $NLMX
  read -n 1 -p " >_ " replyx
  if [ -z $replyx ];then
  wget https://downloads.sourceforge.net/project/talendesb/Talend%20Open%20Studio%20for%20ESB/6.1.2/TOS_ESB-20160912_1228-V6.1.2.zip
  fi
fi
unzip TOS*.zip
mv Runtime_ESBSE /opt/
chown -R $apache_user:$apache_user /opt/Runtime_ESBSE
cat >> /etc/bashrc <<EOF
export JAVA_HOME=$java_root/jre
export PATH=$PATH:\$JAVA_HOME/bin:
EOF
source /etc/bashrc
/opt/Runtime_ESBSE/container/bin/start
firewall-cmd --service=http --add-port=8040/tcp --permanent; firewall-cmd --reload
$BLX; echo "Karaf is now installed"
echo "Available under http://$hostnmx:8040/system/console/bundles"
$NLMX
;;

  "7") echo "############################################################"
echo "Cleaning $dirsource/tmp"
shred -zvu $dirsource/tmp/*
rm -rf $dirsource/tmp
echo "Exiting..."
exit
;;
  "*") echo "############################################################"
echo "unrecognised choice"
break
;;

esac
done

}

### SUB FUNCTIONS ###
SQLINST () {
$BLX; echo "Install MYSQL 5.6 and dev.mysql.com repository"
echo "Press 'Enter' to install"
read -n 1 -p " >_ " replyx
$NLMX
if [ -z $replyx ]; then
  yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
  yum repolist all|grep mysql
  yum-config-manager --disable mysql80-community
  yum-config-manager --enable mysql56-community
  yum repolist enabled | grep mysql
fi
$BLX; echo ""
echo "check if enabled repo version is correct"
echo "and Press 'Enter' for install"
read -n 1 -p " >_ " replyx
$NLMX
if [ -z $replyx ]; then
  yum install -y mysql-community-server
  su - mysql -c "mysql_install_db"
#  chown -R mysql:mysql /var/lib/mysql
fi
}

PHPINST () {
$BLX; echo "choose PHP Version to install :"
echo "Press '1' to install PHP 5.6"
echo "Press '2' to install PHP 7.0"
read -n 1 -p " >_ " replyx
$NLMX
if [ "$replyx" = "1" ]; then
  yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
  yum install -y php56 php56-php
  yum install -y php56-php-{mcrypt,cli,curl,mbstring,xmlrpc,xml,imagick,soap,mysqli,pdo,zip,mysqlnd,ldap,gd,intl,imap}

fi
if [ "$replyx" = "2" ]; then
  yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
  yum install -y php70 php70-php
  yum install -y php70-php-{mcrypt,cli,curl,mbstring,xmlrpc,xml,imagick,soap,mysqli,pdo,zip,mysqlnd,ldap,gd,intl,imap}
fi
} 

main

