# BetterCombatEvolved
![](http://i1345.photobucket.com/albums/p662/sekrosis/w3fight_zpsfcm1puo5.jpg)
Note - [READ THIS] (README.md#packing) if you are cloning the repo to pack it yourself.

The Better Combat Evolved mod for Witcher 3

[Nexus page](http://www.nexusmods.com/witcher3/mods/769/?)

Better Combat Evolved 2.0 is a combat overhaul mod which aims to add further depth, challenge, and reward to combat. Enemies are stronger, and scale better per-level. Geralt knows 5 additonal "basic" abilities per skill tree, which do not need to be slotted to function. All skills are unlockable at any level and have been changed to make end-game less of an "easy mode." Trophies are essential to combat - some are even powerful enough to design entire builds around.

Below is an INCOMPLETE list of changes, feel free to read them. 
Enemies

Monsters have been given slightly decreased health and greatly increased damage.
Humans and Non-Humans have been given greatly decreased health and greatly increased damage.
ALL enemy scaling has been re-designed to ramp-up as Geralt becomes stronger, making end-game still quite challenging. 
ALL enemies have been modified to dodge and block more, and have been given a 25% boost to stamina regeneration (which means they will attack more often)
Bosses have been given increased health and damage. 


A full list of changes and documentation is coming soon!
MOD DESCRIPTION CURRENTLY UNDER CONSTRUCTION! But here is something you MUST KNOW!:

1. Users of Version 1.04 or earlier MUST DRINK A RESPEC POTION for version 1.09+ to function correctly!

2. NEW USERS who want to use BCEVolved on an EXISTING save, NG+, or Hearts of Stone Only, must ALSO DRINK A RESPEC POTION!

3. NEW USERS who create a BRAND NEW FRESH START GAME do not need to do anything. 

--------------------------------------------------------------------------------------------------
A SPECIAL THANKS TO ALL WHO INSPIRED BCEVOLVED
--------------------------------------------------------------------------------------------------
BCEvolved was inspired by many other great mods here on the Nexus
* Better Combat Enhanced
* Brutal and Realistic Combat
* Ucross' Hardcore Mod
* Ranged Combat Redone
* AND MANY OTHERS!

--------------------------------------------------------------------------------------------------
COMPATIBILITY
--------------------------------------------------------------------------------------------------
BCEvolved edits SEVERAL .xml files, which makes it incompatible with a lot of mods. In spite of this, I've included several similar modifications that other popular mods do.

Mods that change meshes/textures are 100% compatible with BCEvolved

Mods that only edit scripts can be merged together with SCRIPT MERGER, which makes it compatible.

--------------------------------------------------------------------------------------------------
Packing
--------------------------------------------------------------------------------------------------
Before cloning this repository, add the following to your .gitconfig before:
```
[filter "utf16"]
	clean = iconv -f utf-16 -t utf-8
	smudge = iconv -f utf-8 -t utf-16
	required
```
This is required because github doesn't understand UTF-16 encoded files, and The Witcher 3 must encoded its xml files in UTF16 in order to be read.
iconv will force git to store the xml files encoded as utf-8, but convert them to utf-16 on your local machine.
This means that we get the best of both worlds - git friendly files that we can use in the game.
