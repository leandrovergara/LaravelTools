#!/bin/bash

###############################################################################
# CreateSchema
# 
# Comando de creación de script SQL para generar base de datos.
# VERSION: v0.2 beta
#
# Leandro Vergara & Kaleb
# 2019-03-27
###############################################################################

# Config ######################################################################
APP_ID="CreateSchema v0.2 beta"
APP_DATETIME="2019-03-27"
APP_AUTHOR="Leandro Vergara & Kaleb"

# Rutas
SCRIPT_PATH="$(dirname "$0")"

# Temporal output
TMP_LOG=$( tempfile )

# Herramientas necesarias
TRUNCATE=$( command -v truncate )
TOUCH=$( command -v touch )

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
	xecho "    $0 -u usuario -p password -d basedatos"
	xecho ""
	xecho "Ayuda:"
	xecho "    -u, --user USUARIO          Identificador de nombre de usuario. "
	xecho "    -p, --password CONTRASEÑA   Contraseña del usuario en texto plano. "
	xecho "    -d, --db BASEDEDATOS        Nombre de la base de datos a generar."
	xecho "    -c, --character-set CHARSET Character-Set de la base de datos a generar."
	xecho "                                Por defecto es 'utf8mb4'."
	xecho "    -o, --collate COLLATION     Collation de la base de datos a generar."
	xecho "                                Por defecto es 'utf8mb4_unicode_ci'."
	xecho "    -r, --no-remote             Deshabilita la creación del usuario remoto."
	xecho "    -h, --help                  Ayuda sobre el uso de la herramienta."
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

if [ "$TRUNCATE" == "" ] ; then
	xecho "[$( log_ts )] ERROR: no se encuentra la herramienta 'truncate'. Abortando..."
	xecho "[$( log_ts )]     Ayuda: pruebe instalarla con 'apt-get install truncate'"
	exit 1
fi
if [ "$TOUCH" == "" ] ; then
	xecho "[$( log_ts )] ERROR: no se encuentra la herramienta 'touch'. Abortando..."
	xecho "[$( log_ts )]     Ayuda: pruebe instalarla con 'apt-get install touch'"
	exit 1
fi

# Parameter control ###########################################################

bd=""
usuario=""
contrasena=""
character_set="utf8mb4"
collation="utf8mb4_unicode_ci"
gen_remote_user="S"

while [ "$1" != "" ]; do
	case $1 in
		-u | --user)		shift
						 	usuario=$1
						 	;;
		-p | --password)	shift
							contrasena=$1
							;;
		-d | --db )			shift
							bd=$1
							;;
		-c | --character-set )	shift
							character_set=$1
							;;
		-o | --collate )	shift
							collation=$1
							;;
		-r | --no-remote )	shift
							gen_remote_user="N"
							;;
		* )					call_for_help
							free_resources
							exit 1
	esac
	shift
done

if [ "$bd" == "" ] ; then 
	xecho "[$( log_ts )] Debe especificar el nombre de la base de datos. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

if [ "$usuario" == "" ] ; then 
	xecho "[$( log_ts )] Debe especificar el usuario. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

if [ "$contrasena" == "" ] ; then 
	xecho "[$( log_ts )] Debe especificar la contraseña del usuario. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
	free_resources
	exit
fi

# Process start ###############################################################

xecho "[$( log_ts )] Directorio relativo de script: '$SCRIPT_PATH'"
xecho "[$( log_ts )] Herramienta 'truncate' encontrada en: '$TRUNCATE'"
xecho "[$( log_ts )] Herramienta 'touch' encontrada en: '$TOUCH'"
xecho "[$( log_ts )] Parámetros: "
xecho "[$( log_ts )]     Usuario:        $usuario"
xecho "[$( log_ts )]     Password:       ********"
xecho "[$( log_ts )]     DB:             $bd"
xecho "[$( log_ts )]     Char-Set:       $character_set"
xecho "[$( log_ts )]     Collate:        $collation"
xecho "[$( log_ts )]     Usuario Remoto: $gen_remote_user"

file="$bd-create-schema.sql"
xecho "[$( log_ts )] Creando archivo $file ..."
$TOUCH $file
$TRUNCATE -s 0 $file
xecho "[$( log_ts )] Listo!"

bd='`'$bd'`'

xecho "[$( log_ts )] Generando esquema..."
echo "# " >> $file
echo "# $APP_ID @ $( log_ts )" >> $file
echo "# " >> $file
echo "# Creación del esquema" >> $file
echo "CREATE SCHEMA IF NOT EXISTS $bd DEFAULT CHARACTER SET $character_set COLLATE $collation;" >> $file
echo "" >> $file
xecho "[$( log_ts )] Listo!"

xecho "[$( log_ts )] Generando creación de usuario local..."
echo "# Creación de usuario local" >> $file
fulluser="'$usuario'@'localhost'"
echo "CREATE USER IF NOT EXISTS $fulluser IDENTIFIED BY '$contrasena';" >> $file
echo "GRANT ALL ON $bd.* TO $fulluser;" >> $file
echo "FLUSH PRIVILEGES;" >> $file
echo "" >> $file
xecho "[$( log_ts )] Listo!"

if [ "$gen_remote_user" == "S" ] ; then
	xecho "[$( log_ts )] Generando creación de usuario para acceso remoto..."
	echo "# Creación de usuario para acceso remoto" >> $file
	fulluser="'$usuario'@'%'" 
	echo "CREATE USER IF NOT EXISTS $fulluser IDENTIFIED BY '$contrasena';" >> $file
	echo "GRANT ALL ON $bd.* TO $fulluser;" >> $file
	echo "FLUSH PRIVILEGES;" >> $file
	xecho "[$( log_ts )] Listo!"
else
	xecho "[$( log_ts )] No se genera creación de usuario para acceso remoto."
fi

xecho "[$( log_ts )] Proceso de generación de base de datos '$bd' finalizado con éxito."
xecho "[$( log_ts )] Archivo generado: $SCRIPT_PATH/$file"

# Guardo el "last-run" status
script_name=$( basename $0 | sed 's/\.sh$//g' )
cat $TMP_LOG > ${script_name}_lastrun.log

free_resources
