# Income Predictor: FastAPI + SQLite + Flutter

A small end-to-end machine learning project. A trained classifier is served through a **FastAPI** backend, every prediction is stored in a **SQLite** database, and a **Flutter** app lets a user enter details, get a prediction, and view the prediction history.

The model predicts whether a person earns **more than $50K a year** using the Adult Census Income dataset from Hugging Face (`scikit-learn/adult-census-income`).

## How it works

```
Flutter app  --POST /predict-->  FastAPI  -->  Logistic Regression model
     ^                              |
     |                              v
     +------GET /history-------  SQLite database (predictions.db)
```

1. The user enters age, years of education, hours per week and sex in the Flutter app.
2. The app sends the data to the `/predict` endpoint.
3. The backend one-hot encodes the input, scales it, runs the model, and returns the prediction with a probability.
4. The request and result are saved in the database.
5. The app calls `/history` to show all past predictions.

## Project structure

```
Task_7/
├── lib/
│   └── main.dart          # Flutter app (Provider for state management)
├── backend/
│   ├── main.py            # FastAPI app and database code
│   ├── model.pkl          # Trained Logistic Regression model
│   ├── scaler.pkl         # StandardScaler fitted on training data
│   └── columns.pkl        # Feature column names used in training
├── pubspec.yaml
└── README.md
```

## Model

- **Algorithm:** Logistic Regression (scikit-learn)
- **Preprocessing:** missing values (`?`) removed, categorical columns one-hot encoded, features scaled with `StandardScaler`
- **Split:** 80% train, 20% test
- **Results on the test set:** accuracy 85.3%, precision 73.4%, recall 61.0%

The model was trained in a separate notebook (the Task 6 classification notebook) and saved with `joblib`.

## API endpoints

| Method | Endpoint   | Description                                                      |
|--------|------------|------------------------------------------------------------------|
| POST   | `/predict` | Takes a person's details, returns a prediction and probability   |
| GET    | `/history` | Returns all past predictions, newest first                       |

### Example request

```json
POST /predict
{
  "age": 40,
  "education_num": 13,
  "hours_per_week": 45
}
```

### Example response

```json
{
  "prediction": "<=50K",
  "probability": 0.42
}
```

Fields not sent (workclass, occupation, race, and so on) use default values defined in the `Person` class in `main.py`.

## Database

SQLite file `predictions.db`, created automatically on first run.

**`model_info`**

| Column  | Type    | Notes                  |
|---------|---------|------------------------|
| id      | INTEGER | Primary key            |
| name    | TEXT    | Model name             |
| version | TEXT    | Model version          |

**`predictions`**

| Column      | Type    | Notes                              |
|-------------|---------|------------------------------------|
| id          | INTEGER | Primary key, auto-increment        |
| model_id    | INTEGER | Links to `model_info.id`           |
| input_data  | TEXT    | The request as JSON                |
| prediction  | TEXT    | `>50K` or `<=50K`                  |
| probability | REAL    | Probability of `>50K`              |
| created_at  | TEXT    | Timestamp, set automatically       |

The `/history` endpoint uses a SQL `JOIN` to combine each prediction with the model name from `model_info`:

```sql
SELECT p.id, p.prediction, p.probability, p.created_at,
       p.input_data, m.name AS model_name
FROM predictions p
JOIN model_info m ON p.model_id = m.id
ORDER BY p.id DESC;
```

## Running the project

### 1. Start the backend

```bash
cd backend
pip install fastapi uvicorn scikit-learn pandas joblib
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open `http://localhost:8000/docs` to test the endpoints in the browser.

### 2. Start the Flutter app

```bash
flutter pub get
flutter run -d chrome
```

Set `baseUrl` at the top of `lib/main.dart` to match where the app runs:

| Where you run the app | `baseUrl`                    |
|-----------------------|------------------------------|
| Chrome or Windows     | `http://localhost:8000`      |
| Android emulator      | `http://10.0.2.2:8000`       |
| Real phone            | `http://<your-PC-IP>:8000`   |

The backend must be running before you press **Predict**.

## Tech stack

- Python, scikit-learn, pandas, joblib
- FastAPI, Uvicorn, SQLite
- Flutter, Provider, http

## Limitations and next steps

- The app sends only four fields; the rest use defaults, so predictions are approximate.
- Recall is 61%, so the model misses some people who earn over $50K. Next steps: try Random Forest and handle class imbalance.
- No authentication, and CORS is open to all origins. This is fine for a learning project but not for production.
- The `.pkl` files must be produced with a compatible scikit-learn version.

## Screenshots

Add screenshots here: the `/docs` page, the `/history` response, and the Flutter screen showing a prediction and history.
