INSERT INTO global_property (property, property_value, description) VALUES ("statistics.show_encounter_types", "REGISTRATION,OBSERVATIONS,DIAGNOSIS,UPDATE OUTCOME,REFER PATIENT OUT?", "Maternity Encounter Types") ON DUPLICATE KEY UPDATE property = "statistics.show_encounter_types";

DELETE FROM global_property where property = "facility.login_wards";
INSERT INTO global_property (property, property_value, description) VALUES ("facility.login_wards", "Ante-Natal Ward,Labour Ward,Post-Natal Ward,Gynaecology Ward,Post-Natal Ward (High Risk),Post-Natal Ward (Low Risk),Theater,High Dependency Unit (HDU),Private Obstetric and Gynaecology,Registration", "");


INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Ante-Natal Ward", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Ante-Natal Ward" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Bwaila Maternity Unit", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Bwaila Maternity Unit" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Labour Ward", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Labour Ward" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Post-Natal Ward", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Post-Natal Ward" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Gynaecology Ward", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Gynaecology Ward" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Post-Natal Ward (Low Risk)", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Post-Natal Ward (Low Risk)" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Post-Natal Ward (High Risk)", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Post-Natal Ward (High Risk)" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Kamuzu Central Hospital", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Kamuzu Central Hospital" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Ethel Mutharika Maternity Wing", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Ethel Mutharika Maternity Wing" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Theater", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Theater" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "High Dependency Unit (HDU)", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "High Dependency Unit (HDU)" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Private Obstetric and Gynaecology", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Private Obstetric and Gynaecology" LIMIT 1);

INSERT INTO location (name, description, creator, date_created, retired)
	SELECT "Registration", "(ID=700)", 1, now(), 0
    FROM dual
	WHERE NOT EXISTS (SELECT name FROM location WHERE name = "Registration" LIMIT 1);




