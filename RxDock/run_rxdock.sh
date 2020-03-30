#!/bin/bash
#
# This is prototype script for OPENSCIENCE project 
# Prototipna skripta za Citizen Science COVID-19 drug search
# 30.3.2020
#
Version="v0.6"
operatingsys="<mac/linux>" # Only valid options are mac or linux
github_user="<GitHub User>"
github_repo="<GitHub Repo>"
#
FirstLoopFinished=0
#
# Set variables according to selected OS
#
versionCheckAPI="https://api.github.com/repos/$github_user/$github_repo/releases/latest"
if [ $operatingsys = mac ]; then
    threadCheckCommand="sysctl -n hw.ncpu"
elif [ $operatingsys = linux ]; then
    threadCheckCommand="nproc"
else
    echo "Operating system not specified or invalid!"
    echo "Exiting..."
    exit
fi
# Set environment variables
export RBT_ROOT="$PWD/RxDock"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$RBT_ROOT/lib"
export PATH="$PATH:$RBT_ROOT/bin"
# Set API key var
apikey="API key"
server="<server URL>" # DO NOT END WITH A SLASH!!!!!!!!!!!
#
# Check for updates
#
auto_update() {
    if [ $FirstLoopFinished -eq 1 ]; then
        echo "Saving settings..."
        echo $parallels > settings.update
        echo $savdel >> settings.update
        echo $operatingsys >> settings.update
        echo $niceNum >> settings.update
        echo $autoupdate >> settings.update
    fi    
    echo "Attempting auto-update..."
    mv lib/update.sh update.sh
    chmod +x update.sh
    /bin/bash update.sh $github_user $github_repo
    exit
}
version_check() {
    if ! [ -e no.update ]; then
        start_time=$(date +%s)
        currentVersion="$(curl -s $versionCheckAPI | grep tag_name | cut -d '"' -f 4)"
        if ! [ $Version = $currentVersion ] && ! [ $currentVersion = *DOCTYPE* ]; then
            echo "Newer version of script found."
            if [ "$autoupdate" = "true" ]; then
                auto_update
            else
                while true; do
                    read -t 10 -p "Would you like to update? ([Y]es/[n]o) " update_confirmation
                    case $update_confirmation in
                        [Yy]* ) auto_update; break;;
                        [Nn]* ) main_func; break;;
                        * ) echo "Please answer yes or no.";;
                    esac
                done
            fi
        elif [ $currentVersion = *DOCTYPE* ]; then
            echo "Error checking for updates!"
            echo "Continuing..."
        elif [ $Version = $currentVersion ]; then
            echo "You are running the newest version of the script"
        fi
        if [ -e update.sh ]; then
            rm -f update.sh
        fi
    else
        echo "Update block enabled, skipping check..."
    fi
}
#
# Declare main function
#
main_func() {
    #
    # STEP 0. CHECK UPDATES IF TWELVE HOURS HAVE PASSED
    #
    let time_elapsed=$end_time-$start_time
    if [ $time_elapsed -gt 43200 ]; then
        version_check
    fi
    #
    # STEP 1. CHECK THE COUNTER 
    #
    # Get target counter value
    t=$(curl -s --request GET $server/target)
    let tnum=$t
    # Check if there's any targets left on server
    while [ $tnum -eq -1 ]; do
        echo "Ran out of targets for docking"
        echo "We are constantly adding targets to our database"
        echo "The program will continue checking for new targets every 30mins"
        read -t 1800 -p "Press T to [t]erminate script or enter to recheck now..." empty
        case $empty in
            [Tt]*) rm -rf TARGET_PRO_$tnum.mol2 TARGET_REF_$tnum.sdf $fx *.as *.prm temp; exit;;
            *) echo "Rechecking..."; main_func;;
        esac
    done
    # Get structure counter value
    c=$(curl -s --request GET $server/$tnum/counter)
    let cnum=$c
    # Check if there's any structures left on server
    while [ $cnum -eq -1 ]; do
        echo "Ran out of structures to calculate"
        echo "We are constantly adding structures to our database"
        echo "The program will continue checking for new structures every 30mins"
        read -t 1800 -p "Press T to [t]erminate script or enter to recheck now..." empty
        case $empty in
            [Tt]*) rm -rf TARGET_PRO_$tnum.mol2 TARGET_REF_$tnum.sdf $fx *.as *.prm temp; exit;;
            *) echo "Rechecking..."; main_func;;
        esac
    done
    fx="3D_structures_$cnum.sdf"
    #
    # STEP 2. DOWNLOAD A PACKAGE WITH LIGANDS
    #
    while true; do
        curl -s --request GET $server/$tnum/file/down/$cnum --output $fx
        health=$(head -n 1 $fx) # Check if file is healthy
        if [ -e $fx ] && ! [ "$health" = *DOCTYPE* ]; then
            break # Continue if file is healthy
        else
            echo "Error downloading structure!"
            read -t 5 -p "Retrying in 5 sec... [A]bort " hp
            case $hp in
                [Aa]*) rm -rf TARGET_PRO_$tnum.mol2 TARGET_REF_$tnum.sdf $fx *.as *.prm temp; exit;;
                *) echo "Retrying...";;
            esac
        fi
    done
    #
    # STEP 3. DOWNLOAD TARGET
    #
    if [ $FirstLoopFinished -eq 0 ] || ! [ -e TARGET_REF_$tnum.sdf -a -e TARGET_PRO_$tnum.mol2 -a -e TARGET_$tnum.as -a -e TARGET_$tnum.prm -a -e htvs.ptc ]; then
        rm -f TARGET_PRO_$tnum_old.mol2 TARGET_REF_$tnum_old.sdf TARGET_$tnum_old.* htvs.ptc
        while true; do
            curl -s --request GET $server/$tnum/file/target/archive --output TARGET_$tnum.zip
            health=$(head -n 1 TARGET_$tnum.zip) # Check if file is healthy
            if [ -e TARGET_$tnum.zip ] && ! [ "$health" = *DOCTYPE* ]; then
                unzip -o TARGET_$tnum.zip
                rm -f TARGET_$tnum.zip
                break # Continue if file is healthy
            else
                echo "Error downloading target!"
                read -t 5 -p "Retrying in 5 sec... [A]bort " hp
                case $hp in
                    [Aa]*) rm -rf TARGET_PRO_$tnum.mol2 TARGET_REF_$tnum.sdf $fx *.as *.prm temp htvs.ptc; exit;;
                    *) echo "Retrying...";;
                esac
            fi
        done
    fi
    #
    # STEP 4. RUNNING DOCKING WITH RxDock
    #
    echo "Docking package $cnum into target $tnum"
    mkdir -p output
    outfx="output/OUT_T$tnum"'_'"$cnum"
    target_prm=TARGET_$tnum.prm
    # PRM file generation
    # Split the compound file for multiple threads
    mkdir -p temp
    RxDock/splitMols.sh $fx $parallels temp/split
    # Run RxDock
    for file in temp/split*sd
    do
        nice -n $niceNum rbdock -r $target_prm -p dock.prm -f htvs.ptc -i $file -o ${file%%.*}_out &
    done
    wait
    for file in temp/*_out*
    do
        cat $file >> $outfx.sdf
    done
    #
    # STEP 5. UPLOAD RESULTS TO SERVER
    #
    echo "Uploading package $cnum for target $tnum"
    curl -s --request POST -F "data=@$outfx.sdf" -F "apikey=$apikey" $server/$tnum/file/$cnum
    #
    # STEP 6. CLEANUP
    #
    rm -rf $fx temp
    if [ "$savdel" = "d" ]; then
        rm -f $outfx.sdf
    fi
end_time=$(date +%s)
FirstLoopFinished=1
redo
} # End main function

redo() {
    read -t 10 -p "Would you like to calculate the next package? (Y/n) " yn
    case $yn in
        [Yy]* ) tnum_old=$tnum; main_func;;
        [Nn]* ) rm -rf TARGET_PRO_$tnum.mol2 TARGET_REF_$tnum.sd $fx *.as *.prm temp htvs.ptc; exit;;
        * ) main_func;;
    esac
    main_func
}

#
# User input dialogue
#
start_dialogue() {
    echo "Welcome to the CITIZEN SCIENCE COVID-19 $Version"
    # Check threads
    threads=$($threadCheckCommand)
    if [ $threads -gt 0 ]; then
        echo "Your current machine has $threads available threads"
        while true; do
            read -p "Please enter how many threads you would like this software to use (1-$threads/[A]ll) " thread_count
            if [ "$thread_count" = "A" ] || [ "$thread_count" = "All" ] || [ "$thread_count" = "all" ] || [ "$thread_count" = "a" ]; then
                parallels="$threads"
                break;
            elif [ "$thread_count" = "" ]; then
                parallels="$threads"
                break;
            elif ! [ $thread_count -gt $threads ] && [ $thread_count -gt 0 ]; then
                parallels="$thread_count"
                break;
            else
                echo "Please enter a valid number of cores"
            fi
        done
    else
        while true; do
            read -p "Cannot determine available threads, would you like to continue with all processing power? (Y/n) " yn
            case $yn in
                [Yy]* ) parallels=""; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
    if [ $FirstLoopFinished -eq 0 ]; then
        while true; do
            echo "You can set a priority for this software, to make it less obtrusive"
            read -p "Enter a number between -20 (highest) and 19 (lowest priority); default is 0 " nice_level
            if [ "$nice_level" -gt -21 ] && [ "$nice_level" -lt 20 ]; then
                niceNum=$nice_level
                break
            else
                niceNum=0
                break
            fi
        done
        while true; do
            read -p "Would you like to keep the RxDock output files? ([Y]es/[n]o) " savdel
            case $savdel in
                [Yy]* ) savdel="s"; main_func; break;;
                [Nn]* ) savdel="d"; main_func; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

#
# *** PROGRAM START *** #
#
version_check
if [ -e temp/*split*.sd ]; then
    rm -f temp/*split*.sd
fi
if [ -e settings.update ]; then
    FirstLoopFinished=1
    start_time=$(date +%s)
    parallels="$(head -n 1 settings.update)"
    savdel="$(sed '2q;d' settings.update)"
    niceNum="$(sed '3q;d' settings.update)"
    autoupdate="$(sed '4q;d' settings.update)"
    rm -f settings.update
    main_func
elif [ -e rxdock.config ]; then
    start_time=$(date +%s)
    parallels="$(cat rxdock.config | grep threads | cut -d '=' -f 2)"
    if [[ $parallels =~ ^[0-9]+$ ]] && ! [ $parallels -gt $(threadCheckCommand) ]; then 
        if [[ "$(cat rxdock.config | grep save_output | cut -d '=' -f 2)" = [Tt][Rr][Uu][Ee] ]]; then    
            savdel="s"
        else
            savdel="d"
        fi
        if [[ "$(cat rxdock.config | grep auto_update | cut -d '=' -f 2)" = [Tt][Rr][Uu][Ee] ]]; then    
            autoupdate="true"
        else
            autoupdate="false"
        fi
        nice_level="$(cat rxdock.config | grep nice_level | cut -d '=' -f 2)"
        if [ $nice_level -gt -21 ] && [ $nice_level -lt 20 ]; then
            niceNum=$nice_level
            main_func
        else
            niceNum=0
            main_func
        fi
    else
        parallels="$(threadCheckCommand)"
        if [[ $parallels =~ ^[0-9]+$ ]]; then
            main_func
        else
            echo "Error in config file!"
            exit
        fi
    fi
else
    start_dialogue
fi
#
#
# EoF