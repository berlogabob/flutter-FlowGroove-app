import route, cap, time
from route import run, NAV
r0=cap.reset
def r12(): r0(); time.sleep(5)
cap.reset=r12
MET=[(795,1499),4,(538,1907),4,(540,1778),4]
SW=("swipe",540,1900,540,900,400)
routes=[
 ("22_metronome_with_song",MET),
 ("23_drums_panel_empty",MET+[SW,(540,2038),3]),
 ("24_drums_editor",MET+[SW,(540,2038),3,(737,1307),3]),
 ("25_song_lab",[NAV["songs"],2,(400,1030),4,(850,585),3]),
 ("26_song_edit",[NAV["songs"],2,(400,1030),4,(225,585),3]),
 ("27_band_songs",[NAV["bands"],2,(400,700),4,(270,1355),4]),
 ("28_band_rehearsals",[NAV["bands"],2,(400,700),4,(770,1355),4]),
 ("29_songs_filter",[NAV["songs"],2,(340,805),3]),
 ("30_song_card_menu",[NAV["songs"],2,(910,1160),3]),
 ("31_setlist_menu",[NAV["setlists"],2,(910,750),3]),
]
for n,t in routes:
    try: run(n,t)
    except Exception as e: print("FAIL",n,e)
