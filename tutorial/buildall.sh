#!/bin/bash 
set -e

cleanAll=1
buildAll=1
simAll=0
simSpecific=-1

numTutes=3


function buildTute {
	cd "tute$1"
	if [[ $2 == 1 ]]; then # build and simulate
		echo "simulating tute$1"
		desilog -top tute$1 -tb.vsim tute${1}_tb
	else
		echo "building tute$1"
		desilog -top tute$1
	fi
	cd ..
}

if [[ $cleanAll == 1 ]]; then
	for ((i=0; i < $numTutes; i++))
	do
		if [ -e "tute$i/autogen" ]; then
			echo "cleaning tute$i"
			rm -r "tute$i/autogen"
		fi
	done
fi


if [[ $buildAll == 1 ]]; then
	for ((i=0; i < $numTutes; i++))
	do
		buildTute $i $simAll
	done
fi

if [[ $simSpecific != "-1" ]]; then
	echo "Simulta"
	buildTute $simSpecific 1
fi

echo "all done"
