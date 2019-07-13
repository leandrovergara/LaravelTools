#!/bin/bash

###############################################################################
# GenerateLaravelSite
# 
# Comando de creación de configuración para sitios Laravel con su configuración 
# completa en APACHE.
# VERSION: v0.2 beta
#
# Leandro Vergara & Kaleb
# 2019-03-27
###############################################################################

# Config ######################################################################
APP_ID="GenerateLaravelSite v0.2 beta"
APP_DATETIME="2019-03-27"
APP_AUTHOR="Leandro Vergara & Kaleb"

# Rutas
SCRIPT_PATH="$(dirname "$0")"

# Temporal output
TMP_LOG=$( tempfile )

# Herramientas necesarias
ID=$( command -v id )
SYSTEMCTL=$( command -v systemctl )
A2ENSITE=$( command -v a2ensite )

# Functions ###################################################################
function xecho () 
{
	echo -e "$1" 2>&1 | tee --append $TMP_LOG
}

function header
{
	xecho "----------------------------------------"
	xecho "$APP_ID"
	xecho "----------------------------------------"
	xecho "$APP_AUTHOR"
	xecho "$APP_DATETIME"
	xecho "----------------------------------------"
	xecho ""
}

function call_for_help
{
	xecho "Uso:"
	xecho "    $0 -s mysite -u myuser"
	xecho ""
	xecho "Ayuda:"
	xecho "    -s, --site SITIO    Identificador del sitio."
	xecho "    -u, --user USUARIO  Identificador del usuario que contendrá en su 'home'"
	xecho "                        el directorio generado por laravel para la aplicación."
	xecho "    -h, --help          Ayuda sobre el uso de la herramienta."
	xecho ""
}

function log_ts
{
	echo "$( date "+%Y-%m-%d %H:%M:%S" )"
}

function free_resources
{
	xecho "[$( log_ts )] Liberando recursos..."
	if [ -f $TMP_LOG ] ; then rm $TMP_LOG ; fi
	xecho "[$( log_ts )] Listo!"
}


###############################################################################
# Entry point #################################################################
###############################################################################

# Cabecera ####################################################################
header

# Solo una unica instancia corriendo por vez ##################################
if [[ "`pidof -x $(basename $0) -o %PPID`" ]] ; then
	xecho "[$( log_ts )] $0 ya se encuentra en ejecución con PID `pidof -x $(basename $0) -o %PPID`. Abortando..."
	free_resources
	exit
fi

# Requerimientos ##############################################################

if [ "$ID" == "" ] ; then
	xecho "[$( log_ts )] ERROR: no se encuentra la herramienta 'id'. Abortando..."
	xecho "[$( log_ts )]     Ayuda: pruebe instalarla con 'apt-get install id'"
	exit 1
fi

if [ "$SYSTEMCTL" == "" ] ; then
	xecho "[$( log_ts )] ERROR: no se encuentra la herramienta 'systemctl'. Abortando..."
	xecho "[$( log_ts )]     Ayuda: pruebe instalarla con 'apt-get install systemctl'"
	exit 1
fi

if [ "$A2ENSITE" == "" ] ; then
	xecho "[$( log_ts )] ERROR: no se encuentra la herramienta 'a2ensite'. Abortando..."
	xecho "[$( log_ts )]     Ayuda: pruebe instalarla con 'apt-get install apache2'"
	exit 1
fi

# Parameter control ###########################################################

sitename=""
usuario=""

while [ "$1" != "" ]; do
	case $1 in
		-s | --site)	shift
						sitename=$1
						;;
		-u | --user)	shift
						usuario=$1
						;;
		* )				call_for_help
						free_resources
						exit 1
	esac
	shift
done

if [ "$usuario" == "" ] ; then 
	xecho "[$( log_ts )] Debe especificar el usuario contenedor de la aplicación. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

if [ ! -d "/home/$usuario" ] ; then
	xecho "[$( log_ts )] No se encuentra el directorio '/home/$usuario'. Es posible que el usuario no exista o no disponga de directorio 'home'."
	free_resources
	exit
fi

if [ "$sitename" == "" ] ; then 
	xecho "[$( log_ts )] Debe especificar el identificador del sitio. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

if [ -d "/home/$usuario/$sitename" ] ; then
	xecho "[$( log_ts )] El directorio '/home/$usuario/$sitename' ya existe. Seleccione otro identificador de sitio o bien borre el ya existente."
	free_resources
	exit
fi	

if [[ $($ID -u) -ne 0 ]] ; then
	xecho "[$( log_ts )] Debe ejecutar la herramienta como 'root'. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

# Process start ###############################################################

# Fix barra al final del path
xecho "[$( log_ts )] Directorio relativo de script: '$SCRIPT_PATH'"
xecho "[$( log_ts )] Parámetros: "
xecho "[$( log_ts )]     Sitio:   $sitename"
xecho "[$( log_ts )]     Usuario: $usuario"

xecho "[$( log_ts )] Creando directorio '/home/$usuario/$sitename' ..."
mkdir /home/$usuario/$sitename
chown $usuario:$usuario /home/$usuario/$sitename
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Creando enlace simbólico en directorio de publicación: '/var/www/$sitename' --> '/home/$usuario/$sitename' ..."
ln -s /home/$usuario/$sitename /var/www/
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Creando archivo de configuración para Apache: '/etc/apache2/sites-available/$sitename.conf' ..."
apache_conf_file="/etc/apache2/sites-available/$sitename.conf"
echo "# " >> $apache_conf_file
echo "# $APP_ID @ $( log_ts )" >> $apache_conf_file
echo "# " >> $apache_conf_file
echo "<VirtualHost *:80>" >> $apache_conf_file
echo "        ServerName $sitename" >> $apache_conf_file
echo "        ServerAdmin webmaster@localhost" >> $apache_conf_file
echo "        DocumentRoot /var/www/$sitename/public" >> $apache_conf_file
echo "        ErrorLog /var/log/apache2/$sitename/error.log" >> $apache_conf_file
echo "        CustomLog /var/log/apache2/$sitename/access.log combined" >> $apache_conf_file
echo "        <Directory /var/www/$sitename/public>" >> $apache_conf_file
echo "            Options Indexes FollowSymLinks MultiViews" >> $apache_conf_file
echo "            AllowOverride all" >> $apache_conf_file
echo "            Order allow,deny" >> $apache_conf_file
echo "            allow from all" >> $apache_conf_file
echo "        </Directory>" >> $apache_conf_file
echo "    	<FilesMatch \.php$>" >> $apache_conf_file
echo '     		SetHandler "proxy:unix:/var/run/php/php7.2-fpm.sock|fcgi://localhost/"' >> $apache_conf_file
echo "    	</FilesMatch>" >> $apache_conf_file
echo " </VirtualHost>" >> $apache_conf_file
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Activando sitio en Apache: '/etc/apache2/sites-available/$sitename.conf' ..."
$A2ENSITE $sitename.conf
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Creando directorios de logs para '$sitename' en Apache: '/var/log/apache2/$sitename' ..."
mkdir /var/log/apache2/$sitename
chmod 755 /var/log/apache2/$sitename
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Recargando configuración de Apache ..."
$SYSTEMCTL reload apache2
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] -------------------------------------------------------------------------------"
xecho "[$( log_ts )] Se recomienda agregar $sitename en /etc/hosts:"
xecho "[$( log_ts )] 127.0.0.1     $sitename"
xecho "[$( log_ts )] -------------------------------------------------------------------------------"
xecho "[$( log_ts )] Proceda a inicializar /home/$usuario/$sitename :"
xecho "[$( log_ts )] cd /home/$usuario/$sitename"
xecho "[$( log_ts )] laravel new"
xecho "[$( log_ts )] -------------------------------------------------------------------------------"

xecho "[$( log_ts )] Proceso de configuración finalizado con éxito."

# Guardo el "last-run" status
script_name=$( basename $0 | sed 's/\.sh$//g' )
cat $TMP_LOG > ${script_name}_lastrun.log

free_resources
