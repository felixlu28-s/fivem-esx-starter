Garage = {}
Garage.Config = {
    radius = 2.2, streamDistance = 100.0, operationTimeout = 150000,
    stageTimeout = 30000, spawnSyncTimeout = 10000, pedSyncTimeout = 10000, gateTime = 2600, speed = 3.5,
    deadValetLifetime = 60000, gateClearance = 4.0,
    -- Slow, careful driving: stop for cars/peds, steer around objects.
    drivingStyle = 59, testModel = 'asea',
    editor = { maxGarages=64, maxPoints=20, radius=100.0,
        models={'s_m_y_valet_01','s_m_m_autoshop_01','s_m_m_autoshop_02','s_f_y_shop_low'},
        scenarios={'WORLD_HUMAN_CLIPBOARD','WORLD_HUMAN_STAND_IMPATIENT','WORLD_HUMAN_GUARD_STAND'} },
    garages = {
        la_mesa = {
            label = 'La Mesa · Parkservice', bucket = 0,
            clerk = { model = 's_m_y_valet_01', x = 715.0, y = -1094.0, z = 21.17, h = 0.0, scenario='WORLD_HUMAN_CLIPBOARD' },
            interaction = { x=715.0, y=-1093.0, z=22.17 },
            -- Existing LS Customs roller door; do not run another door controller here.
            gate = { model = 'prop_id2_11_gdoor', x = 723.12, y = -1088.83, z = 23.28 },
            -- Vehicle positions are native vehicle roots. Ped positions are sole anchors.
            hidden = { x = 732.0, y = -1088.5, z = 22.17, h = 90.0 },
            parking = { x = 714.0, y = -1088.5, z = 22.17, h = 90.0 },
            outward = { { x = 727.0, y = -1088.5, z = 22.17 }, { x = 719.0, y = -1088.5, z = 22.17 } },
            inward = { { x = 719.0, y = -1088.5, z = 22.17 }, { x = 727.0, y = -1088.5, z = 22.17 } },
            -- Staff entrance behind the roller door; the closed door conceals despawning.
            staffDoor = { x = 731.0, y = -1085.5, z = 21.17, h = 90.0 },
            staffPath = { { x = 727.0, y = -1087.0, z = 22.17 }, { x = 720.0, y = -1087.0, z = 22.17 }, { x=715.0,y=-1090.5,z=22.17 } },
            valetModel = 's_m_y_valet_01', blip = { sprite = 357, color = 2 },
        },
    },
}
