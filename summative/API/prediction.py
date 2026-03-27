import io
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# Paths — works locally and on Render as long as the repo structure is kept
# ---------------------------------------------------------------------------
BASE_DIR    = Path(__file__).parent
MODEL_PATH  = BASE_DIR.parent / "linear_regression" / "bitcoin_best_model.pkl"
SCALER_PATH = BASE_DIR.parent / "linear_regression" / "bitcoin_feature_scaler.pkl"

model  = joblib.load(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

FEATURES = [
    "sp500_close",
    "gold_close",
    "dxy_close",
    "fng_score",
    "hash_rate",
    "google_trends_score",
    "volume",
]

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Bitcoin Close Price Predictor",
    description=(
        "Predicts Bitcoin's daily closing price from macro-economic "
        "and market-sentiment indicators. Built on a Random Forest model "
        "trained on daily data from 2021–2025."
    ),
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://10.0.2.2:8000",   # Android emulator
        "https://your-app-name.onrender.com",  # replace with actual Render URL
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class PredictionInput(BaseModel):
    sp500_close: float = Field(
        ...,
        ge=2000.0,
        le=7000.0,
        description="S&P 500 closing index value",
        examples=[4500.0],
    )
    gold_close: float = Field(
        ...,
        ge=1000.0,
        le=4000.0,
        description="Gold spot price in USD per troy ounce",
        examples=[1950.0],
    )
    dxy_close: float = Field(
        ...,
        ge=75.0,
        le=130.0,
        description="US Dollar Index (DXY) closing value",
        examples=[103.5],
    )
    fng_score: int = Field(
        ...,
        ge=0,
        le=100,
        description="Fear & Greed Index — 0 is extreme fear, 100 is extreme greed",
        examples=[55],
    )
    hash_rate: float = Field(
        ...,
        ge=50.0,
        le=1500.0,
        description="Bitcoin network hash rate in EH/s",
        examples=[450.0],
    )
    google_trends_score: int = Field(
        ...,
        ge=0,
        le=100,
        description="Google Trends interest score for 'Bitcoin' (0–100)",
        examples=[40],
    )
    volume: float = Field(
        ...,
        ge=1e8,
        le=1e12,
        description="Bitcoin 24-hour trading volume in USD",
        examples=[25_000_000_000.0],
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "sp500_close": 4500.0,
                "gold_close": 1950.0,
                "dxy_close": 103.5,
                "fng_score": 55,
                "hash_rate": 450.0,
                "google_trends_score": 40,
                "volume": 25000000000.0,
            }
        }
    }


class PredictionOutput(BaseModel):
    predicted_close_usd: float
    model_used: str = "Random Forest Regressor"


class RetrainOutput(BaseModel):
    message: str
    rmse_usd: float
    r2_score: float
    training_samples: int
    test_samples: int


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/")
def root():
    return {
        "message": "Bitcoin Close Price Predictor API is running.",
        "docs_url": "/docs",
        "predict_endpoint": "POST /predict",
        "retrain_endpoint": "POST /retrain",
    }


@app.post("/predict", response_model=PredictionOutput)
def predict(payload: PredictionInput):
    """
    Returns the predicted Bitcoin closing price in USD.

    All inputs should represent values available *before* the trading day opens —
    no same-day BTC data to keep the model honest.
    """
    try:
        raw = np.array([[
            payload.sp500_close,
            payload.gold_close,
            payload.dxy_close,
            payload.fng_score,
            payload.hash_rate,
            payload.google_trends_score,
            payload.volume,
        ]])
        scaled = scaler.transform(raw)
        price  = float(model.predict(scaled)[0])
        return PredictionOutput(predicted_close_usd=round(price, 2))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/retrain", response_model=RetrainOutput)
async def retrain(file: UploadFile = File(...)):
    """
    Upload a CSV with the same columns as the original dataset to retrain
    the model on fresh data. The updated model is saved to disk automatically.

    Required columns: sp500_close, gold_close, dxy_close, fng_score,
                      hash_rate, google_trends_score, volume, close
    """
    global model, scaler

    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted.")

    contents = await file.read()
    try:
        new_df = pd.read_csv(io.BytesIO(contents))
    except Exception:
        raise HTTPException(status_code=400, detail="Could not parse the file as a CSV.")

    required = FEATURES + ["close"]
    missing  = [c for c in required if c not in new_df.columns]
    if missing:
        raise HTTPException(
            status_code=422,
            detail=f"Missing columns: {missing}",
        )

    new_df = new_df[required].dropna()
    if len(new_df) < 50:
        raise HTTPException(
            status_code=422,
            detail="Not enough rows to retrain (minimum 50 required).",
        )

    X = new_df[FEATURES].values
    y = new_df["close"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    new_scaler        = StandardScaler()
    X_train_scaled    = new_scaler.fit_transform(X_train)
    X_test_scaled     = new_scaler.transform(X_test)

    new_model = RandomForestRegressor(n_estimators=100, random_state=42)
    new_model.fit(X_train_scaled, y_train)

    preds = new_model.predict(X_test_scaled)
    rmse  = float(np.sqrt(mean_squared_error(y_test, preds)))
    r2    = float(r2_score(y_test, preds))

    joblib.dump(new_model,  MODEL_PATH)
    joblib.dump(new_scaler, SCALER_PATH)
    model  = new_model
    scaler = new_scaler

    return RetrainOutput(
        message="Model retrained and saved successfully.",
        rmse_usd=round(rmse, 2),
        r2_score=round(r2, 4),
        training_samples=len(X_train),
        test_samples=len(X_test),
    )
