import route
from route import run, NAV
H=lambda *t: list(t)
routes=[
 ("04_songs",[NAV["songs"]]),
 ("05_song_detail",[NAV["songs"],2,(300,640),3]),
 ("06_bands",[NAV["bands"]]),
 ("07_band_detail",[NAV["bands"],2,(300,500),3]),
 ("08_setlists",[NAV["setlists"]]),
 ("09_setlist_detail",[NAV["setlists"],2,(300,560),3]),
 ("10_menu",[NAV["menu"],2]),
 ("11_menu_scrolled",[NAV["menu"],2,("swipe",540,2100,540,500,400)]),
 ("12_tuner",[(284,1279),3]),
 ("13_metronome_empty",[(795,1279),3]),
 ("14_rehearsals",[(284,1482),3]),
 ("15_recorder",[(795,1482),3]),
 ("16_practice",[(538,1686),3]),
 ("17_add_song",[(284,702),3]),
 ("18_add_band",[(795,702),3]),
 ("19_add_setlist",[(284,907),3]),
 ("20_audio_note",[(795,907),3]),
]
for n,t in routes:
    try: run(n,t)
    except Exception as e: print("FAIL",n,e)
