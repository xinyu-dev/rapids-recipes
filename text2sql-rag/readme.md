
# Text2SQL RAG Minimal Demo

## Note

This is a minimal skeleton version to demo how to retrieve Q&A and DDL for Text2SQL RAG, using the accelerated cuVS. 

## Requirements

Linux instance with NVIDIA GPU (any kind, even a small A10 is OK)

Test your CUDA driver installation with: 
```
nvidia-smi
```

## Miniconda

> [!NOTE]
    > We recommend using miniconda to manage the environment if you plan to use faiss for RAG. The faiss-GPU-cuVS package is easier to install with conda.

1. Run
	```bash
	curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	```
2. Then
	```bash
	bash ~/Miniconda3-latest-Linux-x86_64.sh
	```
3. Click through... Accept default, select `yes` for all questions.
4. Reopen a terminal to take effect. Alternatively, in the same terminal, run run
	```bash
	source ~/.bashrc
	```

## Workspace

1. Create worksplace
	```bash
	mkdir ~/workspace && cd ~/workspace
	```
2. Create uv environment. See [vllm docs](https://docs.vllm.ai/en/stable/getting_started/quickstart.html#prerequisites)
	```bash
	uv venv --python 3.12
	conda create -n workspace python=3.12
	```
3. Activate uv environment
	```bash
	source .venv/bin/activate
	conda activate workspace
	```
4. Install faiss-gpu-cuvs. For the latest version, see [here](https://github.com/facebookresearch/faiss/blob/main/INSTALL.md#installing-faiss-via-conda)
	```bash
	conda install -c pytorch -c nvidia -c rapidsai -c conda-forge libnvjitlink faiss-gpu-cuvs=1.12.0
	```
5. Install a fewl additional packages
    ```bash
    pip install loguru openai pandas python-dotenv
    ```

## Example DDL statement

Take a look at `data/model_evaluation/dataset/eicu_instruct_benchmark_rag.sql`. Below is a snippet of that file, showing the first 2 DDL statement: 

```sql
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
```

Notes:
1. Annotate each DDL with inline comments (as above).
2. For DDL RAG, chunk by table so each chunk is a complete, executable table definition. For example, in the code snippet above, produce exactly two chunks.

## Exmaple of Q&A dataset

Take a look at `data/model_evaluation/dataset/qa_examples.csv`. The CSV file has 2 columns: 

1. `question`: example question a user would ask
2. `label`: the ground truth SQL statement

Example: 

```python
{
    "questions": "tell me the method of intake of oxycodone hcl 5 mg po tabs (range) prn?"
    "label": "select distinct medication.routeadmin from medication where medication.drugname = 'oxycodone hcl 5 mg po tabs (range) prn'"
}
```

Notes: 
1. Embed only the `question`, but retrieve both `question` and `label` pairs.
2. Questions can have multiple valid SQL solutions. Just add the `question`... `label` for each unique pair of Q&A. 

## How to embed & retrieve

Follow `text2sql-minimal-demo.ipynb` . 

Notes: 
1. The notebook only shows how to embed & retrieve DDL and Q&A 
2. It does not contain code to add the retrieved chunks to prompt. 
3. Eventually, the retrieved chunks need to be embedded into the prompt, like this: 

## Final prompt

The final prompt will contain several sections. For readability, I split the sections into the JSON dict shown below:  

```json
{
  "task": "Based on DDL statements, instructions, and the current date, generate a SQL query in the following SQLite schema to answer the question. If the question cannot be answered using the available tables and columns in the DDL (i.e., it is out of scope), return only: None.",
  "today": "2105-12-31 23:59:00",
  "ddl_statements": [
    "DROP TABLE IF EXISTS medication;",
    "CREATE TABLE medication (medicationid INT NOT NULL PRIMARY KEY, patientunitstayid INT NOT NULL, drugname VARCHAR(220) NOT NULL, dosage VARCHAR(60) NOT NULL, routeadmin VARCHAR(120) NOT NULL, drugstarttime TIMESTAMP(0), drugstoptime TIMESTAMP(0), FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid));",
    "DROP TABLE IF EXISTS intakeoutput;",
    "CREATE TABLE intakeoutput (intakeoutputid INT NOT NULL PRIMARY KEY, patientunitstayid INT NOT NULL, cellpath VARCHAR(500) NOT NULL, celllabel VARCHAR(255) NOT NULL, cellvaluenumeric NUMERIC(12,4) NOT NULL, intakeoutputtime TIMESTAMP(0) NOT NULL, FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid));",
    "DROP TABLE IF EXISTS treatment;",
    "CREATE TABLE treatment (treatmentid INT NOT NULL PRIMARY KEY, patientunitstayid INT NOT NULL, treatmentname VARCHAR(200) NOT NULL, treatmenttime TIMESTAMP(0) NOT NULL, FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid));",
    "DROP TABLE IF EXISTS vitalperiodic;",
    "CREATE TABLE vitalperiodic (vitalperiodicid BIGINT NOT NULL PRIMARY KEY, patientunitstayid INT NOT NULL, temperature NUMERIC(11,4), sao2 INT, heartrate INT, respiration INT, systemicsystolic INT, systemicdiastolic INT, systemicmean INT, observationtime TIMESTAMP(0) NOT NULL, FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid));",
    "DROP TABLE IF EXISTS lab;",
    "CREATE TABLE lab (labid INT NOT NULL PRIMARY KEY, patientunitstayid INT NOT NULL, labname VARCHAR(256) NOT NULL, labresult NUMERIC(11,4) NOT NULL, labresulttime TIMESTAMP(0) NOT NULL, FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid));"
  ],
  "sample_questions": [
    {
      "question": "tell me the method of intake of fentanyl 2000 mcg in d5w 100 ml infusion final conc = 20 mcg/ml?",
      "sql": "select distinct medication.routeadmin from medication where medication.drugname = 'fentanyl 2000 mcg in d5w 100 ml infusion final conc = 20 mcg/ml'"
    },
    {
      "question": "tell me the intake method for propofol 1000 mg/100 ml?",
      "sql": "select distinct medication.routeadmin from medication where medication.drugname = 'propofol 1000 mg/100 ml'"
    },
    {
      "question": "tell me the method of intake of pantoprazole 40 mg intravenous solution?",
      "sql": "select distinct medication.routeadmin from medication where medication.drugname = 'pantoprazole 40 mg intravenous solution'"
    },
    {
      "question": "what is the cost of a medication named dextrose 50 % in water (d50w) iv syringe?",
      "sql": "select distinct cost.cost from cost where cost.eventtype = 'medication' and cost.eventid in ( select medication.medicationid from medication where medication.drugname = 'dextrose 50 % in water (d50w) iv syringe' )"
    },
    {
      "question": "did patient 022-44805 be prescribed 1000 ml flex cont: sodium chloride 0.9 % iv soln, dextrose 5% in water (d5w) iv : 1000 ml bag, or potassium chloride in 12/2105?",
      "sql": "select count(*)>0 from medication where medication.patientunitstayid in ( select patient.patientunitstayid from patient where patient.patienthealthsystemstayid in ( select patient.patienthealthsystemstayid from patient where patient.uniquepid = '022-44805' ) ) and medication.drugname in ( '1000 ml flex cont: sodium chloride 0.9 % iv soln', 'dextrose 5% in water (d5w) iv : 1000 ml bag', 'potassium chloride' ) and strftime('%y-%m',medication.drugstarttime) = '2105-12'"
    },
    {
      "question": "what are the methods of consumption of potassium chloride 20 meq/50 ml iv piggy back 50 ml bag?",
      "sql": "select distinct medication.routeadmin from medication where medication.drugname = 'potassium chloride 20 meq/50 ml iv piggy back 50 ml bag'"
    }
  ],
  "instructions": [
    "Respond only with the SQL query in markdown format.",
    "If unsure, reply with 'None'."
  ],
  "user_question": "tell me the method of dextrose 5% in water (d5w) iv : 1000 ml bag intake?"
}
```
Note that: 
1. `task`: Basic instructions for all prompts
2. `today`: Current date (optional)
3. `ddl_statements`: RAG-retrieved DDL schema relevant to the question
4. `sample_questions`: RAG-retrieved Q&A examples relevant to the question
5. `instructions`: Additional instructions (optional)
6. `user_question`: The actual user query

Then your final prompt is just a single string, concatenating the information above: 

```python

final_prompt = """
\"Based on DDL statements, instructions, and the current date, generate a SQL query in the following sqlite to answer the question.\\nIf the question cannot be answered using the available tables and columns in the DDL (i.e., it is out of scope), return only: None.\\nToday is 2105-12-31 23:59:00\\nDDL statements:\\nDROP TABLE IF EXISTS medication;\\nCREATE TABLE medication  -- store medication administration records\\n(\\n    medicationid INT NOT NULL PRIMARY KEY, -- Unique medication record ID\\n    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)\\n    drugname VARCHAR(220) NOT NULL, -- Name of the medication (lowercase)\\n    dosage VARCHAR(60) NOT NULL, -- Dosage of the drug\\n    routeadmin VARCHAR(120) NOT NULL, -- Route of administration (e.g., \\\"iv\\\", \\\"po\\\", ...etc) (lowercase)\\n    drugstarttime TIMESTAMP(0), -- Time drug administration started\\n    drugstoptime TIMESTAMP(0), -- Time drug administration stopped\\n    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)\\n);\\nDROP TABLE IF EXISTS intakeoutput;\\nCREATE TABLE intakeoutput  -- store intake/output measurements (fluids, urine, etc.)\\n(\\n    intakeoutputid INT NOT NULL PRIMARY KEY, -- Unique intake/output record ID\\n    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)\\n    cellpath VARCHAR(500) NOT NULL, -- Hierarchical label/path (lowercase)   \\n    celllabel VARCHAR(255) NOT NULL, -- Label describing the intake/output (lowercase)\\n    cellvaluenumeric NUMERIC(12,4) NOT NULL, -- Volume or quantity recorded\\n    intakeoutputtime TIMESTAMP(0) NOT NULL, -- Time of measurement\\n    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)\\n);\\nDROP TABLE IF EXISTS treatment;\\nCREATE TABLE treatment  -- store treatments administered during ICU stay\\n(\\n    treatmentid INT NOT NULL PRIMARY KEY, -- Unique treatment record ID\\n    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)\\n    treatmentname VARCHAR(200) NOT NULL, -- Name of the treatment administered (lowercase)\\n    treatmenttime TIMESTAMP(0) NOT NULL, -- Time the treatment was given\\n    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)\\n);\\nDROP TABLE IF EXISTS vitalperiodic;\\nCREATE TABLE vitalperiodic  -- store periodic vital signs measured during ICU stay\\n(\\n    vitalperiodicid BIGINT NOT NULL PRIMARY KEY, -- Unique ID for vital sign entry\\n    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)\\n    temperature NUMERIC(11,4), -- Body temperature (Celsius)\\n    sao2 INT, -- Oxygen saturation (%)\\n    heartrate INT, -- Heart rate (bpm)\\n    respiration INT, -- Respiratory rate (breaths per minute)\\n    systemicsystolic INT, -- Systolic blood pressure (mmHg)\\n    systemicdiastolic INT, -- Diastolic blood pressure (mmHg)\\n    systemicmean INT, -- Mean arterial pressure (mmHg)\\n    observationtime TIMESTAMP(0) NOT NULL, -- Time of observation\\n    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)\\n);\\nDROP TABLE IF EXISTS lab;\\nCREATE TABLE lab  -- store lab test results\\n(\\n    labid INT NOT NULL PRIMARY KEY, -- Unique lab test result ID\\n    patientunitstayid INT NOT NULL, -- ICU stay ID (FK to patient)\\n    labname VARCHAR(256) NOT NULL, -- Name of the lab test (lowercase)\\n    labresult NUMERIC(11,4) NOT NULL, -- Result value\\n    labresulttime TIMESTAMP(0) NOT NULL, -- Time when the lab result was recorded\\n    FOREIGN KEY(patientunitstayid) REFERENCES patient(patientunitstayid)\\n);\\nHere are some sample question and correct SQL (may or may not be useful in constructing the SQL to answer the question) :\\n\\nQuestion: tell me the method of intake of fentanyl 2000 mcg in d5w 100 ml infusion final conc = 20 mcg/ml?.  SQL answer: ```sql\\nselect distinct medication.routeadmin from medication where medication.drugname = 'fentanyl 2000 mcg in d5w 100 ml infusion final conc = 20 mcg/ml'\\n```\\nQuestion: tell me the intake method for propofol 1000 mg/100 ml?.  SQL answer: ```sql\\nselect distinct medication.routeadmin from medication where medication.drugname = 'propofol 1000 mg/100 ml'\\n```\\nQuestion: tell me the method of intake of pantoprazole 40 mg intravenous solution?.  SQL answer: ```sql\\nselect distinct medication.routeadmin from medication where medication.drugname = 'pantoprazole 40 mg intravenous solution'\\n```\\nQuestion: what is the cost of a medication named dextrose 50 % in water (d50w) iv syringe?.  SQL answer: ```sql\\nselect distinct cost.cost from cost where cost.eventtype = 'medication' and cost.eventid in ( select medication.medicationid from medication where medication.drugname = 'dextrose 50 % in water (d50w) iv syringe' )\\n```\\nQuestion: did patient 022-44805 be prescribed 1000 ml flex cont: sodium chloride 0.9 % iv soln, dextrose 5% in water (d5w) iv : 1000 ml bag, or potassium chloride in 12/2105?.  SQL answer: ```sql\\nselect count(*)>0 from medication where medication.patientunitstayid in ( select patient.patientunitstayid from patient where patient.patienthealthsystemstayid in ( select patient.patienthealthsystemstayid from patient where patient.uniquepid = '022-44805' ) ) and medication.drugname in ( '1000 ml flex cont: sodium chloride 0.9 % iv soln', 'dextrose 5% in water (d5w) iv : 1000 ml bag', 'potassium chloride' ) and strftime('%y-%m',medication.drugstarttime) = '2105-12'\\n```\\nQuestion: what are the methods of consumption of potassium chloride 20 meq/50 ml iv piggy back 50 ml bag?.  SQL answer: ```sql\\nselect distinct medication.routeadmin from medication where medication.drugname = 'potassium chloride 20 meq/50 ml iv piggy back 50 ml bag'\\n```\\n\\nInstructions:\\n- Respond only with the SQL query in markdown format. If unsure, reply with \\\"None\\\"\"}, {\"role\": \"user\", \"content\": \"tell me the method of dextrose 5% in water (d5w) iv : 1000 ml bag intake?\"
""
```
## End to end example

For a end-to-end with demo with eICU datset, including retrieval and benchmarking, see [private repository](https://github.com/xinyu-dev/vrdc_text2sql)



