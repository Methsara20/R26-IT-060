# AI-Driven Smart Fashion Retail System

## Project Overview

The **AI-Driven Smart Fashion Retail System** is an integrated intelligent retail platform designed to improve operational efficiency and customer experience in multi-store fashion retail environments.

The system combines four AI-driven components within a unified architecture:

The system integrates multiple AI components into a **single unified platform** to support real-time retail decision-making, bridging the gap between digital convenience and physical retail shopping.

---

## Research Objectives

- Analyze customer behaviour using high-frequency GPS-based tracking.
- Provide a photorealistic virtual try-on experience and AI-driven size recommendations.
- Offer 24/7 personalized fashion advice via a Conversational AI Stylist.
- Predict product demand using machine learning.
- Generate personalized marketing insights and promotions.

---

## System Components

### 1. GPS-Based Customer Behaviour Tracking & Staff Assistance
Tracks customer movement, zone changes, and time spent in store areas using mobile GPS. It leverages a Random Forest classifier to distinguish between "Browsing" and "Transiting" behaviour, automatically alerting store staff when a customer demonstrates a need for assistance (e.g., prolonged dwell time or pacing).

### 2. AI-Based Virtual Try-On, Size Recommendation & AI Stylist
Addresses sizing inconsistency by using Machine Learning (GridSearchCV-tuned Random Forest) to predict precise body measurements from basic inputs, and then maps those measurements to brand-specific sizes. Includes a **Google Vertex AI** integration allowing users to virtually try on clothing with photorealistic compositing. Furthermore, it features a 24/7 **Conversational AI Stylist** utilizing a **Traditional Retrieval-Augmented Generation (RAG)** architecture (LangChain, HuggingFace Embeddings, ChromaDB) to ground the Large Language Model's styling advice in the store's actual live inventory, preventing AI hallucinations.

### 3. Smart Inventory & Stock Flow Optimization 
Predicts product demand using machine learning (XGBoost) and provides intelligent stock management and restocking recommendations.

### 4. Personalized Marketing Intelligence Dashboard
Analyzes customer data to predict effective promotions, evaluate campaigns, and generate AI-based marketing content.

---

## System Architecture

                 ┌────────────────────────────┐
                 │       Data Sources         │
                 │----------------------------│
                 │ • POS Transactions         │
                 │ • Mobile GPS Data          │
                 │ • Product Catalog          │
                 └────────────┬───────────────┘
                              ↓
                 ┌────────────────────────────┐
                 │     Backend / API Layer    │
                 │----------------------------│
                 │ • Python / FastAPI         │
                 │ • LangChain / ChromaDB     │
                 │ • Geometry Processing      │
                 └────────────┬───────────────┘
                              ↓
     ┌────────────────────────────────────────────────────┐
     │              AI & Processing Layer                 │
     │----------------------------------------------------│
     │ 1. Random Forest (Behaviour Intent & Sizing)       │
     │ 2. Generative AI (Vertex AI Try-On)                │
     │ 3. Traditional RAG (Conversational AI Stylist)     │
     │ 4. XGBoost (Demand Forecasting & Marketing)        │
     └────────────┬───────────────────────────────────────┘
                  ↓
        ┌────────────────────────────┐
        │   Data Storage Layer       │
        │----------------------------│
        │ • Firebase Firestore       │
        │ • ChromaDB (Vector Store)  │
        └────────────┬───────────────┘
                     ↓
        ┌────────────────────────────┐
        │   Frontend / Dashboard     │
        │----------------------------│
        │ • Flutter Mobile App       │
        │ • Flutter Web Dashboard    │
        └────────────┬───────────────┘
                     ↓
        ┌────────────────────────────┐
        │      Final Outputs         │
        │----------------------------│
        │ • Autonomous Staff Alerts  │
        │ • Fashion Recommendations  │
        │ • Demand Predictions       │
        └────────────────────────────┘

---

## Technologies Used

- **Frontend:** Flutter, Dart (Mobile & Web)
- **Backend:** Python, FastAPI, Uvicorn
- **Machine Learning:** Scikit-Learn (Random Forest), XGBoost, Pandas
- **Generative AI & LLMs:** Google Cloud Vertex AI, Gemini
- **RAG Architecture:** LangChain, HuggingFace (`all-MiniLM-L6-v2`), ChromaDB
- **Database:** Firebase Firestore (NoSQL)
- **Geolocation:** Flutter Geolocator, Haversine Formula

---

## Project Structure

```text
project-root/
│
├── frontend/             # Flutter Mobile App & Web Dashboard
├── backend/              # Python FastAPI Server & AI Services
├── chroma_db/            # Local Vector Database for RAG
├── docs/                 # Architecture diagrams & documentation
└── README.md
```

---

## Project Status

Currently in **Implementation & Testing Phase**  
- ✅ System architecture designed  
- ✅ Frontend UI overhauled with Premium Light/Dark mode  
- ✅ GPS Behaviour Tracking integrated  
- ✅ AI Stylist & RAG pipeline deployed  
- ✅ ML Sizing and Virtual Try-On completed

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

This project is maintained using GitHub with structured commits showing progress from planning to implementation.
