# AI-Driven Smart Fashion Retail System

## Project Overview

The **AI-Driven Smart Fashion Retail System** is an integrated intelligent retail platform designed to improve operational efficiency and customer experience in multi-store fashion retail environments.

The system combines four AI-driven components within a unified architecture:

1. AI-Driven Smart Inventory and Stock-Flow Optimization
2. AI-Driven Personalized Marketing Intelligence
3. AI-Based Virtual Try-On and Size Recommendation
4. GPS-Based Customer Behavior Tracking with Staff Assistance

The components communicate through shared backend services and a centralized Firebase Firestore database, enabling coordinated, data-driven retail decision-making.

---

## Research Objectives

- Forecast product demand across multiple retail stores.
- Detect stock shortages, overstock conditions, and reorder requirements.
- Recommend intelligent inter-store stock transfers.
- Predict customer promotion-redemption probability.
- Generate personalized marketing insights and promotional content.
- Predict body measurements and brand-specific clothing sizes.
- Provide AI-based virtual garment try-on.
- Track in-store customer movement and identify browsing behavior.
- Trigger real-time staff-assistance alerts based on customer behavior.
- Integrate all four components into a unified Smart Fashion Retail platform.

---

## System Components

### 1. AI-Driven Smart Inventory and Stock-Flow Optimization

The inventory component forecasts future product demand across multiple retail stores using XGBoost regression.

Main capabilities include:

- Daily demand forecasting
- Monthly inventory intelligence
- Inventory-health analysis
- Reorder prediction
- Overstock detection
- Days-on-hand calculation
- Best source-store selection
- Alternative source-store ranking
- Transfer-distance calculation
- Logistics-cost estimation
- Risk-aware stock-transfer recommendations
- Recommendation confidence scoring
- AI-generated explanations
- Approve, reject, cancel, and execute stock-transfer workflows
- Automatic inventory and movement-history updates

The daily forecasting model achieved:

- **MAE:** 0.5418
- **RMSE:** 0.9436
- **R²:** 0.9497

The monthly inventory-intelligence model achieved:

- **MAE:** 14.213
- **RMSE:** 26.306
- **R²:** 0.9353

---

### 2. AI-Driven Personalized Marketing Intelligence

The marketing component predicts the probability that individual customers will redeem promotional offers.

It uses RFM-based customer behavior features together with customer, product, and promotion information.

Main capabilities include:

- RFM customer analysis
- Promotion-redemption prediction
- Customer segmentation
- Campaign scheduling
- Personalized promotion recommendations
- Stock-aware promotion targeting
- AI-generated promotional posters
- AI-generated explanations for recommendations

The XGBoost redemption classifier achieved:

- **Classification Accuracy:** 78.3%
- **ROC-AUC:** 0.819
- **Baseline Redemption Rate:** 35.9%

---

### 3. AI-Based Virtual Try-On and Size Recommendation

The virtual try-on component acts as a digital fitting assistant for fashion customers.

It combines machine learning and generative AI to estimate customer measurements, recommend brand-specific sizes, and visualize garments on customer photographs.

Main capabilities include:

- Body-measurement prediction
- BMI-based feature engineering
- Brand-specific clothing-size prediction
- Product-category-aware size recommendation
- Customer photo upload
- Garment image processing
- AI-generated virtual garment fitting
- Automatic recalculation when customer body information changes

Machine-learning methods include:

- Random Forest Regressor
- Random Forest Classifier
- GridSearchCV optimization
- Google Cloud Vertex AI virtual try-on

---

### 4. GPS-Based Customer Behavior Tracking with Staff Assistance

The GPS component monitors customer movement within retail stores and identifies behavioral patterns that may indicate a need for assistance.

Main capabilities include:

- Real-time GPS tracking
- Store-zone identification
- Haversine-based distance calculation
- Velocity and direction-change analysis
- Browsing vs. transiting classification
- Dwell-time monitoring
- Customer pacing-pattern detection
- Automated staff-assistance alerts
- Manual SOS assistance request
- Real-time staff monitoring dashboard

A Random Forest classifier is used to classify customer movement behavior.

The system can trigger staff alerts when:

- Continuous browsing exceeds a configured dwell-time threshold.
- Repeated movement between store zones indicates pacing behavior.
- A customer manually requests assistance.

---

## System Architecture

```text
                    ┌──────────────────────────────┐
                    │            Users             │
                    │------------------------------│
                    │ Customers                    │
                    │ Retail Staff                 │
                    │ Administrators               │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │      Frontend Applications   │
                    │------------------------------│
                    │ Flutter Web / Mobile UI      │
                    │ Marketing Dashboard          │
                    │ Staff Monitoring Dashboard   │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │       FastAPI Backend        │
                    │------------------------------│
                    │ REST API Services            │
                    │ Authentication               │
                    │ Business Logic               │
                    │ AI Service Integration       │
                    └──────────────┬───────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌───────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│ Inventory         │   │ Personalized       │   │ Virtual Try-On     │
│ Intelligence      │   │ Marketing          │   │ & Size Prediction  │
│-------------------│   │--------------------│   │--------------------│
│ XGBoost Forecast  │   │ XGBoost            │   │ Random Forest      │
│ Stock Analysis    │   │ RFM Analysis       │   │ Vertex AI          │
│ Transfer Engine   │   │ Gemini / Imagen    │   │ Size Prediction    │
└───────────────────┘   └────────────────────┘   └────────────────────┘
          │                        │                        │
          └────────────────────────┼────────────────────────┘
                                   │
                                   ▼
                       ┌────────────────────────┐
                       │ GPS Behavior Tracking  │
                       │------------------------│
                       │ Random Forest          │
                       │ Haversine Features     │
                       │ Staff Alert Engine     │
                       └────────────┬───────────┘
                                    │
                                    ▼
                       ┌────────────────────────┐
                       │ Firebase Firestore     │
                       │------------------------│
                       │ Products               │
                       │ Stores                 │
                       │ Inventory              │
                       │ Sales                  │
                       │ Customers              │
                       │ Recommendations        │
                       │ Transactions           │
                       │ Monitoring Data        │
                       └────────────────────────┘
