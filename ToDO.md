ToDO.md
# role:
you are 10+ experienced flutter developer, solve uncheked tasks useing agents in /agents folder. in need-rescan whole project to realise roots of problem.

1 [x] приложение забывает пользователя при сворачивании или выходе:
 первый раз заходил - приняло логин и пароль. свернул приложение и открыл снова - просит заполниться данные ( забыл пользователя)
 второй раз ввожу данные - получаю ошибкуauthentification faild
2 [x] problem with metronome screen, when user pus arrow go back -> black screen.
3 [x] fix arrow in add song, add band, add setlist screen. it should be like in other screens with widget (arrow, name , 3 dot menu)
- [x] when user trying to add new song to the band -> screen stuck on loading animation
- [x] after fresh login user sees main screen with arrow "back" on the top left. why? 
- [x] band screen with band name has old "arrow back" on the top left, not common bar with arrow in circle, page name, 3 dot menu. fix it.
  - [x] add to 3 dot menu items:
    - [x] members. swow all members in this band
    - [x] share this band ( send link to join this band)
    - [x] add / edit discription of this band.
- [x] you broke nawigation. ifter fresh login i can see arrow back on main screen, but i cant navigate to any ather screen
- [x] login screen have arrow back on the top left, for what? its logically wron if it it a first screen.


- [ ] check in Band screen -> The Band -> list of song.
  - [x] songs widget have different look than on original personal songs bank. 
  - [x] when user edit song -> it doesnt save changes.
  - [x] when song is deleted  from bend page-> it mus be deleted only from band page, not from personal songs bank.
  - [x] there are no sorting widget like in personal songs bank.


- [ ] after sendind join the band link user get this:
```
Join my band "Offbeats." on RepSync!
Use invite code: 920ZZR
Or click the link: https://repsync-app-8685c.web.app/join-band?code=920ZZR
```
```
Site Not Found
Why am I seeing this?
There are a few potential reasons:
1. You haven't deployed an app yet.
2. You may have deployed an empty directory.
3. This is a custom domain, but we haven't finished setting it up yet.

How can I deploy my first app?

Refer to our hosting documentation to get started.

Firebase
```
