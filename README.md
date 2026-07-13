# Dotfiles

This project is meant to contain the specific configurations for applications that can be configured through the home directory of the user.

It will contain a script that will allow for applying the configs for the applications where applicable.

For configs that differ from other OS distributions (such as arch/debian), be sure to prefix the config file with the OS ID that can be found on the `ID_LIKE=` line of the `/etc/os-release` file.

For example, the vimrc configs that differ from debian to arch will look like this:

- `scriptDir/vimrc/arch-vimrc`
- `scriptDir/vimrc/debian-vimrc`

The script itself will look at the `/etc/os-release` file on the system running the script and will use the appropriate configs if they are prefixed correctly.
