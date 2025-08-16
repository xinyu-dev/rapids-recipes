DROP TABLE IF EXISTS patient;
CREATE TABLE patient    -- store patient demographics and admission information
(
    uniquepid VARCHAR(10) NOT NULL, -- Unique patient identifier across the system
    patienthealthsystemstayid INT NOT NULL, -- Unique ID for patient's entire hospital stay
    patientunitstayid INT NOT NULL PRIMARY KEY, -- Unique ID for the patient's ICU stay
    gender VARCHAR(25) NOT NULL, -- Gender of the patient ("female" or "male") (lowercase)
    age VARCHAR(10) NOT NULL, -- Age at admission (can be in years or an age category)
    ethnicity VARCHAR(50), -- Ethnicity of the patient (e.g: "caucasian", "native american", "hispanic", "african american", "other/unknown", "asian" or null) (lowercase)
    hospitalid INT NOT NULL, -- ID of the hospital
    wardid INT NOT NULL, -- ID of the hospital ward/unit
    admissionheight NUMERIC(10,2), -- Patient's height on admission (in cm)
    admissionweight NUMERIC(10,2), -- Weight on admission (in kg)
    dischargeweight NUMERIC(10,2), -- Weight at discharge (in kg)
    hospitaladmittime TIMESTAMP(0) NOT NULL, -- Time patient was admitted to hospital
    hospitaladmitsource VARCHAR(30) NOT NULL, -- Source of hospital admission (e.g., "operating room", "floor", "other hospital", "emergency department", "direct admit", "step-down unit (sdu)", "acute care/floor", "recovery room", "icu to sdu", "other icu" or "pacu") (lowercase)
    unitadmittime TIMESTAMP(0) NOT NULL, -- Time of ICU admission
    unitdischargetime TIMESTAMP(0), -- Time of ICU discharge
    hospitaldischargetime TIMESTAMP(0), -- Time of hospital discharge
    hospitaldischargestatus VARCHAR(10) -- Discharge status (e.g., "alive", "expired" or null)
);

DROP TABLE IF EXISTS diagnosis;
CREATE TABLE diagnosis  -- store diagnoses assigned during ICU stay
(
    diagnosisid INT NOT NULL PRIMARY KEY, -- Unique diagnosis record ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    diagnosisname VARCHAR(200) NOT NULL, -- Full name of diagnosis (lowercase)
    diagnosistime TIMESTAMP(0) NOT NULL, -- Time diagnosis was recorded
    icd9code VARCHAR(100), -- ICD-9 code of the diagnosis
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS treatment;
CREATE TABLE treatment  -- store treatments administered during ICU stay
(
    treatmentid INT NOT NULL PRIMARY KEY, -- Unique treatment record ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    treatmentname VARCHAR(200) NOT NULL, -- Name of the treatment administered (lowercase)
    treatmenttime TIMESTAMP(0) NOT NULL, -- Time the treatment was given
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS lab;
CREATE TABLE lab  -- store lab test results
(
    labid INT NOT NULL PRIMARY KEY, -- Unique lab test result ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    labname VARCHAR(256) NOT NULL, -- Name of the lab test (lowercase)
    labresult NUMERIC(11,4) NOT NULL, -- Result value
    labresulttime TIMESTAMP(0) NOT NULL, -- Time when the lab result was recorded
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS medication;
CREATE TABLE medication  -- store medication administration records
(
    medicationid INT NOT NULL PRIMARY KEY, -- Unique medication record ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    drugname VARCHAR(220) NOT NULL, -- Name of the medication (lowercase)
    dosage VARCHAR(60) NOT NULL, -- Dosage of the drug
    routeadmin VARCHAR(120) NOT NULL, -- Route of administration (e.g., "iv", "po", ...etc) (lowercase)
    drugstarttime TIMESTAMP(0), -- Time drug administration started
    drugstoptime TIMESTAMP(0), -- Time drug administration stopped
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS cost;
CREATE TABLE cost  -- store cost-related data for services provided
(
    costid INT NOT NULL PRIMARY KEY, -- Unique cost record ID
    uniquepid VARCHAR(10) NOT NULL, -- Unique patient ID (can appear in multiple ICU stays)
    patienthealthsystemstayid INT NOT NULL, -- Hospital stay ID (FK to patient)
    eventtype VARCHAR(20) NOT NULL, -- Type of billable event (e.g., "diagnosis", "lab", "treatment" or "medication") (lowercase)
    eventid INT NOT NULL, -- Associated event ID (maps to treatment, lab, etc.)
    chargetime TIMESTAMP(0) NOT NULL, -- Time the cost was charged
    cost DOUBLE PRECISION NOT NULL, -- Cost value
    FOREIGN KEY(patienthealthsystemstayid) REFERENCES patient(patienthealthsystemstayid)
);

DROP TABLE IF EXISTS allergy;
CREATE TABLE allergy  -- store drug-related allergy information
(
    allergyid INT NOT NULL PRIMARY KEY, -- Unique allergy record ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    drugname VARCHAR(255), -- Drug name associated with allergy (if any) (lowercase)
    allergyname VARCHAR(255) NOT NULL, -- Description of the allergy (lowercase)
    allergytime TIMESTAMP(0) NOT NULL, -- Time allergy was recorded
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS intakeoutput;
CREATE TABLE intakeoutput  -- store intake/output measurements (fluids, urine, etc.)
(
    intakeoutputid INT NOT NULL PRIMARY KEY, -- Unique intake/output record ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    cellpath VARCHAR(500) NOT NULL, -- Hierarchical label/path (lowercase)   
    celllabel VARCHAR(255) NOT NULL, -- Label describing the intake/output (lowercase)
    cellvaluenumeric NUMERIC(12,4) NOT NULL, -- Volume or quantity recorded
    intakeoutputtime TIMESTAMP(0) NOT NULL, -- Time of measurement
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS microlab;
CREATE TABLE microlab  -- store microbiology lab culture results
(
    microlabid INT NOT NULL PRIMARY KEY, -- Unique microbiology lab result ID
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    culturesite VARCHAR(255) NOT NULL, -- Site of culture collection (e.g., "blood", "urine") (lowercase)
    organism VARCHAR(255) NOT NULL, -- Identified organism (e.g., "escherichia coli", "mixed flora", "pseudomonas aeruginosa", ...etc) (lowercase)
    culturetakentime TIMESTAMP(0) NOT NULL, -- Time culture was taken
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);

DROP TABLE IF EXISTS vitalperiodic;
CREATE TABLE vitalperiodic  -- store periodic vital signs measured during ICU stay
(
    vitalperiodicid BIGINT NOT NULL PRIMARY KEY, -- Unique ID for vital sign entry
    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)
    temperature NUMERIC(11,4), -- Body temperature (Celsius)
    sao2 INT, -- Oxygen saturation (%)
    heartrate INT, -- Heart rate (bpm)
    respiration INT, -- Respiratory rate (breaths per minute)
    systemicsystolic INT, -- Systolic blood pressure (mmHg)
    systemicdiastolic INT, -- Diastolic blood pressure (mmHg)
    systemicmean INT, -- Mean arterial pressure (mmHg)
    observationtime TIMESTAMP(0) NOT NULL, -- Time of observation
    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)
);