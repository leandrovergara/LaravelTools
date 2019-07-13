#!/bin/bash

###############################################################################
# LaravelPermissions
# 
# Comando de modificación de permisos carpeta storage y bootstrap/cache de un 
# software montado en Laravel
# VERSION: v0.2 beta
#
# Leandro Vergara & Kaleb
# 2019-03-27
###############################################################################

# Config ######################################################################
APP_ID="LaravelPermissions v0.2 beta"
APP_DATETIME="2019-03-27"
APP_AUTHOR="Leandro Vergara & Kaleb"

# Rutas
SCRIPT_PATH="$(dirname "$0")"

# Temporal output
TMP_LOG=$( tempfile )

# Herramientas necesarias
ID=$( command -v id )

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
	xecho "    -p, --path RUTA   Directorio de publicación de una aplicación laravel. "
	xecho "    -h, --help        Ayuda sobre el uso de la herramienta."
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

# Parameter control ###########################################################

path="$SCRIPT_PATH"

while [ "$1" != "" ]; do
	case $1 in
		-p | --path)	shift
						path=$1
						;;
		* )				call_for_help
						free_resources
						exit 1
	esac
	shift
done

if [ ! -d "$path" ] ; then 
	xecho "[$( log_ts )] Debe especificar una ruta de publicación de aplicación laravel que sea válida. Ejecute $0 --help para obtener ayuda del uso de la herramienta."
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
path=$( echo $path | sed 's|/$||g' )

path_storage="$path/storage"
path_cache="$path/bootstrap/cache"

xecho "[$( log_ts )] Directorio relativo de script: '$SCRIPT_PATH'"
xecho "[$( log_ts )] Parámetros: "
xecho "[$( log_ts )]     Ruta de publicación: $path"
xecho "[$( log_ts )]     Ruta de storage:     $path_storage"
xecho "[$( log_ts )]     Ruta de cache:       $path_cache"

if [ -d "$path_storage" ] ; then 
	xecho "[$( log_ts )] Modificando permisos para $path_storage ..."
	chmod 777 -R $path_storage/*
	xecho "[$( log_ts )] Listo!"
else
	xecho "[$( log_ts )] El directorio '$path_storage' no existe. Ha utilizado una ruta de aplicación correcta?"
fi

if [ -d "$path_cache" ] ; then 
	xecho "[$( log_ts )] Modificando permisos para $path_cache ..."
	chmod 777 -R $path_cache/*
	xecho "[$( log_ts )] Listo!"
else
	xecho "[$( log_ts )] El directorio '$path_cache' no existe. Ha utilizado una ruta de aplicación correcta?"
fi

xecho "[$( log_ts )] Proceso de asignación de permisos finalizado con éxito."

# Guardo el "last-run" status
script_name=$( basename $0 | sed 's/\.sh$//g' )
cat $TMP_LOG > ${script_name}_lastrun.log

free_resources
