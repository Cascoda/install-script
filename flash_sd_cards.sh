#!/bin/bash

#Checking the arguments
if [ $# -ne 2 ]
then
	echo "Please specify the number of sd cards to flash as the first argument and the image as the second argument"
	exit
fi

image=$2 

if test ! -f ${image}
then
	echo "Image not found"
	exit
fi

#Checking that the correct number of SD cards are available
cardnum=$1
cards_found=0

echo "Attempting to flash ${cardnum} SD cards"

for letter in {a..z}
do
	card="/dev/sd${letter}"

	if test -b ${card}
	then
		let "cards_found++"
		echo "Found card ${card}"
	else
		break
	fi
done

if [ $cardnum != $cards_found ]
then
	echo "Flashing of $cardnum cards requested, but $cards_found cards detected. Flash aborted..."
	exit
fi

#Flashing the cards in parallel
for letter in {a..z}
do
	card="/dev/sd${letter}"

	if test -b ${card}
	then
		flash -d ${card} -f ${image} &
	else
		break
	fi
done

wait

echo "DONE"
