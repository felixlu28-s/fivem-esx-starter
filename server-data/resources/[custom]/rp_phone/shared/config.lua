PhoneConfig = {
    contacts=150, tasks=100, photos=40, photoBytes=120000, -- public iFruit copies; private gallery limits live in phoneGallery.ts
    callParticipants=6, videoParticipants=4, ringSeconds=35,
    camera={
        -- Local offsets of the prop_npc_phone_02 lenses, in metres.
        lens={rear={x=0.0,y=-0.035,z=0.055},selfie={x=0.0,y=0.035,z=0.055}},
        fov={rear=65.0,selfie=75.0},
    },
    -- These are fictional in-game sites. No arbitrary remote HTML executes in our NUI.
    sites={
        {id='eyefind',title='Eyefind',url='eyefind.info',body='Entdecke Los Santos. Suche nach Orten, Diensten und Menschen in deiner Stadt.'},
        {id='city',title='Los Santos City',url='los-santos.gov',body='Willkommen in Los Santos. Kontakte, Nachrichten und iFruit verbinden dich mit den Menschen deiner Stadt.'},
        {id='travel',title='Los Santos Transit',url='lst.travel',body='Ankommen. Einsteigen. Losfahren. Öffentliche Garagen erkennst du am Garagensymbol auf deiner Karte.'},
        {id='news',title='Weazel News',url='weazel.news',body='Nachrichten aus Los Santos. Eigene Bilder und Geschichten findest du im öffentlichen iFruit-Feed.'},
    },
}
