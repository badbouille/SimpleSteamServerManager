# Simple Steam Server Manager

A simple shell script to install, update and start your steam servers.
Works with `tmux`, `ufw`, and `steamcmd`.

## Installation

You will need `steamcmd`, `ufw` and `tmux`.

```
apt update && apt install steamcmd ufw tmux
```

It is recommended to make sure **steamcmd** is working by login manually first.

Don't forget to configure the few variables at the beginning of the file (install dir, steam user, etc).

## Usage

The command is pretty simple to use:

```
# game installation
# game.sh install <gamename> <steam_appid> <ufw_formatted_ports>
# will install the game in the right directory using steamcmd*/
./game.sh install starbound 211820 "21025/tcp"

# game configuration
# game.sh setpath <gamename> <path>
# used to define the command used to launch the game
./game.sh setpath starbound "cd linux/ ; ./starbound_server"

# game launch
# game.sh start <gamename>
# will open the ports and start the server in a tmux session (user is named after the game)
./game.sh start starbound

# game status
# game.sh status <gamename>
# Will check if the gameserver is started or not
./game.sh status starbound

# game console
# game.sh console <gamename>
# Will open the tmux session to type in-game commands
./game.sh console starbound

# game stop
# game.sh stop <gamename>
# will KILL the server (to clean it correctly please do it in the console)
./game.sh stop starbound

```
