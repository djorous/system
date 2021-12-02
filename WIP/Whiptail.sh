#!/bin/bash
#---------------------------------------------------------------------------
# yes/no
#---------------------------------------------------------------------------
whiptail --title "Test Message Box" --msgbox "Create a message box with whiptail. Choose Ok to continue." 10 60

if (whiptail --title "Test Yes/No Box" --yesno "Choose between Yes and No." 10 60) then
    echo "You chose Yes. Exit status was $?."
else
    echo "You chose No. Exit status was $?."
fi

#---------------------------------------------------------------------------
# yes/no different text
#---------------------------------------------------------------------------
if (whiptail --title "Test Yes/No Box" --yes-button "Skittles" --no-button "M&M's"  --yesno "Which do you like better?" 10 60) then
    echo "You chose Skittles Exit status was $?."
else
    echo "You chose M&M's. Exit status was $?."
fi

#---------------------------------------------------------------------------
#Input box
#---------------------------------------------------------------------------
PET=$(whiptail --title "Test Free-form Input Box" --inputbox "What is your pet's name?" 10 60 Wigglebutt 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your pet name is:" $PET
else
    echo "You chose Cancel."
fi

#---------------------------------------------------------------------------
#Password
#---------------------------------------------------------------------------
PASSWORD=$(whiptail --title "Test Password Box" --passwordbox "Enter your password and choose Ok to continue." 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your password is:" $PASSWORD
else
    echo "You chose Cancel."
fi
#---------------------------------------------------------------------------
#Menu
#---------------------------------------------------------------------------
OPTION=$(whiptail --title "Test Menu Dialog" --menu "Choose your option" 15 60 4 "1" "Grilled Spicy Sausage" "2" "Grilled Halloumi Cheese" "3" "Charcoaled Chicken Wings" "4" "Fried Aubergine"  3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your chosen option:" $OPTION
else
    echo "You chose Cancel."
fi

#---------------------------------------------------------------------------
#Radio
#---------------------------------------------------------------------------
DISTROS=$(whiptail --title "Test Checklist Dialog" --radiolist "What is the Linux distro of your choice?" 15 60 4 "debian" "Venerable Debian" ON "ubuntu" "Popular Ubuntu" OFF "centos" "Stable CentOS" OFF "mint" "Rising Star Mint" OFF 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "The chosen distro is:" $DISTROS
else
    echo "You chose Cancel."
fi

#---------------------------------------------------------------------------
#Checklist
#---------------------------------------------------------------------------
DISTROS=$(whiptail --title "Test Checklist Dialog" --checklist "Choose preferred Linux distros" 15 60 4 "debian" "Venerable Debian" ON "ubuntu" "Popular Ubuntu" OFF "centos" "Stable CentOS" ON "mint" "Rising Star Mint" OFF 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your favorite distros are:" $DISTROS
else
    echo "You chose Cancel."
fi
