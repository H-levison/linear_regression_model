# Bitcoin Market Price Predictor

## Mission

To build a machine learning model that predicts the **daily closing price of Bitcoin** using macroeconomic indicators and market sentiment data, and to make those predictions accessible through a REST API consumed by a Flutter mobile application.

The core idea is straightforward: rather than looking at Bitcoin's own price history, can external signals — what the stock market is doing, how fearful investors are, how much energy miners are committing to the network — reliably explain where BTC lands at the end of a trading day?

---

## Dataset

**Name:** Bitcoin Market Analysis Dataset (2021–2025)
**Source:** [Kaggle — purnamaridzkynugraha/bitcoin-historical-data](https://www.kaggle.com/datasets/purnamaridzkynugraha/bitcoin-historical-data)

The dataset contains **1,820 daily observations** spanning January 2021 to early 2025. It is multi-dimensional by design, combining four distinct categories of signal:

| Category | Features |
|---|---|
| Bitcoin market data | close, open, high, low, volume, adj_close |
| Traditional markets | S&P 500 close, Gold spot price |
| Macroeconomic | US Dollar Index (DXY) |
| Sentiment & network | Fear & Greed Index, Google Trends score, hash rate, BTC return, log return |

This breadth of variety — across asset classes, geographies, and data types — is what makes the dataset well-suited for a regression task. It forces the model to weigh fundamentally different kinds of signals against each other.

---

## Task 1 — Linear Regression Model

### Feature Engineering

Several columns were dropped before training to prevent **data leakage** — they contain same-day Bitcoin price information that would not be available at the start of a trading day:

- Dropped: `open`, `high`, `low`, `adj_close`, `btc_return`, `btc_log_return`
- Kept as features: `sp500_close`, `gold_close`, `dxy_close`, `fng_score`, `hash_rate`, `google_trends_score`, `volume`
- Target: `close`

Remaining missing values were handled with forward-fill before dropping any residual nulls.

### Models Trained

Three models were built and compared:

| Model | Test RMSE | Test R² |
|---|---|---|
| Linear Regression | $4,054.66 | 0.9715 |
| Decision Tree | $3,651.61 | 0.9845 |
| **Random Forest** | **$2,766.51** | **0.9911** |

The **Random Forest** model achieved the lowest error and highest explained variance and was saved as the production model.

### Gradient Descent

A custom batch gradient descent implementation was built from scratch to train a multivariate linear regression model over 500 epochs (learning rate = 0.01). Training and test loss curves were plotted to confirm stable convergence with no overfitting.

### Saved Artifacts

| File | Description |
|---|---|
| `linear_regression/bitcoin_best_model.pkl` | Trained Random Forest model |
| `linear_regression/bitcoin_feature_scaler.pkl` | Fitted StandardScaler for input features |

---

## Task 2 — Prediction API

Built with **FastAPI**, deployed on **Render**.

**Live API:** https://linear-regression-model-4w14.onrender.com
**Swagger UI:** https://linear-regression-model-4w14.onrender.com/docs

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | Health check and available routes |
| POST | `/predict` | Returns predicted BTC closing price |
| POST | `/retrain` | Accepts a CSV upload and retrains the model |

### Input Variables (`POST /predict`)

All inputs are validated using **Pydantic** with enforced types and realistic range constraints:

| Variable | Type | Range | Description |
|---|---|---|---|
| `sp500_close` | float | 2000 – 7000 | S&P 500 closing index value |
| `gold_close` | float | 1000 – 4000 | Gold spot price in USD/oz |
| `dxy_close` | float | 75 – 130 | US Dollar Index closing value |
| `fng_score` | int | 0 – 100 | Fear & Greed Index |
| `hash_rate` | float | 50 – 1500 | Bitcoin network hash rate (EH/s) |
| `google_trends_score` | int | 0 – 100 | Google Trends interest score |
| `volume` | float | 1×10⁸ – 1×10¹² | 24h trading volume in USD |

### Running Locally

```bash
cd summative/API
pip install -r requirements.txt
uvicorn prediction:app --reload
```

The API will be available at `http://localhost:8000` and the interactive docs at `http://localhost:8000/docs`.

### Model Retraining

Send a `POST` request to `/retrain` with a CSV file attached. The file must contain all seven feature columns plus `close`. The model is retrained on the new data, evaluated, and the updated `.pkl` files are saved to disk automatically. Metrics (RMSE and R²) are returned in the response.

---

## Task 3 — Flutter Application

A single-page Flutter application that sends prediction requests to the live API and displays the result.

### Features

- Seven input fields, each corresponding to one model feature
- Input validation with range constraints matching the API
- A **Predict** button that fires a `POST /predict` request
- A result card that displays the predicted price or a descriptive error message if inputs are out of range or the request fails

### Running the App

```bash
cd summative/Flutter
flutter pub get
flutter run
```

> The API base URL is set to the live Render deployment by default. To test against a local API instance, update `kApiBaseUrl` at the top of `lib/main.dart`.

---

## Demo Video

[![Bitcoin Price Predictor — Demo](https://img.youtube.com/vi/TpWCeN0NZkk/0.jpg)](https://youtu.be/TpWCeN0NZkk)

---

## Project Structure

```
summative/
├── README.md
├── linear_regression/
│   ├── multivariate.ipynb          # Full analysis and model training notebook
│   ├── predict.py                  # Standalone prediction script
│   ├── bitcoin_best_model.pkl      # Saved Random Forest model
│   ├── bitcoin_feature_scaler.pkl  # Saved StandardScaler
│   └── Bitcoin Market Analysis Dataset (2021-2025).csv
├── API/
│   ├── prediction.py               # FastAPI application
│   └── requirements.txt
└── Flutter/
    ├── lib/
    │   └── main.dart               # App UI and prediction logic
    └── pubspec.yaml
```
