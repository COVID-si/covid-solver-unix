# covid-solver-unix
This is the mac/linux universal version of the script used for automated docking in the [Open Science Project COVID-19](https://covid.si)
It is used in conjunction with [covid-solver-queue](https://github.com/COVID-si/covid-solver-queue)

[Windows version](https://github.com/COVID-si/covid-solver-windows)

## Compiling
To use the script as intended covid-solver.sh and RxDock/splitMols.dart have to be compiled with
```
cd /path/to/script
shc -r -f covid-solver.sh -o covid-solver
dart2native RxDock/splitMols.dart -o RxDock/splitMols
```
## Dependencies
* shc [Shell Script Compiler](https://neurobin.org/projects/softwares/unix/shc/) (only for compiling)
* [Dart](https://dart.dev/) (>=2.6) (only for compiling)
* [RxDock](https://rxdock.org/)
* Python 2 (>=2.6)
* curl

## File structure of working installation
```
covid-solver
rxdock.config*
no.update*
RxDock/update.sh
RxDock/splitMols
RxDock/bin - RxDock binary folder
RxDock/lib - RxDock library folder
RxDock/data - RxDock data folder
```
### Target archive
In lieu of minimizing server strain the script expects to get all files pertaining to the target in a zip archive named TARGET_\<target-number>.zip

The inside file structure should be as follows:
```
TARGET_REF_<target-number>.sdf
TARGET_PRO_<target-number>.mol2
TARGET_<target-number>.prm
TARGET_<target-number>.as
htvs.ptc
```

## Optional files
### rxdock.config
When this file is present, the runner skips the startup dialogue and runs automatically with the options preset in the config file.
Structure:
```
threads=<int>
save_output=<bool>
nice=<int>
auto_update=<bool>
```
Threads should be an integer lower or equal to the number of logical cores in your system. This defines how many parallel instances of RxDock will run, by default RxDock uses all processor threads.

Save_output should be TRUE or FALSE. This tells the script if you want to keep the output files or delete them after uploading them to the server, default is FALSE.

Nice should be an integer between -20 and 19. This tells your OS with what priority RxDock should be run, 19 means lowest priority, -20 means highest priority, default is 0. Negative nice values can only be set by root!

Auto_update should be TRUE or FALSE. This tells the script if you want the software to automatically update itself when a new version is found. Default is FALSE, but we recommend setting to TRUE.

### no.update
This prevents the script from checking for updates. This should only be present during developer testing. File can be empty. Create it with touch.
```
touch no.update
```

