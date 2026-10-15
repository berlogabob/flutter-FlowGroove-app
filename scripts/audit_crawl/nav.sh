S=XPH0219904001750
adb -s $S shell am force-stop com.flowgroove.app; adb -s $S logcat -c
adb -s $S shell monkey -p com.flowgroove.app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 10
adb -s $S shell input tap 540 2260; sleep 4
adb -s $S shell input tap 300 197; adb -s $S shell input text "mill"; sleep 2; adb -s $S shell input keyevent KEYCODE_BACK; sleep 1
adb -s $S shell input tap 767 533; sleep 10
adb -s $S shell input tap 767 1119; sleep 5
adb -s $S shell input swipe 540 1900 540 900 400; sleep 1
adb -s $S shell input tap 540 2038; sleep 3
