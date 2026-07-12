# Dotfiles

This project is meant to contain the specific configurations for applications that can be configured through the home directory of the user.

It will contain a script that will allow for applying the configs for specific applications so that you don't have to have an "all or nothing" clone and manual migration of configs.

## Getting a list of apps that can be configured

Each app will be put within its own directory within the repo, so a simple `ls` will give you a list of all the apps that the `app-config.sh` script will be able to configure.

## Running the app-config.sh script

When cloning to a new system, you will have to change the `app-config.sh` file to be executable:

`chmod +x app-config.sh` (assuming you're within the repo directory).

The script is designed to detect if the directories/files are already within the user's home directory and create a .bak file before migrating the dotfiles configs to the user's home directory.

When the script is removing a config, it will restore the .bak files/directories if they exist once the dotfiles config is removed.

### Running examples

Enabling app configs:

1. `./app-config.sh enable all`
2. `./app-config.sh enable starship`
3. `./app-config.sh enable starship tmux lazyvim`

Disabling (removing) app configs:

1. `./app-config.sh disable all`
2. `./app-config.sh disable startship`
3. `./app-config.sh disable starship tmux lazyvim`
