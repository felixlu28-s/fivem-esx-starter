-- Standard ESX schema. IF NOT EXISTS never replaces an existing owned vehicle store.
CREATE TABLE IF NOT EXISTS owned_vehicles (
    owner VARCHAR(60) DEFAULT NULL,
    plate VARCHAR(12) NOT NULL,
    vehicle LONGTEXT DEFAULT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'car',
    job VARCHAR(20) DEFAULT NULL,
    stored TINYINT NOT NULL DEFAULT 0,
    parking VARCHAR(60) DEFAULT NULL,
    pound VARCHAR(60) DEFAULT NULL,
    PRIMARY KEY (plate), KEY esx_owned_vehicles_owner (owner)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit/recovery journal only: ownership/properties remain in owned_vehicles.
CREATE TABLE IF NOT EXISTS rp_vehicle_garage_operations (
    token VARCHAR(80) NOT NULL,
    owner VARCHAR(80) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    garage VARCHAR(60) NOT NULL,
    direction ENUM('out','in') NOT NULL,
    phase VARCHAR(32) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (token), KEY garage_operations_plate (plate), KEY garage_operations_phase (phase)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
