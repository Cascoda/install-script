# Bulk Flash SD Cards

This script allows you to flash multiple SD cards in parallel with a given image.

## Setup

This script uses [this flash tool](https://github.com/hypriot/flash), so before running the script, follow the instruction on that page to download the tool and its dependencies.

Then download the `flash_sd_cards.sh` script and the image that you want to flash to the SD cards, and connect your SD cards to your PC or Raspberry Pi.

## Running the Script

Run the script by typing ``flash_sd_cards <number_of_cards> <image>``, e.g. ``flash_sd_cards 9 18-oct-2021.img`` to flash the image file 18-oct-2021.img to 9 connected SD cards.
