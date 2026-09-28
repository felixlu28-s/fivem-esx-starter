RP = RP or {}
-- Client-only presentation defaults; no gameplay permissions or rewards.
RP.NpcConfig = {
    tickMs = 750, radius = 6.0, leaveRadius = 8.0, lostSightMs = 5000,
    greetingCooldown = 60000, chatterMin = 35000, chatterMax = 65000,
    speechGap = 6500, gestureGap = 4000, loadTimeout = 2000,
    profiles = {
        generic = { maleDict = 'gestures@m@standing@casual', femaleDict = 'gestures@f@standing@casual',
            greeting = 'gesture_hello', gestures = { 'gesture_nod_yes_soft', 'gesture_pleased' },
            greetingSpeech = 'GENERIC_HI', chatterSpeech = 'GENERIC_HOWS_IT_GOING' },
        shop = { maleDict = 'gestures@m@standing@casual', femaleDict = 'gestures@f@standing@casual',
            greeting = 'gesture_hello', gestures = { 'gesture_nod_yes_soft', 'gesture_pleased' },
            greetingSpeech = 'GENERIC_HI', chatterSpeech = 'GENERIC_HOWS_IT_GOING' },
        ammunation = { dict = 'random@shop_gunstore', greeting = '_greeting', gestures = { '_idle_a', '_idle_b' },
            greetingSpeech = 'GENERIC_HI', chatterSpeech = 'GENERIC_HOWS_IT_GOING' },
    },
}
