import json
import sqlite3
import joblib
import pandas as pd
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])

model = joblib.load("model.pkl")
scaler = joblib.load("scaler.pkl")
columns = joblib.load("columns.pkl")


def db():
    conn = sqlite3.connect("predictions.db")
    conn.row_factory = sqlite3.Row
    return conn


with db() as c:
    c.execute("""CREATE TABLE IF NOT EXISTS model_info (
        id INTEGER PRIMARY KEY, name TEXT, version TEXT)""")
    c.execute("""INSERT OR IGNORE INTO model_info (id, name, version)
        VALUES (1, 'LogisticRegression', 'v1')""")
    c.execute("""CREATE TABLE IF NOT EXISTS predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id INTEGER DEFAULT 1,
        input_data TEXT,
        prediction TEXT,
        probability REAL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP)""")


class Person(BaseModel):
    age: int
    workclass: str = "Private"
    fnlwgt: int = 190000
    education: str = "Bachelors"
    education_num: int
    marital_status: str = "Never-married"
    occupation: str = "Prof-specialty"
    relationship: str = "Not-in-family"
    race: str = "White"
    sex: str = "Male"
    capital_gain: int = 0
    capital_loss: int = 0
    hours_per_week: int
    native_country: str = "United-States"


@app.post("/predict")
def predict(p: Person):
    data = p.model_dump()
    row = {k.replace("_", "."): v for k, v in data.items()}  # education_num -> education.num
    X = pd.get_dummies(pd.DataFrame([row])).reindex(columns=columns, fill_value=0)
    Xs = scaler.transform(X)
    pred = int(model.predict(Xs)[0])
    prob = float(model.predict_proba(Xs)[0][1])
    label = ">50K" if pred == 1 else "<=50K"
    with db() as c:
        c.execute("INSERT INTO predictions (input_data, prediction, probability) VALUES (?, ?, ?)",
                  (json.dumps(data), label, prob))
    return {"prediction": label, "probability": prob}


@app.get("/history")
def history():
    with db() as c:
        rows = c.execute("""
            SELECT p.id, p.prediction, p.probability, p.created_at,
                   p.input_data, m.name AS model_name
            FROM predictions p
            JOIN model_info m ON p.model_id = m.id
            ORDER BY p.id DESC""").fetchall()
    return [dict(r) for r in rows]