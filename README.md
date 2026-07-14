# AI-Driven Smart Retail Intelligence System

---

## Project Overview

This project aims to develop an **AI-driven smart retail system** that enhances customer experience, optimizes inventory management, and improves marketing effectiveness using data analytics, machine learning, and intelligent decision support.

The system integrates multiple AI components into a **single unified platform** to support real-time retail decision-making.

---

## Objectives

- Analyze customer behaviour using GPS-based tracking
- Provide virtual try-on and size recommendation
- Predict product demand using machine learning
- Generate personalized marketing insights and promotions

---

## System Components

### GPS-Based Customer Behaviour Tracking & Staff Assistance
Tracks customer movement, zone changes, and time spent in store areas to provide behaviour insights and real-time staff assistance.

---

### AI-Based Virtual Try-On & Size Recommendation
Allows users to virtually try clothing using a lightweight 2D approach and provides size recommendations using AI.

---

### Smart Inventory & Stock Flow Optimization 
Predicts product demand using machine learning (XGBoost) and provides intelligent stock management and restocking recommendations.

---

### Personalized Marketing Intelligence Dashboard
Analyzes customer data to predict effective promotions, evaluate campaigns, and generate AI-based marketing content.

---

## System Architecture

                 ┌────────────────────────────┐
                 │       Data Sources         │
                 │----------------------------│
                 │ • POS Transactions         │
                 │ • Customer Data            │
                 │ • Product Data             │
                 │ • Promotion Data           │
                 └────────────┬───────────────┘
                              ↓
                 ┌────────────────────────────┐
                 │     Backend / API Layer    │
                 │----------------------------│
                 │ • Flask / FastAPI          │
                 │ • Data Processing          │
                 │ • API Integration          │
                 └────────────┬───────────────┘
                              ↓
     ┌────────────────────────────────────────────────────┐
     │              AI & Processing Layer                 │
     │----------------------------------------------------│
     │ 1. GPS Behaviour Tracking & Staff Assistance       │
     │ 2. Virtual Try-On & Size Recommendation (AI)       │
     │ 3. Demand Forecasting (XGBoost)                  │
     │ 4. Marketing Intelligence (XGBoost + AI Posters)   │
     └────────────┬───────────────────────────────────────┘
                  ↓
        ┌────────────────────────────┐
        │   Data Storage Layer       │
        │----------------------------│
        │ • Database (MySQL/Firebase)│
        │ • Model Outputs            │
        └────────────┬───────────────┘
                     ↓
        ┌────────────────────────────┐
        │   Frontend / Dashboard     │
        │----------------------------│
        │ • Admin Dashboard          │
        │ • Marketing Dashboard      │
        │ • Smart UI (Try-On)        │
        └────────────┬───────────────┘
                     ↓
        ┌────────────────────────────┐
        │      Final Outputs         │
        │----------------------------│
        │ • Customer Insights        │
        │ • Demand Predictions       │
        │ • Promotion Strategies     │
        │ • Staff Alerts             │
        └────────────────────────────┘

---

## Technologies Used

- **Frontend:** React.js  
- **Backend:** Flask / FastAPI  
- **Machine Learning:** XGBoost, Scikit-learn , Randon Forest  
- **Database:** MySQL / Firebase  
- **AI Tools:** Generative AI APIs (for virtual try-on & marketing)

---

## Dataset (Planned)

- Retail sales transaction data  
- Product data  
- Customer interaction data  
- Promotion data  

---

##  Project Structure
project-root/
│
├── frontend/ # UI (Dashboard, Smart Mirror)
├── backend/ # API and server logic
├── models/ # ML models (forecasting, prediction)
├── data/ # Dataset (sample / placeholder)
├── docs/ # Architecture diagrams & documentation
├── tests/ # Testing files
└── README.md


---

## Project Status

Currently in **Research and Design Phase (PP1)**  
- Problem analysis completed  
- System architecture designed  
- Initial project setup created  

---

## Team Members

- IT22146588  
- IT22244598  
- IT22284952
- IT22243812

---

## Version Control

This project is maintained using GitHub with structured commits showing progress from planning to implementation.

---

## Key Contribution

This research proposes an **integrated AI-driven retail intelligence platform** that combines behaviour tracking, virtual try-on, demand forecasting, and marketing intelligence into a single system for practical real-world retail environments.
