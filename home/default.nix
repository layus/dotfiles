{ homeManager, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration (import (./users + "/${name}@${machine}.nix"))
