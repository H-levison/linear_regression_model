import numpy as np
import joblib
from pathlib import Path

BASE_DIR = Path(__file__).parent

model  = joblib.load(BASE_DIR / "bitcoin_best_model.pkl")
scaler = joblib.load(BASE_DIR / "bitcoin_feature_scaler.pkl")

FEATURES = [
    "sp500_close",
    "gold_close",
    "dxy_close",
    "fng_score",
    "hash_rate",
    "google_trends_score",
    "volume",
]


def predict_btc_close(
    sp500_close: float,
    gold_close: float,
    dxy_close: float,
    fng_score: int,
    hash_rate: float,
    google_trends_score: int,
    volume: float,
) -> float:
    """
    Predict Bitcoin's daily closing price using macro and sentiment indicators.

    All features should reflect values available at the start of the trading day
    (no same-day BTC price data to avoid leakage).
    """
    raw = np.array([[
        sp500_close,
        gold_close,
        dxy_close,
        fng_score,
        hash_rate,
        google_trends_score,
        volume,
    ]])
    scaled = scaler.transform(raw)
    return float(model.predict(scaled)[0])


if __name__ == "__main__":
    sample = {
        "sp500_close": 4500.0,
        "gold_close":  1950.0,
        "dxy_close":   103.5,
        "fng_score":   55,
        "hash_rate":   450.0,
        "google_trends_score": 40,
        "volume":      25_000_000_000.0,
    }

    price = predict_btc_close(**sample)
    print(f"Predicted Bitcoin close price: ${price:,.2f}")
