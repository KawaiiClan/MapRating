# MapRating
## Allow players to !rate maps (For use with [bhoptimer](https://github.com/shavitush/bhoptimer))

Use data for random map cycle influence, or anything else

## Setup
- Create `addons/sourcemod/configs/databases.cfg` entry called `maprating`
- Load the plugin, it will auto-create the DB structure

## Commands
- !rate / !rating - Open map rating menu, see map rating, and vote on it.
- !favorite / !fav - Favorite a map to find it again with !favorites / !favs
- !topmaps - See the highest rated maps on the server.
- !worstmaps - See the lowest rated maps on the server.
<p>The menu also appears when a player finishes the map (if no rating has been submitted, or if the option has been disabled by the player)<br>

![image](https://github.com/user-attachments/assets/f060e7d2-18ae-4261-90c0-adaa71576bbb)
