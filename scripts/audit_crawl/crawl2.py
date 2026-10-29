import route, cap, time
from route import run, NAV
cap_reset=cap.reset
def reset12(): cap_reset(); time.sleep(5)
cap.reset=reset12
SONGPICK=[(795,1499),4,(538,1907),3]  # metronome tile -> Songs & Setlists (empty-state position varies)
routes=[
 ("05_song_detail",[NAV["songs"],2,(400,1030),4]),
 ("07_band_detail",[NAV["bands"],2,(400,700),4]),
 ("12_tuner",[(284,1499),3]),
 ("13_metronome_empty",[(795,1499),3]),
 ("14_rehearsals",[(284,1702),3]),
 ("15_recorder",[(795,1702),3]),
 ("16_practice",[(538,1907),3]),
 ("17_add_song",[(284,922),3]),
 ("18_add_band",[(795,922),3]),
 ("19_add_setlist",[(284,1127),3]),
 ("20_audio_note",[(795,1127),3]),
 ("21_metronome_songpicker",[(795,1499),4,(538,1980),4]),
]
for n,t in routes:
    try: run(n,t)
    except Exception as e: print("FAIL",n,e)
