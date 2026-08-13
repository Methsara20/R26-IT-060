# AI-Driven Smart Fashion Retail System

## Project Overview

The **AI-Driven Smart Fashion Retail System** is an integrated intelligent retail platform designed to improve operational efficiency and customer experience in multi-store fashion retail environments.

The system combines four AI-driven components within a unified architecture:

1. AI-Driven Smart Inventory and Stock-Flow Optimization
2. AI-Driven Personalized Marketing Intelligence
3. AI-Based Virtual Try-On and Size Recommendation
4. GPS-Based Customer Behavior Tracking with Staff Assistance

The components communicate through shared backend services and a centralized Firebase Firestore database, enabling coordinated and data-driven retail decision-making.

---

## Research Objectives

* Forecast product demand across multiple retail stores
* Detect stock shortages, overstock conditions, and reorder requirements
* Recommend intelligent inter-store stock transfers
* Predict customer promotion-redemption probability
* Generate personalized marketing insights and promotional content
* Predict body measurements and brand-specific clothing sizes
* Provide AI-based virtual garment try-on
* Track in-store customer movement and identify browsing behavior
* Trigger real-time staff-assistance alerts
* Integrate all components into a unified Smart Fashion Retail platform

---

## System Components

### 1. AI-Driven Smart Inventory and Stock-Flow Optimization

The inventory component uses **XGBoost regression** to forecast future product demand across multiple retail stores and support intelligent inventory decisions.

Main capabilities:

* Daily demand forecasting
* Monthly inventory intelligence
* Inventory-health analysis
* Reorder prediction
* Overstock detection
* Days-on-hand calculation
* Best source-store selection
* Alternative source-store ranking
* Transfer-distance calculation
* Logistics-cost estimation
* Risk-aware stock-transfer recommendations
* Recommendation confidence scoring
* AI-generated explanations
* Approve, reject, cancel, and execute transfer workflows
* Automatic inventory and movement-history updates

**Daily Demand Forecasting Performance**

* MAE: **0.5418**
* RMSE: **0.9436**
* R²: **0.9497**

**Monthly Inventory Intelligence Performance**

* MAE: **14.213**
* RMSE: **26.306**
* R²: **0.9353**

---

### 2. AI-Driven Personalized Marketing Intelligence

The marketing component uses customer purchase and campaign-interaction history to predict the probability of customers redeeming promotional offers.

Main capabilities:

* RFM customer analysis
* Promotion-redemption prediction
* Customer segmentation
* Campaign scheduling
* Personalized promotion recommendations
* Stock-aware promotion targeting
* AI-generated promotional content
* AI-generated explanations

The component uses an **XGBoost classifier** together with Recency, Frequency, and Monetary (RFM) behavioral features.

**Model Performance**

* Classification Accuracy: **78.3%**
* ROC-AUC: **0.819**
* Baseline Redemption Rate: **35.9%**

---

### 3. AI-Based Virtual Try-On and Size Recommendation

The virtual try-on component acts as an intelligent digital fitting assistant by combining machine learning and generative AI.

Main capabilities:

* Body-measurement prediction
* BMI-based feature engineering
* Brand-specific size recommendation
* Product-category-aware sizing
* Customer photo processing
* Garment image processing
* AI-generated virtual garment fitting
* Automatic body-measurement recalculation when profile information changes

The component uses:

* **Random Forest Regressor** for body-measurement prediction
* **Random Forest Classifier** for brand-specific size recommendation
* **GridSearchCV** for model optimization
* **Google Cloud Vertex AI** for generative virtual try-on

---

### 4. GPS-Based Customer Behavior Tracking with Staff Assistance

The GPS component monitors customer movement within retail stores and identifies behavioral patterns that may indicate a need for staff assistance.

Main capabilities:

* Real-time GPS tracking
* Store-zone identification
* Haversine-based distance calculation
* Velocity analysis
* Direction-change analysis
* Browsing vs. transiting classification
* Dwell-time monitoring
* Customer pacing-pattern detection
* Automated staff-assistance alerts
* Manual SOS assistance requests
* Real-time staff monitoring dashboard

A **Random Forest classifier** analyzes movement features to classify customers as:

* Browsing
* Transiting

The system can automatically trigger assistance alerts when prolonged browsing or repeated zone-transition patterns are detected.

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
│ XGBoost           │   │ XGBoost            │   │ Random Forest      │
│ Forecasting       │   │ RFM Analysis       │   │ Vertex AI          │
│ Transfer Engine   │   │ Generative AI      │   │ Size Prediction    │
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
```

---

## System Integration

The four components communicate through shared backend services and a centralized **Firebase Firestore** database.

Common identifiers include:

* `product_id`
* `store_id`
* `customer_id`
* `recommendation_id`
* `transaction_id`

Cross-component integration includes:

* Inventory availability is shared with the marketing component to avoid promoting unavailable products
* Inventory information supports virtual try-on product availability
* Customer engagement and marketing information can support inventory demand forecasting
* GPS assistance events can be linked with customer and store information
* Shared Firestore data enables consistent information exchange across the platform

---

## Technologies Used

| Layer                       | Technology                  |
| --------------------------- | --------------------------- |
| Frontend                    | Flutter Web / Flutter       |
| Backend                     | FastAPI                     |
| Programming Languages       | Python, Dart                |
| Database                    | Firebase Firestore          |
| Authentication              | Firebase Authentication     |
| Machine Learning            | XGBoost, Random Forest      |
| ML Libraries                | Scikit-learn, Pandas, NumPy |
| Explainable / Generative AI | Gemini                      |
| Image Generation            | Imagen 3                    |
| Virtual Try-On              | Google Cloud Vertex AI      |
| Model Optimization          | GridSearchCV                |
| Product Image Hosting       | GitHub Pages                |

---

## Data Used

The system works with multiple domain-specific datasets, including:

* Retail sales transactions
* Inventory records
* Product information
* Store information
* Customer profiles
* Promotion and campaign history
* Customer interaction data
* Weather information
* Holiday and event information
* Body measurements
* Garment images
* Brand and size information
* GPS coordinates
* Store-zone information
* Customer movement history

Some datasets used during research development and evaluation are simulated or prepared datasets.

---

## Machine Learning Models

### Inventory Optimization

**Model:** XGBoost Regressor

Features include:

* Historical sales
* Lag-1 sales
* Lag-7 sales
* Seven-day rolling averages
* Product category
* Product subcategory
* Brand
* Gender
* Price
* Promotion percentage
* Store
* Temperature
* Humidity
* Rainfall
* Holidays
* Festivals
* School periods
* Weekends
* Calendar features

---

### Personalized Marketing

**Model:** XGBoost Classifier

Inputs include:

* Recency
* Frequency
* Monetary value
* Customer characteristics
* Product information
* Promotion information
* Campaign-interaction history

**Output:** Promotion-redemption probability

---

### Virtual Try-On and Size Recommendation

**Models:**

* Random Forest Regressor
* Random Forest Classifier

Inputs include:

* Height
* Weight
* Gender
* BMI
* Brand
* Product category

Outputs include:

* Estimated body measurements
* Brand-specific size recommendation
* AI-generated virtual try-on image

---

### GPS Customer Behavior Tracking

**Model:** Random Forest Classifier

Movement features include:

* Latitude
* Longitude
* Altitude
* Distance travelled
* Velocity
* Direction change
* Dwell time
* Zone-transition history

Output classes:

* Browsing
* Transiting

---

## Project Structure

```text
project-root/
│
├── frontend/
│   ├── customer/
│   ├── inventory/
│   ├── virtual_try_on/
│   └── staff_dashboard/
│
├── backend/
│   ├── api/
│   ├── schemas/
│   ├── services/
│   ├── models/
│   ├── utils/
│   └── main.py
│
├── ml_models/
│   ├── inventory/
│   ├── marketing/
│   ├── virtual_try_on/
│   └── gps_tracking/
│
├── data/
│   └── sample_or_research_datasets/
│
├── docs/
│   ├── architecture/
│   ├── diagrams/
│   └── research/
│
├── tests/
│
└── README.md
```

---

## Research Results

### Inventory Optimization

| Model                          |    MAE |   RMSE |     R² |
| ------------------------------ | -----: | -----: | -----: |
| Daily Demand Forecasting       | 0.5418 | 0.9436 | 0.9497 |
| Monthly Inventory Intelligence | 14.213 | 26.306 | 0.9353 |

### Personalized Marketing

| Metric                   | Value |
| ------------------------ | ----: |
| Baseline Redemption Rate | 35.9% |
| Classification Accuracy  | 78.3% |
| ROC-AUC                  | 0.819 |

Additional model evaluation includes functional testing, performance metrics, confusion matrices, and graphical analysis.

---

## Project Status

The project is currently in the **final implementation, evaluation, and research publication stage**.

### Completed / Implemented

* Overall Smart Fashion Retail architecture
* Firebase Firestore integration
* FastAPI backend services
* Flutter-based interfaces
* Inventory demand forecasting
* Inventory intelligence
* Stock-transfer recommendation workflow
* Personalized marketing prediction
* Customer segmentation
* AI-generated promotional content
* Body-measurement prediction
* Brand-specific size recommendation
* Virtual try-on integration
* GPS-based customer tracking
* Customer behavior classification
* Staff-assistance alerting
* Cross-component integration
* Functional testing
* Machine-learning model evaluation

### Current Focus

* Final model evaluation
* Performance graphs and confusion matrices
* Integrated system testing
* Research paper preparation
* Research publication preparation

---

## Team Members

* IT22146588
* IT22244598
* IT22284952
* IT22243812

---

## Research Contribution

The main contribution of this research is an integrated **AI-Driven Smart Fashion Retail System** that connects customer-facing intelligence with operational retail decision-making.

The platform integrates:

* Demand forecasting
* Inventory intelligence
* Stock-flow optimization
* Personalized marketing
* Generative promotional content
* Virtual try-on
* Brand-specific size recommendation
* Customer behavior tracking
* Real-time staff assistance

within a unified smart retail architecture.

---

## Limitations

* Some datasets are simulated or prepared rather than collected entirely from live retail operations
* Model performance depends on data quality and completeness
* Logistics calculations use simplified assumptions
* Virtual try-on quality may vary with pose, image quality, and garment complexity
* Size recommendations are affected by brands represented in the training data
* Indoor GPS accuracy may vary depending on environment and device
* Continuous GPS tracking may increase battery consumption
* Some operational decisions require human approval

---

## Future Work

Future improvements include:

* Real-time POS integration
* Live traffic and logistics information
* Hybrid forecasting models
* Larger real-world retail datasets
* Continuous model retraining
* Improved indoor-positioning technologies
* Fine-tuned generative models for virtual try-on
* Larger brand-specific sizing datasets
* Real-world multi-store deployment
* Large-scale user evaluation
* Adaptive and continuously learning AI models

---

## Version Control

The project is maintained using GitHub with structured commits representing development progress, implementation changes, model improvements, integration, testing, and documentation.

---

## Publication

This project forms part of a university research study on intelligent fashion retail systems. The research paper presents the design, implementation, integration, evaluation, contributions, and limitations of the proposed **AI-Driven Smart Fashion Retail System**.
