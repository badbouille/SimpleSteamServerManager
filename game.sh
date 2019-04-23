#!/bin/bash

#########################################################################################
#											#
# This script is under the MIT license and comes with absolutely no warranty		#
# Usage: /game.sh {start|stop|status|console|install|update|setpath} gamename		#
# see README.md for details								#
#											#
# Author: badbouille									#
#											#
#########################################################################################

# path where all servers are stored
SRV_ROOT="/user/servers"
STEAM_USER="badbouille"
STEAM_LOGIN="badboy72200"
STEAMCMD="steamcmd"

# default empty actions
ACTION="nothing"
GAME="no game"

# auto vars
USR=$(whoami)

# function to check if a tmux session is running for the given game (user)
status () {
	local RES=""
	DIR="$SRV_ROOT/$1"
	RES=$(su - ${1} -c "cd $DIR ; tmux list-sessions 2> /dev/null | grep $1:")
	if [ "$RES" = "" ]
	then
		return 1;
	fi
	return 0;
}

# starts a new tmux session for user {game} and starts the script $DIR/$GAME.sh
start () {
	DIR="$SRV_ROOT/$1"
	if [ ! -x $DIR/$1.sh ]; then echo "ERROR: Game $1 not found. Is it installed ?"; exit 1; fi
	if status $1; then echo "$1 is already running"; exit 1; fi
	ufw allow $1
	su - ${1} -c "cd $DIR ; tmux new-session -d -s $1 './$1.sh' ;"
	touch $DIR/enabled
}

# yeah.. since every game has a different command to stop the server (quit, exit, shutdown, Ctrl+C, ...)
# we just kill the tmux session. WARNING : some data may be lost.
# TODO add softer ways of closing the server
stop () {
	DIR="$SRV_ROOT/$1"
	rm $DIR/enabled
	ufw delete allow $1
	if ! status $1; then echo "$1 is already stopped"; exit 1; fi
	# maybe a bit hardcore...
	su - ${1} -c "tmux kill-session -t $1"
}

# this function simply attaches to the tmux session associated with the game
# calling this function then closing manually the server might be a good idea.
console () {
	if ! status $GAME; then echo "$GAME is not running"; exit 1; fi
	su - ${GAME} -c "cd $DIR ; tmux attach-session -t $GAME"
}

# start all the servers that have the "enabled" file inside their directory
# may be called when the server starts to restart all game servers that were up on the last session
startall () {
	for dir in $SRV_ROOT/*/
	do
		if [ -f ${dir%*/}/enabled ]
		then
			echo "Starting $(basename $dir) ..."
			start $(basename $dir)
		fi
	done
}

# stops all enabled servers
stopall () {
	for dir in $SRV_ROOT/*/
	do
		if [ -f ${dir%*/}/enabled ]
		then
			echo "Stopping $(basename $dir) ..."
			stop $(basename $dir)
		fi
	done
}

# will update a game using steamcmd (or install it if the directory exists)
# steamcmd must be configured in advance and working.
# usually, no password is needed if you already manually logged to steam from this server
# you should never put your password in bash files!
update () {
	GAME="$1"
	DIR="$SRV_ROOT/$GAME"
	if [ ! -f $DIR/infos ]; then
		echo "No such game !"
		exit 1
	fi
	APPID="$(cat $DIR/infos)"
	su - $STEAM_USER -c "$STEAMCMD +login $STEAM_LOGIN +force_install_dir $DIR/ +app_update $APPID validate +exit"
	chown -R $GAME:$STEAM_USER $DIR/
	chmod -R u+rwx,g+rwx,o+xr-w $DIR/
	echo "Update done."
}

# installs a game. This consists on a few steps:
#	- creating user $GAME
#	- creating $GAME folder in the $SRV_ROOT folder to host the game
#	- creating update file that stores the appid (used every time the game is updated)
# 	- creating launch script
#		since every game has a different executable, 
#		we just create a simple $GAME/$GAME.sh script
#		Usually the script contains a simple ./myserver 12 27001 map0 whatever
#		It's just so the script always know how to lauch a game.
#		The lauch script may be edited manually or with the command ./game.sh setpath
#	- creating /etc/ufw/applications.d/$GAME file to open and close needed ports for a game
#		At every launch of a server the ports will be opened 
#		and closed when the stop command is called.
#		Note: you can still "stop" a game server even if already stopped to close the ports
install () {
	GAME="$1"
	DIR="$SRV_ROOT/$GAME"
	APPID="$2"
	PORTS="$3"
	# creating folder
	mkdir $DIR
	# creating user
	useradd --home $DIR $GAME
	# giving him and steam rights to use the directory
	chown -R $GAME:$STEAM_USER $DIR/
	chmod -R u+rwx,g+rwx,o+xr-w $DIR/
	# creating update file
	echo "$APPID" > $DIR/infos
	# creating empty start script
	echo "echo 'Start Script is empty! please tell me how to start the game!'" > $DIR/$GAME.sh
	# installing game
	update $GAME
	# adding rule to allow ports
	echo "[$GAME]\ntitle=$GAME game server\ndescription=$GAME game server\nports=$PORTS\n" > /etc/ufw/applications.d/$GAME
	# making sure steam and $GAME can access the directory
	chown -R $GAME:$STEAM_USER $DIR/
	chmod -R u+rwx,g+rwx,o+xr-w $DIR/
	# the end !
	echo "Server installed."
	echo "Please set up the executable path with 'game setpath' or by editing $GAME.sh script manually"
}

# will stop the server and remove all the files described in install
uninstall () {
	GAME="$1"
	DIR="$SRV_ROOT/$GAME"
	if [ ! -f $DIR/infos ]; then
		echo "No such game !"
		exit 1
	fi
	stop $GAME
	userdel $GAME
	rm -r $DIR
	rm /etc/ufw/applications.d/$GAME
	echo "$GAME uninstalled."
}

# display command usage
usage () {
	echo "Usage: /game.sh {start|stop|status|console|install|update|setpath} gamename"
	exit 1
}

# wrong number of arguments
if [ $# -lt 2 ]
then
	usage
fi

# root needed obviously
if [ $USR != root ]
then
	echo "ERROR: You must be root to use this tool."
	exit 1
fi

# params
ACTION=$1
GAME=$2
CMD=$3
PORT=$4
DIR="$SRV_ROOT/$GAME"

case "$ACTION" in
	start)
		if [ $GAME = "all" ]
		then
			startall
		else
			echo "Starting $GAME"
			start $GAME
			echo "$GAME server started"
		fi
		;;
	stop)
		if [ $GAME = "all" ]
		then
			stopall
		else
			echo "Stopping $GAME"
			stop $GAME
			echo "$GAME server stopped"
		fi
		;;
	status)
		if status $GAME;
		then echo "$GAME is running"
		else echo "$GAME is not running"
		fi
		;;
	console)
		console
		;;
	install)
#		game install starbound 211820 "21025/tcp"
		echo "Installing $GAME"
		if [ $# -lt 4 ]
		then
			echo "game install name appid port/tcp"
		fi
		install $GAME $CMD $PORT
		;;
	update)
		echo "Updating $GAME"
		update $GAME
		;;
	uninstall)
		echo "Uninstalling $GAME"
		uninstall $GAME
		;;
	setpath)
		if [ $# -lt 3 ]
		then
			echo "ERROR: Please specify the path to use"
		else
			if [ ! -f "$DIR/$GAME.sh" ]
			then
				echo "ERROR: Wrong path."
			else
				echo "$CMD" > "$DIR/$GAME.sh"
				echo "New path set !"
			fi
		fi
		;;
	*)
		usage
esac

