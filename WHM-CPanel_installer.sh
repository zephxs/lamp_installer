#!/bin/bash

# Exit
die () {
echo  $1
echo "Error Returning.."
return 1
}

# script color
BLX="echo -e \e[36m"
NLMX="echo -e \e[39m"
RDX="echo -e \e[5m \e[95m"

##### WHM INSTALL #####

# vars
#DBROOT_PW=$(cat /root/.my.cnf|grep password|awk -F '=' '{print $2}')

dirsource='/root/CDE-Install'
if [ ! -d "$dirsource" ]; then 
 mkdir -p ${dirsource}/tmp
 mkdir -p ${dirsource}/log
fi
cd $dirsource


##### FUNCTIONS #####

GENPASS () {
tmpass=$(date +%s | sha256sum | base64 | head -c 24 ; echo)
echo $tmpass
}

PRIDOMAIN_SELECT () {
$BLX
echo ""
echo "Choose Primary Domain Name to use :"
$RDX
echo "Press '1' for 'relation-client.fr'"
echo "Press '2' for 'integration-client.fr'"
echo "Press '3' for 'developpement-client.fr'"
read -p " >_  " choiced
  case $choiced in
    "1") DOMX_NAME="relation-client.fr" ;;
    "2") DOMX_NAME="integration-client.fr" ;;
    "3") DOMX_NAME="developpement-client.fr" ;;
    "*") return ;;
  esac
$BLX; echo ""
echo "choosed domain : $DOMX_NAME"
echo ""
echo "Enter CPanel Name : \"STRING\".$DOMX_NAME"
$RDX
  read -p " >_ " CPANX_NAME
$BLX
WHMUSRTEST=$(whmapi1 verify_new_username user=${CPANX_NAME} | grep result|awk '{print $2}')
if [ "$(WHMUSRTEST)" = "1" ]; then
  echo "FQDN will be : ${CPANX_NAME}.${DOMX_NAME}"
else
  echo "CPanel Name is refused by WHM, please try another (maybe shorter)"
  break
fi
$NLMX
DNSTEST=$(dig +short "${CPANX_NAME}.${DOMX_NAME}")
if [ ! -z $DNSTEST ]; then
echo "FQDN already in use,"
echo "Please choose another one."
return
fi
}

ADDONDOMAIN_SELECT () {
$BLX
echo ""
echo "Enter Addon Domain extension : \"STRING\".$DOMX_NAME"
$RDX
read -p " >_ " URL_NAME
$BLX
echo "URL will be : ${URL_NAME}.${DOMX_NAME}"
$NLMX
DNSTEST=$(dig +short "${URL_NAME}.${DOMX_NAME}")

if [ ! -z $DNSTEST ]; then
echo "FQDN already in use,"
echo "Please choose another one."
return
fi

cpapi2 --user=${CPANX_NAME} AddonDomain addaddondomain dir=%2Fpublic_html%2F${WEBROOTY} newdomain=${URL_NAME}.${DOMX_NAME} subdomain=${URL_NAME}
}

logfile="${dirsource}/log/CDE-AutoInstall_$(date +"%H%M-%d-%b-%y")"
cat >> $logfile <<EOF
########################################
################ zephyr ################
####### CDE cPanel Installer 1.4 #######
########################################
########################################

WHM Used = $(hostname)

EOF



INSTALL_OPTIONS () {
$BLX; echo ""
echo "########################################"
echo "################ zephyr ################"
echo "####### CDE cPanel Installer 1.4 #######"
echo "########################################"
echo "########################################"
echo ""
echo ""
echo " Install Options :"
echo "1) Create New CPanel"
echo "2) Install WordPress"
echo "3) Install SuiteCRM"
echo ""
echo "########################################"
$NLMX; echo ""
}


main () {
while true; do
INSTALL_OPTIONS
$RDX
read -p " >_  " launcher
$NLMX
case $launcher in


"1")

PRIDOMAIN_SELECT

CPANX_PASSD () {
cd ${dirsource}/tmp
if [ ! -f "usr_passw" ]; then
  touch usr_passw
fi
$BLX
if [ -s "${dirsource}/tmp/usr_passw" ]; then
  echo "Password already set : "
  $RDX
  cat ${dirsource}/tmp/usr_passw
else
$BLX
  echo "Input Cpanel password or leave blank to generate a new one"
 $RDX
  read -p " >_ " inputpassd
  if [ -z "$inputpassd" ]; then
    GENPASS > ${dirsource}/tmp/usr_passw
  else
    echo "$inputpassd" > ${dirsource}/tmp/usr_passw
  fi
fi
}
CPANX_PASSD
CPANX_PASS=$(<${dirsource}/tmp/usr_passw)
$BLX
echo "choose Package :"
$RDX
echo "Press '1' for 'Default'"
echo "Press '2' for 'Standard illimité'"
read -p " >_ " choicef
case $choicef in
  "1") CPANX_PLAN="default" ;;
  "2") CPANX_PLAN="standard+illimitÃ©" ;;
  "*") return ;;
esac
# INSTALL WHM CPANEL WITH API

whmapi1 createacct username=${CPANX_NAME} domain=${CPANX_NAME}.${DOMX_NAME} plan=${CPANX_PLAN} password=${CPANX_PASS} contactemail=contact@client.com cpmod=paper_lantern maxpark=unlimited maxaddon=unlimited language=fr spf=0 owner=root || return


# php settings
$BLX
echo "Press 'Enter' to set php ini"
read -p " >_ " reply
if [ -z $reply ]; then
#uapi --user=${CPANX_NAME} LangPHP php_ini_get_user_basic_directives type=vhost vhost=${CPANX_NAME}.${DOMX_NAME}
uapi --user=${CPANX_NAME} LangPHP php_set_vhost_versions vhost=${CPANX_NAME}.${DOMX_NAME} version=ea-php56
uapi --user=${CPANX_NAME} LangPHP php_ini_set_user_basic_directives type=vhost directive-1=post_max_size%3A15M directive-2=upload_max_filesize%3A15M directive-3=max_execution_time%3A30 directive-4=max_input_time%3A60 vhost=${CPANX_NAME}.${DOMX_NAME}
fi

cat >> $logfile <<EOF

###################################

Install : $(date)

CPanel User    = "$CPANX_NAME"
CPanel Pass    = "$CPANX_PASS"

Primary Domain = "${CPANX_NAME}.${DOMX_NAME}"

###################################
###################################

EOF
echo ""
echo "Install infos available at $logfile"

;;






  "2") $BLX; echo "######## WORDPRESS INSTALLER ########"
$NLMX; echo ""
$BLX
echo "Choose between thoses cPanel accounts:"
echo ""
$RDX
readarray -t linexy < <(whmapi1 list_users|grep -|awk '{print $2}'|grep -Ev "^$")
echo ""; $RDX
select CPANX_NAME in "${linexy[@]}"; do
  [ -n $CPANX_NAME ] || { echo "Invalid choice. Please try again." >&2; continue; }
  break
done
$BLX
echo "cPanel choosed : $CPANX_NAME"
CPANX_DOM=$(whmapi1 listaccts search=$CPANX_NAME searchtype=user|grep domain|awk '{print $2}')
echo "cPanel domain name is : $CPANX_DOM"
DOMTMP1=$(echo $CPANX_DOM|awk -F '.' '{print $2}')
DOMX_NAME=$(echo "${DOMTMP1}.fr")
echo ""
echo "Create WordPress instance for $CPANX_NAME"
echo "Choose install suffixe (dev, test, prod..) or leave blank :"
$RDX
read -p " >_  " suffix
WEBROOTY="capdemat-internet${suffix}"
WEBROOTX="/home/${CPANX_NAME}/public_html/${WEBROOTY}"
cd ${dirsource}/tmp
#/home/${CPANX_NAME}/public_html/
$BLX
if [ -e wordpress-4.8.7-fr_FR.zip ]; then echo "Wordpress already downloaded"
else
  wget https://fr.wordpress.org/wordpress-4.8.7-fr_FR.zip
fi
$NLMX
unzip wordpress-4.8.7-fr_FR.zip
mv wordpress $WEBROOTX
chown ${CPANX_NAME}:nobody $WEBROOTX
chown -R ${CPANX_NAME}:${CPANX_NAME} $WEBROOTX/.
$BLX
echo "Press 'Enter' to create WordPress User and Database"
$RDX
read -p " >_ " createdb
$BLX
if [ -z $createdb ]; then
echo ""
echo "Enter DB Name: ${CPANX_NAME}_\"STRING\""
$RDX
read -p " >_ " DB_NAMEWPX
DB_NAMEWP=$(echo "${CPANX_NAME}_${DB_NAMEWPX}")
echo ""
echo "DB Name : $DB_NAMEWP"
echo ""
GENPASS > ${dirsource}/tmp/dbpass-wp
DB_PASSWP=$(<${dirsource}/tmp/dbpass-wp)
uapi --user=$CPANX_NAME Mysql create_user name=$DB_NAMEWP password=$DB_PASSWP
uapi --user=$CPANX_NAME Mysql create_database name=$DB_NAMEWP
uapi --user=$CPANX_NAME Mysql set_privileges_on_database user=$DB_NAMEWP database=$DB_NAMEWP privileges=ALL%20PRIVILEGES
fi
$BLX
cat >> ${WEBROOTX}/wp-config-sample.php << EOF

define ( 'AUTOMATIC_UPDATER_DISABLED', true );
EOF

# ADDONDOMAIN_SELECT

# set random admin password for easy setup
WPADMPAS=$(GENPASS)

cat >> $logfile <<EOF

################# WordPress ##################

CPanel Account  = $CPANX_NAME

MYSQL Infos :
- WP User       = $DB_NAMEWP
- WP Database   = $DB_NAMEWP
- WP Password   = $DB_PASSWP

WEB Infos :
- URL  = https://${URL_NAME}.${DOMX_NAME} 
- User = admin
- Pass = $WPADMPAS


EOF
$RDX
cat $logfile
$BLX
echo ""
echo "Install infos available at $logfile"

;;


  "3") $BLX; echo "######### SUITECRM INSTALLER ########"
$NLMX
$BLX
echo "Choose between thoses cPanel accounts:"
echo ""
$RDX
readarray -t linexy < <(whmapi1 list_users|grep -|awk '{print $2}'|grep -Ev "^$")
echo ""; $RDX
select CPANX_NAME in "${linexy[@]}"; do
  [ -n $CPANX_NAME ] || { echo "Invalid choice. Please try again." >&2; continue; }
  break
done
$BLX
echo "cPanel choosed : $CPANX_NAME"
CPANX_DOM=$(whmapi1 listaccts search=$CPANX_NAME searchtype=user|grep domain|awk '{print $2}')
echo "cPanel domain name is : $CPANX_DOM"
DOMTMP1=$(echo $CPANX_DOM|awk -F '.' '{print $2}')
DOMX_NAME=$(echo "${DOMTMP1}.fr")
$NLMX

GRU_PW_CHCK () {
$BLX
if [ ! -f ${dirsource}/tmp/gru_passw ]; then 
  touch ${dirsource}/tmp/gru_passw
fi
if [ -s ${dirsource}/tmp/gru_passw ]; then 
  echo "GRU Password already set : $(cat ${dirsource}/tmp/gru_passw)"
else
  echo "Input Password or leave blank to generate new password"
  echo "and press 'Enter' "
$RDX
  read -p " >_ " inputpassx
  if [ -n "$inputpassx" ]; then 
    echo "$inputpassx" > ${dirsource}/tmp/gru_passw
  else
    GENPASS > ${dirsource}/tmp/gru_passw
  fi
fi
$NLMX
}
GRU_PW_CHCK
GRUPASS=$(<${dirsource}/tmp/gru_passw)

$BLX
echo "Press 'Enter' to create SuiteCRM User and Database"
$RDX
read -p " >_ " createdb
if [ -z $createdb ]; then 
$BLX
echo ""
echo "Enter DB Name: ${CPANX_NAME}_\"STRING\""
$RDX
read -p " >_ " DB_NAMEGX
DB_NAMEGRU=$(echo "${CPANX_NAME}_${DB_NAMEGX}")
$BLX 
echo ""
echo "DB will be : $DB_NAMEGRU"
echo ""
$NLMX
GENPASS > ${dirsource}/tmp/dbpass-gru
DB_PASSGRU=$(<${dirsource}/tmp/dbpass-gru)
uapi --user=$CPANX_NAME Mysql create_user name=$DB_NAMEGRU password=$DB_PASSGRU
uapi --user=$CPANX_NAME Mysql create_database name=$DB_NAMEGRU
uapi --user=$CPANX_NAME Mysql set_privileges_on_database user=$DB_NAMEGRU database=$DB_NAMEGRU privileges=ALL%20PRIVILEGES
fi

cd ${dirsource}/tmp
$BLX
#cd /home/${CPANX_NAME}/public_html/
echo "Create SuiteCRM instance for $CPANX_NAME"
echo "Choose install suffix (dev, test, prod..) or leave blank :"
$RDX
read -p " >_  " suffixgru
WEBROOTY="capdemat-gru${suffixgru}"
WEBROOTX="/home/${CPANX_NAME}/public_html/${WEBROOTY}"

$NLMX
if [ -e v7.9.7.zip ]; then
$BLX
  echo "SuiteCRM zip already downloaded"
$NLMX
else
  wget https://github.com/salesagility/SuiteCRM/archive/v7.9.7.zip
fi
unzip v7.9.7.zip
sleep 1
mv SuiteCRM-7.9.7 $WEBROOTX
#mv $WEBROOTY /home/${CPANX_NAME}/www/
# ADDONDOMAIN_SELECT

cat > ${WEBROOTX}/config_si.php <<EOF
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
    'setup_db_admin_password' => '$DB_PASSGRU',
    'setup_db_admin_user_name' => '$DB_NAMEGRU',
    'setup_db_create_database' => 0,
    'setup_db_database_name' => '$DB_NAMEGRU',
    'setup_db_drop_tables' => 0,
    'setup_db_host_name' => 'localhost',
    'setup_db_pop_demo_data' => false,
    'setup_db_type' => 'mysql',
    'setup_db_username_is_privileged' => true,
    'setup_site_admin_password' => '$GRUPASS',
    'setup_site_admin_user_name' => 'admin',
    'setup_site_url' => 'https://${URL_NAME}.${DOMX_NAME}',
    'setup_system_name' => 'CapDemat SuiteCRM $suffixgru',
  );
EOF

chown $CPANX_NAME:nobody $WEBROOTX
cd $WEBROOTX
chown -R ${CPANX_NAME}:${CPANX_NAME} .
find . -type d -exec chmod 775 {} \;
find . -type f -exec chmod 664 {} \;

php -r "\$_SERVER['HTTP_HOST'] = 'localhost'; \$_SERVER['REQUEST_URI'] = 'install.php';\$_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);require_once 'install.php';";
sleep 1

chown -R ${CPANX_NAME}:nobody $WEBROOTX
cd $WEBROOTX
chown -R ${CPANX_NAME}:${CPANX_NAME} .
chmod -R o+x custom/ cache/ include/ modules/ themes/ service/
chmod -R o+r custom/ cache/ include/ modules/ themes/ service/
find . -type d -exec chmod 775 {} \;
find . -type f -exec chmod 664 {} \;
$BLX
echo "set Folder Permissions > OK"
# correct .htaccess rewrite error with localhost setted sites
#sed -i "s#RewriteBase localhost#RewriteBase /#" .htaccess
sed -i "s#'dir_mode' => 1528,#'dir_mode' => 509,#" config.php
sed -i "s#'file_mode' => 493,#'file_mode' => 509,#" config.php
sed -i "s#'user' => '',#'user' => '$CPANX_NAME',#" config.php
sed -i "s#'group' => '',#'group' => '$CPANX_NAME',#" config.php
sed -i 's/[^[:print:]\t]//g' config.php
echo ""
echo "User Permission settings in config.php > OK"
echo ""
echo "Press 'Enter' to import 2.0 mail templates"
$RDX
read -p " >_ " exmail
if [ -z $exmail ]; then
  if [ ! -f $dirsource/tmp/mail.sql ]; then
wget https://cloud.client.com/index.php/s/xxxx/download -O ${dirsource}/tmp/mail.sql
  fi
mysql -u $DB_NAMEGRU -h localhost -p$DB_PASSGRU $DB_NAMEGRU < ${dirsource}/tmp/mail.sql
fi

chown ${CPANX_NAME}:nobody ${WEBROOTX}

cat >> $logfile <<EOF

############### GRU - SuiteCRM ###############

CPanel Account  = $CPANX_NAME

MYSQL Infos :
- GRU User      = $DB_NAMEGRU
- GRU Database  = $DB_NAMEGRU
- GRU Password  = $DB_PASSGRU

Web Infos :
- URL  = https://${URL_NAME}.${DOMX_NAME} 
- user = admin
- pass = $GRUPASS

EOF
$RDX
cat $logfile
echo ""
$BLX
echo "Install infos available at $logfile"
$NLMX
;;

'*') echo "Exit Auto Installer"
exit 
;;

esac
done
}

main

