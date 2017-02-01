#!/bin/bash

#
#   This file regenerates the ./screenshots/readme.md,
#   based on the file format prior to adding this script.
#

readme="./screenshots/README.md";

# header
echo "Screenshots" > ${readme};
echo "===" >> ${readme};

# files
for relativePath in ./screenshots/*.png; do
    filenameWithExtension=${relativePath##*/}
    echo "\`$filenameWithExtension\`" >> ${readme}
    echo "" >> ${readme}
    echo "![image]($filenameWithExtension)" >> ${readme}
    echo "" >> ${readme}
done

# remove 1 of 2 empty lines at the bottom
sed '$d' ${readme} > "tmp.md" && mv "tmp.md" ${readme}
