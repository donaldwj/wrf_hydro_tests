#!/bin/bash

## Source this script.
## After informative message: exit on failure with non-zero status.
## Do not exit otherwise.
## KEEP THIS SCRIPT AS GENERAL AS POSSIBLE FOR THE SETUP

###################################
## Establish the file structure
###################################
## Where do all the parts live for the test?
candidateRepoDir=$REPO_DIR/candidate
refRepoDir=$REPO_DIR/reference
if [[ ! -z $candidateLocalPath ]]; then candidateRepoDir=$candidateLocalPath; fi
if [[ ! -z $referenceLocalPath ]]; then refRepoDir=$referenceLocalPath; fi
export candidateRepoDir=$candidateRepoDir
export refRepoDir=$refRepoDir

export toolboxDir=$WRF_HYDRO_TESTS_DIR/toolbox
export answerKeyDir=$WRF_HYDRO_TESTS_DIR/answer_keys

#Binary paths/names
## TODO JLM: evaluate if better names should be used. 
export candidateBinary=$candidateRepoDir/trunk/NDHMS/Run/wrf_hydro.exe
export referenceBinary=$refRepoDir/trunk/NDHMS/Run/wrf_hydro.exe


###################################
## Clone domainRunDir for
## non-docker applications.
###################################
## TODO JLM: also have to tear this down? optionally?
inDocker=FALSE
if [[ -f /.dockerenv ]]; then inDocker=TRUE; fi

if [[ ! -z $domainRunDir ]]; then
    if [[ -e $domainRunDir ]]; then
        chmod -R 755 $domainRunDir
        rm -rf $domainRunDir
    fi
    if [[ "$domainSourceDir" = /* ]]; then
	cp -as $domainSourceDir $domainRunDir
    else
	cp -as `pwd`/$domainSourceDir $domainRunDir
    fi
else
    if [[ $inDocker == "FALSE" ]]; then
	## JLM: this does not catch drives mounted from host into the docker container.
	echo "You are not in docker and you have not specified "
        echo "the \$domainRunDir environment variable. "
        echo "Exiting instead of writing into your \$domainSourceDir."
	exit 1
    fi
    export domainRunDir=$domainSourceDir
fi


###################################
## Setup github authitcation
###################################
doExit=0
if [[ -z ${GITHUB_USERNAME} ]]; then
    echo "The required environment variable GITHUB_USERNAME has 
          not been supplied. Exiting."
    doExit=1
fi
if [[ -z ${GITHUB_AUTHTOKEN} ]] ; then
    echo "The required environment variable GITHUB_AUTHTOKEN has 
          not been supplied. Exiting."
    doExit=1
fi
if [[ $doExit -eq 1 ]]; then exit 1; fi

export authInfo=${GITHUB_USERNAME}:${GITHUB_AUTHTOKEN}

if [[ -z $candidateLocalPath ]]; then
    if [[ -z ${candidateFork} ]]; then export candidateFork=${GITHUB_USERNAME}/wrf_hydro_nwm; fi
    if [[ -z ${candidateBranchCommit} ]]; then export candidateBranchCommit=master; fi
fi
if [[ -z $referenceLocalPath ]]; then
    if [[ -z ${referenceFork} ]]; then export referenceFork=NCAR/wrf_hydro_nwm; fi
    if [[ -z ${referenceBranchCommit} ]]; then export referenceBranchCommit=master; fi
fi


###################################
## Clone candidate fork
###################################
## If running in circleCI, this clone is not necessary. So this section is conditional
## on the CIRCLECI environment variables.
## If running locally, clone specified candidate fork, otherwise in circleCI the current
## PR/Commit is used as candidate.
if [[ -z ${CIRCLECI} ]]; then 
    if [[ -z $candidateLocalPath ]]; then
        if [[ -e $candidateRepoDir ]]; then
            chmod -R 755 $candidateRepoDir
            rm -rf $candidateRepoDir
        fi
        mkdir -p $candidateRepoDir
        cd $candidateRepoDir    
        echo
        echo -e "\e[0;49;32m-----------------------------------\e[0m"
        echo -e "\e[7;49;32mCandidate fork: $candidateFork\e[0m"
	echo -e "\e[7;49;32mCandidate branch/commit: $candidateBranchCommit\e[0m"
        git clone https://${authInfo}@github.com/$candidateFork $candidateRepoDir
        git checkout $candidateBranchCommit || \
            { echo "Unsuccessful checkout of $candidateBranchCommit from $candidateFork."; exit 1; }
        echo -e "\e[0;49;32mRepo moved to\e[0m `pwd`"
        echo -e "\e[0;49;32mCandidate branch:\e[0m    `git rev-parse --abbrev-ref HEAD`"
        echo -e "\e[0;49;32mTesting commit:\e[0m"
        git log -n1 | cat
    else
        cd $candidateLocalPath
        echo
        echo -e "\e[0;49;32m-----------------------------------\e[0m"
        echo -e "\e[7;49;32mCandidate fork: LOCAL: `pwd` \e[0m"
        echo -e "\e[0;49;32mCandidate branch:\e[0m    `git rev-parse --abbrev-ref HEAD`"

        gitDiffInd=`git diff-index HEAD -- `
        if [[ -z $gitDiffInd ]]; then 
            echo -e "\e[0;49;32mTesting commit:\e[0m"
            git log -n1 | cat
        else 
            echo  -e "\e[0;49;32mTesting uncommitted changes.\e[0m"
        fi
        cd - >/dev/null 2>&1
    fi
fi


###################################
## Clone reference fork into repos directory
###################################
## The reference fork can be optional if both $referenceLocalPath and $referenceFork equal ''.
if [[ -z $referenceLocalPath ]]; then
    if [[ ! -z $referenceFork ]]; then
	if [[ -e $refRepoDir ]]; then
            chmod -R 755 $refRepoDir
            rm -rf $refRepoDir
	fi
	mkdir -p $refRepoDir
	cd $refRepoDir
	echo -e "\e[0;49;32m-----------------------------------\e[0m"
	echo -e "\e[7;49;32mReference fork: $referenceFork\e[0m"
	echo -e "\e[7;49;32mReference branch/commit: $referenceBranchCommit\e[0m"
	git clone https://${authInfo}@github.com/$referenceFork $refRepoDir    
	git checkout $referenceBranchCommit || \
            { echo "Unsuccessful checkout of $referenceBranchCommit from $referenceFork."; exit 1; }
	echo -e "\e[0;49;32mRepo in\e[0m `pwd`"
	echo -e "\e[0;49;32mReference branch:\e[0m    `git rev-parse --abbrev-ref HEAD`"
	echo -e "\e[0;49;32mReference commit:\e[0m"
	git log -n1 | cat
    fi
else
    cd $referenceLocalPath
    echo
    echo -e "\e[0;49;32m-----------------------------------\e[0m"
    echo -e "\e[7;49;32mReference fork: LOCAL: `pwd` \e[0m"
    echo -e "\e[0;49;32mReference branch:\e[0m    `git rev-parse --abbrev-ref HEAD`"
    gitDiffInd=`git diff-index HEAD -- `
    if [[ -z $gitDiffInd ]]; then 
        echo -e "\e[0;49;32mTesting commit:\e[0m"
        git log -n1 | cat
    else 
        echo  -e "\e[0;49;32mTesting uncommitted changes.\e[0m"
    fi
    cd - >/dev/null 2>&1
fi


###################################
## Module
###################################
echo
echo -e "\e[0;49;32m-----------------------------------\e[0m"
if [[ ! -z $WRF_HYDRO_MODULES ]]; then
    message="\e[7;49;32mModule information                                           \e[0m"
    echo -e "$message"
    echo "module purge"
    module purge
    echo "module load $WRF_HYDRO_MODULES"
    module load $WRF_HYDRO_MODULES
    module list
else 
    message="\e[7;49;32mConfiguration information:\e[0m"
    echo -e "$message"
    echo
    echo "mpif90 --version:"
    mpif90 --version
    echo 
    echo "nc-config --version --fc --fflags --flibs:"
    nc-config --version --fc --fflags --flibs
fi


###################################
## Compiler / macros
###################################
if [[ $WRF_HYDRO_COMPILER == intel ]]; then
    export MACROS_FILE=macros.mpp.ifort
    mpif90 --version | grep -i intel > /dev/null 2>&1 || {
        echo 'The requested compiler was not found, exiting.'
        exit 1
    }
fi 

if [[ $WRF_HYDRO_COMPILER == GNU ]]; then
    export MACROS_FILE=macros.mpp.gfort
    mpif90 --version | grep -i GNU > /dev/null 2>&1 || {
        echo 'The requested compiler was not found, exiting.'
        exit 1
    }
fi 

echo "mpif90 --version:"
mpif90 --version